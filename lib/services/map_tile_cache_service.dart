import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/services/tile_cache/cache_manager.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';

class MapTileCacheService {
  MapTileCacheService._();

  static const String baseMapStore = CacheManager.baseMapStore;
  static const String reliefMapStore = CacheManager.reliefMapStore;
  static const String hikingMapStore = CacheManager.hikingMapStore;
  static const String packageName = TileProviderFactory.packageName;
  static String get appVersion => TileProviderFactory.appVersion;

  static List<String> get bathymetryLayerNames =>
      CacheManager.bathymetryLayerNames;
  static const List<String> marineLayerNames = CacheManager.marineLayerNames;

  static Uint8List get transparentTilePng =>
      TileProviderFactory.transparentTilePng;

  static Future<void> initialise() async => CacheManager.initialise();

  static Future<int> purgeTilesInBounds({
    required String storeName,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required String Function(int z, int x, int y) urlForTile,
    int tileDimension = 256,
  }) async {
    return CacheManager.purgeTilesInBounds(
      storeName: storeName,
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
      urlForTile: urlForTile,
      tileDimension: tileDimension,
    );
  }

  static FMTCStore marineStoreForZone(String zoneUuid) =>
      CacheManager.marineStoreForZone(zoneUuid);
  static FMTCStore lidarStoreForZone(String zoneUuid) =>
      CacheManager.lidarStoreForZone(zoneUuid);

  static Future<void> deleteStoresForZone(String zoneUuid) async =>
      CacheManager.deleteStoresForZone(zoneUuid);
  static Future<int> getZoneSizeBytes(String zoneUuid) async =>
      CacheManager.getZoneSizeBytes(zoneUuid);
  static String formatBytes(int bytes) => CacheManager.formatBytes(bytes);

  static TileProvider marineTileProviderFor(
    String layerName, {
    List<String>? zoneUuids,
  }) => TileProviderFactory.marineTileProviderFor(
    layerName,
    zoneUuids: zoneUuids,
  );

  static TileProvider bathymetryTileProviderFor(
    String layerName, {
    List<String>? zoneUuids,
  }) => TileProviderFactory.bathymetryTileProviderFor(
    layerName,
    zoneUuids: zoneUuids,
  );

  static TileProvider offlineMarineTileProvider(List<String> zoneUuids) =>
      TileProviderFactory.offlineMarineTileProvider(zoneUuids);

  static TileProvider offlineLidarTileProvider(List<String> zoneUuids) =>
      TileProviderFactory.offlineLidarTileProvider(zoneUuids);

  static TileProvider lidarOmbrageTileProvider() =>
      TileProviderFactory.lidarOmbrageTileProvider();

  /// Returns a tile provider for the standard base map types (standard, relief, hiking).
  /// For marine map type, use [MarineMapService.getActiveMarineTileLayer] instead.
  /// Returns null for standard map types to let flutter_map use the default network provider.
  static TileProvider? getTileProviderForMapType(MapType mapType) {
    switch (mapType) {
      case MapType.standard:
      case MapType.relief:
      case MapType.hiking:
        // These map types use standard URL template, no custom provider needed.
        // Return null to let flutter_map use the default network tile provider.
        return null;
      case MapType.marine:
        // Marine uses MarineMapService, not a single tile provider.
        throw StateError(
          'Marine map type uses MarineMapService.getLayers(), '
          'not getTileProviderForMapType().',
        );
    }
  }
}
