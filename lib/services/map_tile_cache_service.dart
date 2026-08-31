import 'dart:async' show TimeoutException;
import 'dart:io'
    show SocketException, HttpException, HandshakeException, TlsException;

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:http/http.dart' show Client;
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
  /// Exposée publiquement pour servir de `errorImage` aux TileLayer marines.
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

  /// Long-lived HTTP client to avoid "Client is already closed" errors
  static final Client _httpClient = Client();

  static String bathymetryStoreForLayer(String layerName) =>
      'bathymetryOverlay_$layerName';

  static String marineStoreForLayer(String layerName) =>
      'marineBase_$layerName';

  /// Intercepte les erreurs FMTC attendues et renvoie une tuile transparente.
  /// TEMPORARY DEBUG: logs all errors to console instead of silencing them.
  static Uint8List? handleFmtcBrowsingError(FMTCBrowsingError error) {
    // DEBUG: Log error instead of silently swallowing
    print(
      '[SHOM-DIAG] ═══════════════════════════════════════════════════════',
    );
    print('[SHOM-DIAG] FMTC ERROR INTERCEPTED');
    print('[SHOM-DIAG]   type: ${error.type}');
    print('[SHOM-DIAG]   message: ${error.message}');
    print('[SHOM-DIAG]   networkUrl: ${error.networkUrl}');
    print('[SHOM-DIAG]   storageSuitableUID: ${error.storageSuitableUID}');
    if (error.response != null) {
      print('[SHOM-DIAG]   HTTP status: ${error.response!.statusCode}');
      print(
        '[SHOM-DIAG]   HTTP body preview: ${error.response!.body.length > 200 ? '${error.response!.body.substring(0, 200)}...' : error.response!.body}',
      );
    }
    if (error.originalError != null) {
      final orig = error.originalError;
      print('[SHOM-DIAG]   ─────── originalError (Dart exception) ───────');
      print('[SHOM-DIAG]     runtimeType: ${orig.runtimeType}');
      print('[SHOM-DIAG]     toString(): $orig');
      // Probe well-known fields/casts for common HTTP exception types
      try {
        if (orig is SocketException) {
          print('[SHOM-DIAG]     is SocketException: yes');
          print('[SHOM-DIAG]     .message: ${orig.message}');
          print('[SHOM-DIAG]     .osError (errno): ${orig.osError}');
          print('[SHOM-DIAG]     .address: ${orig.address}');
          print('[SHOM-DIAG]     .port: ${orig.port}');
        } else if (orig is HttpException) {
          print('[SHOM-DIAG]     is HttpException: yes');
          print('[SHOM-DIAG]     .message: ${orig.message}');
          print('[SHOM-DIAG]     .uri: ${orig.uri}');
        } else if (orig is HandshakeException) {
          print('[SHOM-DIAG]     is HandshakeException: yes');
          print('[SHOM-DIAG]     .message: ${orig.message}');
          print('[SHOM-DIAG]     .osError: ${orig.osError}');
        } else if (orig is TlsException) {
          print('[SHOM-DIAG]     is TlsException: yes');
          print('[SHOM-DIAG]     .message: ${orig.message}');
          print('[SHOM-DIAG]     .osError: ${orig.osError}');
        } else if (orig is TimeoutException) {
          print('[SHOM-DIAG]     is TimeoutException: yes');
          print('[SHOM-DIAG]     .message: ${orig.message}');
          print(
            '[SHOM-DIAG]     .duration: ${orig.duration?.toString() ?? "<null>"}',
          );
        }
      } catch (probeError) {
        print('[SHOM-DIAG]     field-probe error: $probeError');
      }
      // Try to capture a stack trace for the original error
      try {
        if (orig is Error) {
          print('[SHOM-DIAG]     is Error (subclass of Error): yes');
          print('[SHOM-DIAG]     .stackTrace: ${orig.stackTrace}');
        } else {
          print(
            '[SHOM-DIAG]     is Error (subclass of Error): no (it is an Exception)',
          );
        }
        final st = Error.safeToString(orig);
        print('[SHOM-DIAG]     Error.safeToString: $st');
      } catch (inner) {
        print('[SHOM-DIAG]     safeToString probe error: $inner');
      }
      print('[SHOM-DIAG]   ────────────────────────────────────────────');
    } else {
      print('[SHOM-DIAG]   originalError: <null>');
    }
    print(
      '[SHOM-DIAG] ═══════════════════════════════════════════════════════',
    );

    // TEMP: Still return transparent tile but log first
    if (MapTileErrorLogger.shouldSilence(error)) {
      MapTileErrorLogger.recordSuppressed(error);
      return _transparentTilePng;
    }
    return null;
  }

  /// DEBUG: urlTransformer that logs every tile URL for SHOM marine layers.
  /// Pass-through — returns URL unchanged.
  static String _debugUrlTransformer(String url) {
    if (url.contains('services.data.shom.fr')) {
      final zMatch = RegExp(r'TileMatrix=(\d+)').firstMatch(url);
      final xMatch = RegExp(r'TileCol=(\d+)').firstMatch(url);
      final yMatch = RegExp(r'TileRow=(\d+)').firstMatch(url);
      final layerMatch = RegExp(r'layer=([^&]+)').firstMatch(url);
      print(
        '[SHOM-DIAG] FMTC TILE REQUEST: z=${zMatch?.group(1)} x=${xMatch?.group(1)} y=${yMatch?.group(1)} layer=${layerMatch?.group(1)}',
      );
      print('[SHOM-DIAG]   URL=$url');
    }
    return url;
  }

  static FMTCTileProvider _createProvider({
    required Map<String, BrowseStoreStrategy> stores,
    required Map<String, String> headers,
  }) {
    // DEBUG: Log provider creation for marine layers
    for (final entry in stores.entries) {
      final isMarine =
          entry.key.startsWith('marineBase_') ||
          entry.key.startsWith('bathymetryOverlay_');
      if (isMarine) {
        print(
          '[SHOM-DIAG] FMTCTileProvider created for store="${entry.key}" strategy="${entry.value}"',
        );
        print('[SHOM-DIAG]   Headers: $headers');
      }
    }

    // Check if any store is marine (to apply debug urlTransformer)
    final hasMarineStore = stores.keys.any(
      (k) => k.startsWith('marineBase_') || k.startsWith('bathymetryOverlay_'),
    );

    return FMTCTileProvider(
      stores: stores,
      headers: headers,
      errorHandler: handleFmtcBrowsingError,
      urlTransformer: hasMarineStore ? _debugUrlTransformer : null,
      // Use long-lived HTTP client to avoid "Client is already closed" errors
      httpClient: _httpClient,
    );
  }

  static Future<void> initialise() async {
    if (_initialised) return;
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

  /// Supprime le cache des anciennes couches 10K après migration vers RASTER_MARINE_G_10000_WMTS_3857.
  static Future<void> _deleteLegacy10kStore() async {
    try {
      await const FMTCStore(
        'marineBase_RASTER_MARINE_10_WMTS_3857',
      ).manage.delete();
    } catch (_) {
      // Absent ou déjà supprimé.
    }
    try {
      await const FMTCStore(
        'marineBase_RASTER_MARINE_10000_WMTS_3857',
      ).manage.delete();
    } catch (_) {
      // Absent ou déjà supprimé.
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
