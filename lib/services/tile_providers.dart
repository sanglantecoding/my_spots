import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';

class TileProviders {
  static Map<String, String> get geoplateformeTileHeaders =>
      TileProviderFactory.geoplateformeTileHeaders;
  static Map<String, String> get shomTileHeaders =>
      TileProviderFactory.shomTileHeaders;

  static FMTCTileProvider createProvider({
    required Map<String, BrowseStoreStrategy> stores,
    required Map<String, String> headers,
  }) => TileProviderFactory.createProvider(stores: stores, headers: headers);

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
