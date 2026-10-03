import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/repositories/fmtc_tile_cache_repository.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';
import 'package:my_spots/services/negative_tile_filter.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart'
    show TileProviderFactory;

class CacheManager {
  static const String baseMapStore = 'baseMapStore';
  static const String reliefMapStore = 'reliefMapStore';
  static const String hikingMapStore = 'hikingMapStore';
  static const String _legacyBathymetryStore = 'bathymetryOverlayTiles';
  static final Map<String, int> _zoneSizeCache = {};

  static List<String> get bathymetryLayerNames =>
      Litto3DCatalog.allLayers.map((l) => l.wmtsLayerName).toList();

  static const List<String> marineLayerNames = [
    'RASTER_MARINE_3857_WMTS',
    'RASTER_MARINE_1M_3857_WMTS',
    'RASTER_MARINE_350_WMTS_3857',
    'RASTER_MARINE_100_WMTS_3857',
    'RASTER_MARINE_50_WMTS_3857',
    'RASTER_MARINE_25_WMTS_3857',
    'RASTER_MARINE_10_WMTS_3857',
  ];

  static String bathymetryStoreForLayer(String layerName) =>
      'bathymetryOverlay_$layerName';
  static String marineStoreForLayer(String layerName) =>
      'marineBase_$layerName';

  /// Poids moyen constaté d'une tuile PNG 256 px par type de couche (octets).
  /// Sert uniquement à l'estimation de taille quand la stat FMTC est muette
  /// ou fausse (le backend ObjectBox ne renvoie que l'overhead du store).
  static const Map<LayerType, int> _avgTileBytes = {
    LayerType.marine50k: 14 * 1024,
    LayerType.marine25k: 20 * 1024,
    LayerType.marine10k: 28 * 1024,
    LayerType.lidarLitto3d: 32 * 1024,
  };

  static Future<void> initialise() async {
    await FMTCObjectBoxBackend().initialise();
    await const FMTCStore(baseMapStore).manage.create();
    await const FMTCStore(reliefMapStore).manage.create();
    await const FMTCStore(hikingMapStore).manage.create();
    await _deleteLegacyBathymetryStore();
    for (final layerName in bathymetryLayerNames) {
      await FMTCStore(bathymetryStoreForLayer(layerName)).manage.create();
    }
    for (final layerName in marineLayerNames) {
      await FMTCStore(marineStoreForLayer(layerName)).manage.create();
    }
  }

  static Future<void> _deleteLegacyBathymetryStore() async {
    try {
      await const FMTCStore(_legacyBathymetryStore).manage.delete();
    } catch (_) {}
  }

  static FMTCStore marineStoreForZone(String zoneUuid) =>
      FMTCStore('marine_zone_$zoneUuid');
  static FMTCStore lidarStoreForZone(String zoneUuid) =>
      FMTCStore('lidar_zone_$zoneUuid');

  static Future<void> deleteStoresForZone(String zoneUuid) async {
    final repo = FmtcTileCacheRepository.instance;
    // Delete marine store
    try {
      await marineStoreForZone(zoneUuid).manage.delete();
    } catch (_) {}
    // Delete new format lidar stores: lidar_zone_<uuid>_<layerId>
    try {
      await repo.deleteStoresByPrefix('lidar_zone_$zoneUuid');
    } catch (_) {}
    // Delete legacy format lidar store: lidar_zone_<uuid> (if exists)
    try {
      await lidarStoreForZone(zoneUuid).manage.delete();
    } catch (_) {}
    // Invalidate the store names cache to avoid stale references
    NegativeFilteringImageProvider.clearStoreNamesCache();
    TileProviderFactory.clearZoneProviderCaches();
    // 🟢 Invalidation du cache de taille
    _zoneSizeCache.remove(zoneUuid);
  }

  /// Taille estimée d'une zone hors-ligne (octets).
  ///
  /// Croise deux sources :
  /// 1. la stat FMTC (somme des stores de la zone) — fiable uniquement si le
  ///   backend renvoie bien la somme des octets des tuiles ;
  /// 2. une estimation basée sur les compteurs RÉELS de tuiles téléchargées
  ///   (persistés par couche dans ObjectBox) × poids moyen constaté par type.
  ///
  /// On retient le max des deux : si FMTC renvoie une valeur crédible elle
  /// domine, sinon l'estimation garantit le bon ordre de grandeur (fini les
  /// « quelques Ko » à côté de milliers de tuiles).
  ///
  /// 🟢 Les résultats sont mis en cache mémoire. L'invalidation se fait
  /// via [invalidateZoneSizeCache] (fin de téléchargement, suppression).
  static Future<int> getZoneSizeBytes(String zoneUuid) async {
    final cached = _zoneSizeCache[zoneUuid];
    if (cached != null) return cached;

    final repo = FmtcTileCacheRepository.instance;
    // 1) Taille déclarée par FMTC (marine + tous les stores LiDAR de la zone).
    final marineBytes = await repo.getStoreSizeBytes(
      marineStoreForZone(zoneUuid).storeName,
    );
    final lidarBytes = await repo.getTotalSizeByPrefix('lidar_zone_$zoneUuid');
    final fmtcBytes = marineBytes + lidarBytes;
    // 2) Estimation depuis les compteurs réels de tuiles téléchargées.
    var estimatedBytes = 0;
    final mapRepo = OfflineMapRepository.instance;
    final map = mapRepo?.findByUuid(zoneUuid);
    if (map != null) {
      for (final layer in mapRepo!.findLayersForMap(map)) {
        final avg = _avgTileBytes[layer.layerType] ?? 20 * 1024;
        estimatedBytes += layer.downloadedTileCount * avg;
      }
    }
    final result = estimatedBytes > fmtcBytes ? estimatedBytes : fmtcBytes;
    _zoneSizeCache[zoneUuid] = result;
    return result;
  }

  /// Invalide le cache de taille pour une zone (fin de téléchargement,
  /// suppression, mise à jour).
  static void invalidateZoneSizeCache(String zoneUuid) {
    _zoneSizeCache.remove(zoneUuid);
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 o';
    const units = ['o', 'Ko', 'Mo', 'Go', 'To'];
    var value = bytes.toDouble();
    var unitIdx = 0;
    while (value >= 1024 && unitIdx < units.length - 1) {
      value /= 1024;
      unitIdx++;
    }
    final rounded = value < 10
        ? value.toStringAsFixed(1).replaceAll('.', ',')
        : value.toStringAsFixed(0);
    return '$rounded ${units[unitIdx]}';
  }
}
