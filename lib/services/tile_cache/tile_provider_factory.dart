import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:http/http.dart' show Client;
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/services/tile_cache/cache_manager.dart';
import 'package:my_spots/services/negative_tile_filter.dart';

class TileProviderFactory {
  static const String packageName = 'com.svc.my_spots';
  static String appVersion = '1.0.0';
  static final Client httpClient = Client();

  static Map<String, String> get geoplateformeTileHeaders => {
    'User-Agent': '$packageName/$appVersion (Flutter)',
    'Accept': 'image/webp,image/png,image/*;q=0.8',
  };

  static Map<String, String> get shomTileHeaders => {
    ...geoplateformeTileHeaders,
    'Referer': 'https://data.shom.fr/',
  };

  static Uint8List get transparentTilePng => _transparentTilePng;
  static final Uint8List _transparentTilePng = Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

  static Uint8List? handleFmtcBrowsingError(FMTCBrowsingError error) {
    return _transparentTilePng;
  }

  static FMTCTileProvider createProvider({
    required Map<String, BrowseStoreStrategy> stores,
    required Map<String, String> headers,
  }) {
    return FMTCTileProvider(
      stores: stores,
      headers: headers,
      errorHandler: handleFmtcBrowsingError,
      httpClient: httpClient,
    );
  }

  static TileProvider marineTileProviderFor(
    String layerName, {
    List<String>? zoneUuids,
  }) {
    if (zoneUuids == null || zoneUuids.isEmpty) {
      return _marineTileProviders.putIfAbsent(layerName, () {
        return createProvider(
          stores: {
            CacheManager.marineStoreForLayer(layerName):
                BrowseStoreStrategy.readUpdateCreate,
          },
          headers: shomTileHeaders,
        );
      });
    } else {
      final Map<String, BrowseStoreStrategy> stores = {
        CacheManager.marineStoreForLayer(layerName):
            BrowseStoreStrategy.readUpdateCreate,
        for (final uuid in zoneUuids)
          'marine_zone_$uuid': BrowseStoreStrategy.read,
      };
      return FMTCTileProvider(
        stores: stores,
        otherStoresStrategy: BrowseStoreStrategy.read,
        loadingStrategy: BrowseLoadingStrategy.onlineFirst,
        useOtherStoresAsFallbackOnly: true,
        headers: shomTileHeaders,
        errorHandler: handleFmtcBrowsingError,
        httpClient: httpClient,
      );
    }
  }

  static TileProvider bathymetryTileProviderFor(
    String layerName, {
    List<String>? zoneUuids,
  }) {
    if (zoneUuids == null || zoneUuids.isEmpty) {
      return _bathymetryTileProviders.putIfAbsent(layerName, () {
        return createProvider(
          stores: {
            CacheManager.bathymetryStoreForLayer(layerName):
                BrowseStoreStrategy.readUpdateCreate,
          },
          headers: shomTileHeaders,
        );
      });
    }
    final lidarLayer = Litto3DCatalog.findByWmtsName(layerName);
    final lidarLayerId = lidarLayer?.id;
    final Map<String, BrowseStoreStrategy> stores = {
      CacheManager.bathymetryStoreForLayer(layerName):
          BrowseStoreStrategy.readUpdateCreate,
      for (final uuid in zoneUuids)
        if (lidarLayerId != null)
          'lidar_zone_${uuid}_$lidarLayerId': BrowseStoreStrategy.read
        else
          'lidar_zone_$uuid': BrowseStoreStrategy.read,
    };
    return FMTCTileProvider(
      stores: stores,
      otherStoresStrategy: BrowseStoreStrategy.read,
      loadingStrategy: BrowseLoadingStrategy.onlineFirst,
      useOtherStoresAsFallbackOnly: true,
      headers: shomTileHeaders,
      errorHandler: handleFmtcBrowsingError,
      httpClient: httpClient,
    );
  }

  static TileProvider offlineMarineTileProvider(List<String> zoneUuids) {
    if (zoneUuids.isEmpty) {
      return FMTCTileProvider(
        stores: const <String, BrowseStoreStrategy>{},
        otherStoresStrategy: null,
        loadingStrategy: BrowseLoadingStrategy.cacheOnly,
        headers: shomTileHeaders,
        errorHandler: handleFmtcBrowsingError,
        httpClient: httpClient,
      );
    }
    final Map<String, BrowseStoreStrategy> explicitStores = {
      for (final uuid in zoneUuids)
        'marine_zone_$uuid': BrowseStoreStrategy.read,
    };
    return OfflineTransparentTileProvider(
      stores: explicitStores,
      otherStoresStrategy: null,
      loadingStrategy: BrowseLoadingStrategy.cacheOnly,
      useOtherStoresAsFallbackOnly: false,
      headers: shomTileHeaders,
      errorHandler: handleFmtcBrowsingError,
      httpClient: httpClient,
    );
  }

  static TileProvider offlineLidarTileProvider(List<String> zoneUuids) {
    if (zoneUuids.isEmpty) {
      return OfflineTransparentTileProvider(
        stores: const <String, BrowseStoreStrategy>{},
        otherStoresStrategy: null,
        loadingStrategy: BrowseLoadingStrategy.cacheOnly,
        headers: shomTileHeaders,
        errorHandler: handleFmtcBrowsingError,
        httpClient: httpClient,
      );
    }
    final Map<String, BrowseStoreStrategy> explicitStores = {
      for (final storeName in zoneUuids) storeName: BrowseStoreStrategy.read,
    };
    return OfflineTransparentTileProvider(
      stores: explicitStores,
      otherStoresStrategy: null,
      loadingStrategy: BrowseLoadingStrategy.cacheOnly,
      useOtherStoresAsFallbackOnly: false,
      headers: shomTileHeaders,
      errorHandler: handleFmtcBrowsingError,
      httpClient: httpClient,
    );
  }

  static TileProvider? _lidarOmbrageTileProvider;
  static TileProvider lidarOmbrageTileProvider() {
    return _lidarOmbrageTileProvider ??= OfflineTransparentTileProvider(
      stores: {
        CacheManager.marineStoreForLayer('LIDAR_OMBRAGE_WMTS'):
            BrowseStoreStrategy.readUpdateCreate,
      },
      otherStoresStrategy: null,
      loadingStrategy: BrowseLoadingStrategy.cacheOnly,
      headers: shomTileHeaders,
      errorHandler: handleFmtcBrowsingError,
      httpClient: httpClient,
    );
  }

  static final Map<String, TileProvider> _bathymetryTileProviders = {};
  static final Map<String, TileProvider> _marineTileProviders = {};
}
