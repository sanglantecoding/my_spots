import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/repositories/fmtc_tile_cache_repository.dart';
import 'package:my_spots/services/negative_tile_filter.dart';

class CacheManager {
  static const String baseMapStore = 'baseMapStore';
  static const String reliefMapStore = 'reliefMapStore';
  static const String hikingMapStore = 'hikingMapStore';
  static const String _legacyBathymetryStore = 'bathymetryOverlayTiles';

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

  static Future<void> initialise() async {
    await FMTCObjectBoxBackend().initialise();
    await const FMTCStore(baseMapStore).manage.create();
    await const FMTCStore(reliefMapStore).manage.create();
    await const FMTCStore(hikingMapStore).manage.create();
    await _deleteLegacyBathymetryStore();
    await _deleteLegacy10kStore();
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

  static Future<void> _deleteLegacy10kStore() async {
    try {
      await const FMTCStore(
        'marineBase_RASTER_MARINE_10_WMTS_3857',
      ).manage.delete();
    } catch (_) {}
    try {
      await const FMTCStore(
        'marineBase_RASTER_MARINE_10000_WMTS_3857',
      ).manage.delete();
    } catch (_) {}
  }

  static Future<int> purgeTilesInBounds({
    required String storeName,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required String Function(int z, int x, int y) urlForTile,
    int tileDimension = 256,
  }) async {
    return FmtcTileCacheRepository.instance.purgeTilesInBounds(
      storeName: storeName,
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
      urlForTile: urlForTile,
      tileDimension: tileDimension,
    );
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
  }

  static Future<int> getZoneSizeBytes(String zoneUuid) async {
    final repo = FmtcTileCacheRepository.instance;

    // Marine store size
    final marineBytes = await repo.getStoreSizeBytes(
      marineStoreForZone(zoneUuid).storeName,
    );

    // All lidar stores for this zone (both new and legacy formats)
    final lidarBytes = await repo.getTotalSizeByPrefix('lidar_zone_$zoneUuid');

    return marineBytes + lidarBytes;
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

  /// Cleans up legacy LiDAR stores that don't follow the new 3-segment format.
  ///
  /// New format: `lidar_zone_<uuid>_<layerId>` (3 segments after prefix)
  /// Legacy format: `lidar_zone_<uuid>` (2 segments after prefix)
  ///
  /// This method identifies and deletes all lidar_zone_* stores that have only
  /// 2 segments (legacy format), preserving the new 3-segment stores.
  static Future<void> cleanLegacyLidarStores() async {
    final repo = FmtcTileCacheRepository.instance;
    try {
      final storeNames = await repo.listStores();
      for (final name in storeNames) {
        if (name.startsWith('lidar_zone_')) {
          final segments = name.split('_');
          // New format: ['lidar', 'zone', '<uuid>', '<layerId>'] (4 segments)
          // Legacy format: ['lidar', 'zone', '<uuid>'] (3 segments)
          if (segments.length == 3) {
            // This is a legacy store, delete it
            try {
              final store = FMTCStore(name);
              await store.manage.delete();
            } catch (_) {
              // Ignore errors for individual stores
            }
          }
        }
      }
    } catch (_) {
      // Ignore errors if listing fails
    }

    // Invalidate the store names cache after cleaning up legacy stores
    NegativeFilteringImageProvider.clearStoreNamesCache();
  }
}
