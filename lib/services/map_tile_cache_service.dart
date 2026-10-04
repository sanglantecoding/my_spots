import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:my_spots/services/tile_cache/cache_manager.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';

class MapTileCacheService {
  MapTileCacheService._();

  static const String packageName = TileProviderFactory.packageName;

  static List<String> get bathymetryLayerNames =>
      CacheManager.bathymetryLayerNames;

  static const List<String> marineLayerNames = CacheManager.marineLayerNames;

  static Uint8List get transparentTilePng =>
      TileProviderFactory.transparentTilePng;

  static Future<void> initialise() async => CacheManager.initialise();

  static FMTCStore marineStoreForZone(String zoneUuid) =>
      CacheManager.marineStoreForZone(zoneUuid);

  static FMTCStore lidarStoreForZone(String zoneUuid) =>
      CacheManager.lidarStoreForZone(zoneUuid);

  static Future<void> deleteStoresForZone(String zoneUuid) async =>
      CacheManager.deleteStoresForZone(zoneUuid);

  static Future<int> getZoneSizeBytes(String zoneUuid) async =>
      CacheManager.getZoneSizeBytes(zoneUuid);

  /// Invalide le cache mémoire de taille pour une zone.
  static void invalidateZoneSizeCache(String zoneUuid) =>
      CacheManager.invalidateZoneSizeCache(zoneUuid);

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
}
