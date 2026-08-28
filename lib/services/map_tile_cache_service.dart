import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/repositories/fmtc_tile_cache_repository.dart';

/// Journalisation des erreurs tuiles — désactivée pour éviter la saturation du thread principal.
class MapTileErrorLogger {
  MapTileErrorLogger._();

  /// Erreurs réseau / cache attendues hors-ligne : toujours silencieux.
  static bool shouldSilence(Object error) {
    return true;
  }

  static void recordSuppressed([Object? error]) {
    // Ne rien faire pour éviter l'accumulation en mémoire
  }

  static void logTileError(
    TileImage tile,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    // Ne rien faire pour éviter la saturation du thread principal
  }
}

/// Cache local des tuiles cartographiques (FMTC) pour usage hors-ligne.
class MapTileCacheService {
  static const String baseMapStore = 'baseMapStore';
  static const String reliefMapStore = 'reliefMapStore';
  static const String hikingMapStore = 'hikingMapStore';

  /// Ancien store unique Litto3D. Remplacé par [bathymetryStoreForLayer].
  /// Conservé uniquement pour supprimer le cache legacy encore présent sur disque.
  static const String _legacyBathymetryStore = 'bathymetryOverlayTiles';

  /// Couches Litto3D empilées dans l'overlay bathymétrie.
  static List<String> get bathymetryLayerNames =>
      Litto3DCatalog.allLayers.map((l) => l.wmtsLayerName).toList();

  /// Cartes marines RasterMarine empilées par échelle (clevisu SHOM).
  static const List<String> marineLayerNames = [
    'RASTER_MARINE_3857_WMTS',
    'RASTER_MARINE_1M_3857_WMTS',
    'RASTER_MARINE_350_WMTS_3857',
    'RASTER_MARINE_100_WMTS_3857',
    'RASTER_MARINE_50_WMTS_3857',
    'RASTER_MARINE_25_WMTS_3857',
    'RASTER_MARINE_10_WMTS_3857',
  ];

  /// Relief LiDAR ombré — store FMTC `marineBase_LIDAR_OMBRAGE_WMTS`.
  static const String lidarOmbrageLayerName = 'LIDAR_OMBRAGE_WMTS';

  static String get lidarOmbrageStore =>
      marineStoreForLayer(lidarOmbrageLayerName);

  static const String packageName = 'com.svc.my_spots';
  static const String appVersion = '1.0.0';

  /// PNG 1×1 transparent — évite la propagation d'exceptions FMTC au UI thread.
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

  static Map<String, String> get geoplateformeTileHeaders => {
    'User-Agent': '$packageName/$appVersion (Flutter)',
    'Accept': 'image/webp,image/png,image/*;q=0.8',
  };

  static Map<String, String> get shomTileHeaders => {
    ...geoplateformeTileHeaders,
    'Referer': 'https://data.shom.fr/',
  };

  static bool _initialised = false;
  static final Map<String, TileProvider> _bathymetryTileProviders = {};
  static final Map<String, TileProvider> _marineTileProviders = {};
  static TileProvider? _lidarOmbrageTileProvider;

  static String bathymetryStoreForLayer(String layerName) =>
      'bathymetryOverlay_$layerName';

  static String marineStoreForLayer(String layerName) =>
      'marineBase_$layerName';

  /// Intercepte les erreurs FMTC attendues et renvoie une tuile transparente.
  static Uint8List? handleFmtcBrowsingError(FMTCBrowsingError error) {
    if (MapTileErrorLogger.shouldSilence(error)) {
      MapTileErrorLogger.recordSuppressed(error);
      return _transparentTilePng;
    }
    return null;
  }

  static FMTCTileProvider _createProvider({
    required Map<String, BrowseStoreStrategy> stores,
    required Map<String, String> headers,
  }) {
    return FMTCTileProvider(
      stores: stores,
      headers: headers,
      errorHandler: handleFmtcBrowsingError,
    );
  }

  static Future<void> initialise() async {
    if (_initialised) return;
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
    await FMTCStore(lidarOmbrageStore).manage.create();
    _initialised = true;
  }

  /// Supprime le store bathymétrie unique d'avant le cache par couche.
  static Future<void> _deleteLegacyBathymetryStore() async {
    try {
      await const FMTCStore(_legacyBathymetryStore).manage.delete();
    } catch (_) {
      // Absent ou déjà migré.
    }
  }

  static final TileProvider baseMapTileProvider = _createProvider(
    stores: {baseMapStore: BrowseStoreStrategy.readUpdateCreate},
    headers: geoplateformeTileHeaders,
  );

  static final TileProvider reliefMapTileProvider = _createProvider(
    stores: {reliefMapStore: BrowseStoreStrategy.readUpdateCreate},
    headers: geoplateformeTileHeaders,
  );

  static final TileProvider hikingMapTileProvider = _createProvider(
    stores: {hikingMapStore: BrowseStoreStrategy.readUpdateCreate},
    headers: geoplateformeTileHeaders,
  );

  static TileProvider getTileProviderForMapType(MapType mapType) {
    switch (mapType) {
      case MapType.standard:
        return baseMapTileProvider;
      case MapType.relief:
        return reliefMapTileProvider;
      case MapType.hiking:
        return hikingMapTileProvider;
      case MapType.marine:
        throw StateError(
          'La carte marine utilise MarineMapService.getLayers(), pas getTileProviderForMapType().',
        );
    }
  }

  static TileProvider marineTileProviderFor(String layerName) {
    return _marineTileProviders.putIfAbsent(layerName, () {
      return _createProvider(
        stores: {
          marineStoreForLayer(layerName): BrowseStoreStrategy.readUpdateCreate,
        },
        headers: shomTileHeaders,
      );
    });
  }

  static TileProvider bathymetryTileProviderFor(String layerName) {
    return _bathymetryTileProviders.putIfAbsent(layerName, () {
      return _createProvider(
        stores: {
          bathymetryStoreForLayer(layerName):
              BrowseStoreStrategy.readUpdateCreate,
        },
        headers: shomTileHeaders,
      );
    });
  }

  static TileProvider lidarOmbrageTileProvider() {
    return _lidarOmbrageTileProvider ??= _createProvider(
      stores: {lidarOmbrageStore: BrowseStoreStrategy.readUpdateCreate},
      headers: shomTileHeaders,
    );
  }

  /// Supprime du [storeName] uniquement les tuiles couvrant [bounds] (z min–max).
  ///
  /// N'affecte pas les tuiles hors du rectangle — y compris celles mises en
  /// cache lors de la navigation ailleurs sur la carte.
  static Future<int> purgeTilesInBounds({
    required String storeName,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required String Function(int z, int x, int y) urlForTile,
    int tileDimension = 256,
  }) async {
    await initialise();

    // Delegate to repository to abstract FMTC internal API
    return FmtcTileCacheRepository.instance.purgeTilesInBounds(
      storeName: storeName,
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
      urlForTile: urlForTile,
      tileDimension: tileDimension,
    );
  }
}
