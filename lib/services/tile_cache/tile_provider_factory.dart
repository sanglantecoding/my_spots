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

  // ── Caches de providers : instances STABLES, taille BORNÉE ────────────────
  // flutter_map reset les tuiles d'une TileLayer quand l'instance de
  // tileProvider change.
  static const int _maxProvidersPerCache = 8;

  static final _marineTileProviders = _BoundedProviderCache(
    _maxProvidersPerCache,
  );
  static final _marineZoneProviders = _BoundedProviderCache(
    _maxProvidersPerCache,
  );
  static final _bathymetryTileProviders = _BoundedProviderCache(
    _maxProvidersPerCache,
  );
  static final _bathymetryZoneProviders = _BoundedProviderCache(
    _maxProvidersPerCache,
  );
  static final _offlineMarineProviders = _BoundedProviderCache(
    _maxProvidersPerCache,
  );
  static final _offlineLidarProviders = _BoundedProviderCache(
    _maxProvidersPerCache,
  );

  static String _zonesKey(List<String> zones) =>
      (List<String>.from(zones)..sort()).join(',');

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
    }
    final key = '$layerName|${_zonesKey(zoneUuids)}';
    return _marineZoneProviders.putIfAbsent(key, () {
      return FMTCTileProvider(
        stores: {
          CacheManager.marineStoreForLayer(layerName):
              BrowseStoreStrategy.readUpdateCreate,
          for (final uuid in zoneUuids)
            'marine_zone_$uuid': BrowseStoreStrategy.read,
        },
        otherStoresStrategy: BrowseStoreStrategy.read,
        loadingStrategy: BrowseLoadingStrategy.onlineFirst,
        useOtherStoresAsFallbackOnly: true,
        headers: shomTileHeaders,
        errorHandler: handleFmtcBrowsingError,
        httpClient: httpClient,
      );
    });
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
    final key = '$layerName|${_zonesKey(zoneUuids)}|${lidarLayerId ?? ''}';
    return _bathymetryZoneProviders.putIfAbsent(key, () {
      return FMTCTileProvider(
        stores: {
          CacheManager.bathymetryStoreForLayer(layerName):
              BrowseStoreStrategy.readUpdateCreate,
          for (final uuid in zoneUuids)
            if (lidarLayerId != null)
              'lidar_zone_${uuid}_$lidarLayerId': BrowseStoreStrategy.read
            else
              'lidar_zone_$uuid': BrowseStoreStrategy.read,
        },
        otherStoresStrategy: BrowseStoreStrategy.read,
        loadingStrategy: BrowseLoadingStrategy.onlineFirst,
        useOtherStoresAsFallbackOnly: true,
        headers: shomTileHeaders,
        errorHandler: handleFmtcBrowsingError,
        httpClient: httpClient,
      );
    });
  }

  /// Vide tous les caches de providers qui dépendent des UUIDs de zones.
  /// Doit être appelé à chaque suppression de zone pour éviter de conserver
  /// des providers pointant vers des stores FMTC détruits.
  static void clearZoneProviderCaches() {
    _marineZoneProviders.clear();
    _bathymetryZoneProviders.clear();
    _offlineMarineProviders.clear();
    _offlineLidarProviders.clear();
  }

  static TileProvider offlineMarineTileProvider(List<String> zoneUuids) {
    final key = _zonesKey(zoneUuids);
    return _offlineMarineProviders.putIfAbsent(key, () {
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
      return OfflineTransparentTileProvider(
        stores: {
          for (final uuid in zoneUuids)
            'marine_zone_$uuid': BrowseStoreStrategy.read,
        },
        otherStoresStrategy: null,
        loadingStrategy: BrowseLoadingStrategy.cacheOnly,
        useOtherStoresAsFallbackOnly: false,
        headers: shomTileHeaders,
        errorHandler: handleFmtcBrowsingError,
        httpClient: httpClient,
      );
    });
  }

  static TileProvider offlineLidarTileProvider(List<String> zoneUuids) {
    final key = _zonesKey(zoneUuids);
    return _offlineLidarProviders.putIfAbsent(key, () {
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
      return OfflineTransparentTileProvider(
        stores: {
          for (final storeName in zoneUuids)
            storeName: BrowseStoreStrategy.read,
        },
        otherStoresStrategy: null,
        loadingStrategy: BrowseLoadingStrategy.cacheOnly,
        useOtherStoresAsFallbackOnly: false,
        headers: shomTileHeaders,
        errorHandler: handleFmtcBrowsingError,
        httpClient: httpClient,
      );
    });
  }
}

/// Cache LRU borné de [TileProvider].
///
/// Les [Map] Dart préservent l'ordre d'insertion : un `remove` + réinsertion
/// sur accès marque l'entrée comme récente, et l'éviction retire simplement
/// la première clé quand la borne [_BoundedProviderCache.maxEntries] est
/// dépassée. Complexité O(1) par opération.
///
/// Évincer un provider encore monté dans un [TileLayer] est sans danger :
/// l'instance reste référencée par le widget ; seul un rebuild futur avec
/// la même clé recréerait une instance (cas rare : clés évincées =
/// combinaisons de zones historiques).
class _BoundedProviderCache {
  _BoundedProviderCache(this.maxEntries);

  final int maxEntries;
  final Map<String, TileProvider> _entries = {};

  TileProvider putIfAbsent(String key, TileProvider Function() create) {
    final existing = _entries.remove(key);
    if (existing != null) {
      _entries[key] = existing;
      return existing;
    }
    final created = create();
    _entries[key] = created;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return created;
  }

  void clear() => _entries.clear();
}
