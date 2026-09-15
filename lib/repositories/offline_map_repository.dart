import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/objectbox.g.dart';
import 'package:my_spots/services/zone_download/zone_download.dart';

/// [MapLayerRepository] backed by ObjectBox.
class OfflineMapRepository implements MapLayerRepository {
  OfflineMapRepository(Store store)
    : _mapBox = Box<OfflineMap>(store),
      _layerBox = Box<OfflineMapLayer>(store);

  /// Lazily-initialised singleton. Created on first access via
  /// [initWithStore] or [instance].
  static OfflineMapRepository? _instance;

  /// Returns the singleton instance. Returns `null` if [initWithStore]
  /// has not been called yet — call it during app bootstrap.
  static OfflineMapRepository? get instance => _instance;

  /// Initialises the singleton with the given [store].
  ///
  /// Call this once during app bootstrap (e.g. in [AppBootstrap]).
  /// Subsequent calls are ignored (the first store wins).
  static void initWithStore(Store store) {
    _instance ??= OfflineMapRepository(store);
  }

  /// Resets the singleton — intended for testing only.
  static void resetInstance() {
    _instance = null;
  }

  final Box<OfflineMap> _mapBox;
  final Box<OfflineMapLayer> _layerBox;

  // ---- OfflineMap CRUD ----

  /// Saves a new or existing OfflineMap. Returns the map with its new ID.
  @override
  OfflineMap save(OfflineMap map) {
    _mapBox.put(map);
    return map;
  }

  /// Retrieves a map by its ObjectBox ID.
  OfflineMap? findById(int id) => _mapBox.get(id);

  /// Retrieves a map by its UUID.
  @override
  OfflineMap? findByUuid(String uuid) {
    final query = _mapBox.query(OfflineMap_.uuid.equals(uuid)).build();
    final result = query.find();
    query.close();
    return result.isEmpty ? null : result.first;
  }

  /// Returns all stored maps, ordered by creation date descending.
  List<OfflineMap> findAll() {
    final query = _mapBox
        .query()
        .order(OfflineMap_.createdAt, flags: Order.descending)
        .build();
    final result = query.find();
    query.close();
    return result;
  }

  /// Deletes a map and all its associated layers.
  bool delete(int mapId) {
    final map = _mapBox.get(mapId);
    if (map == null) return false;

    // Delete associated layers first (query by offlineMapId).
    final layerQuery = _layerBox
        .query(OfflineMapLayer_.offlineMapId.equals(mapId))
        .build();
    final layers = layerQuery.find();
    layerQuery.close();
    for (final layer in layers) {
      _layerBox.remove(layer.id);
    }
    _mapBox.remove(mapId);
    return true;
  }

  /// Deletes a map by UUID.
  bool deleteByUuid(String uuid) {
    final map = findByUuid(uuid);
    if (map == null) return false;
    return delete(map.id);
  }

  // ---- OfflineMapLayer CRUD ----

  /// Saves a layer and associates it with a map.
  @override
  OfflineMapLayer saveLayer(OfflineMap map, OfflineMapLayer layer) {
    layer.offlineMapId = map.id;
    layer.offlineMap.target = map;
    _layerBox.put(layer);
    return layer;
  }

  /// Retrieves a layer by its ObjectBox ID.
  @override
  OfflineMapLayer? findLayerById(int layerId) => _layerBox.get(layerId);

  /// Returns all layers for a given map (queried by offlineMapId).
  List<OfflineMapLayer> findLayersForMap(OfflineMap map) {
    final query = _layerBox
        .query(OfflineMapLayer_.offlineMapId.equals(map.id))
        .build();
    final layers = query.find();
    query.close();
    return layers;
  }

  /// Returns all maps that are ready or partially downloaded (eligible for offline display).
  List<OfflineMap> findReadyOrPartialMaps() {
    final query = _mapBox
        .query(
          OfflineMap_.statusIndex
              .equals(OfflineMapStatus.ready.index)
              .or(
                OfflineMap_.statusIndex.equals(OfflineMapStatus.partial.index),
              ),
        )
        .order(OfflineMap_.createdAt, flags: Order.descending)
        .build();
    final result = query.find();
    query.close();
    return result;
  }

  /// Returns layers for a map by map ID.
  List<OfflineMapLayer> findLayersByMapId(int mapId) {
    final query = _layerBox
        .query(OfflineMapLayer_.offlineMapId.equals(mapId))
        .build();
    final layers = query.find();
    query.close();
    return layers;
  }

  /// Deletes a layer by its ID.
  bool deleteLayer(int layerId) {
    return _layerBox.remove(layerId);
  }

  /// Returns the count of all maps in the store.
  int get mapCount => _mapBox.count();

  /// Returns the count of all layers in the store.
  int get layerCount => _layerBox.count();

  /// Returns `true` if a map with the given [name] (after `.trim()`) already
  /// exists in the store.
  ///
  /// Comparison is case-insensitive so that "Ma Zone" and "ma zone" are
  /// treated as the same duplicate name, and the leading/trailing
  /// whitespace tolerance matches the `.trim()` performed by the
  /// [NewZoneSheet] when persisting the user input.
  bool nameExists(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final query = _mapBox
        .query(OfflineMap_.name.equals(trimmed, caseSensitive: false))
        .build();
    final count = query.count();
    query.close();
    return count > 0;
  }
}
