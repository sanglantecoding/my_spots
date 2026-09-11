import 'dart:ui' show Codec, ImmutableBuffer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
// Accès à l'infrastructure interne de FMTC pour la lecture brute du cache.
// FMTCBackendAccess n'est pas exporté publiquement (utilisation interne only).
// ignore: implementation_imports
import 'package:flutter_map_tile_caching/src/backend/backend_access.dart'
    // ignore: invalid_use_of_internal_member
    as fmtc_internal;
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

/// Seuil en octets au-dessus duquel un tile lu en cache est considéré comme
/// un PNG SHOM valide.
///
/// En téléchargement, FMTC a stocké dans le store ObjectBox non seulement les
/// tuiles HTTP 200 (PNG cartographiques, généralement ≥ 5 Ko), mais aussi
/// certains corps de réponse HTTP 404 / erreurs SHOM (HTML/JSON court, de
/// quelques centaines d'octets à ~2 Ko). FMTC n'expose aucun drapeau
/// « negative » pour distinguer ces deux cas dans la voie `cacheOnly`, et son
/// `errorHandler` n'est jamais appelé pour un hit de cache — le tile est
/// simplement retourné en bytes.
///
/// En mode OFFLINE, ces réponses négatives sont donc resservies comme images
/// opaques, ce qui masque la couche inférieure (ex. 50k) au-dessus de laquelle
/// la couche supérieure (25k) devrait être transparente en cas d'absence.
///
/// On filtre donc systématiquement, en lecture, tout tile issu du cache dont
/// la taille est inférieure à ce seuil : il est remplacé par un PNG 1×1
/// transparent afin que la couche inférieure reste visible.
///
/// Les tuiles téléchargées avec succès font toutes plusieurs Ko ; ce seuil ne
/// peut donc jamais correspondre à un PNG cartographique valide.
const int _offlineMinValidTileBytes = 3072;

/// Sous-classe de [FMTCTileProvider] qui, en mode `cacheOnly`, filtre les
/// « tiles » stockés qui sont en réalité des corps de réponse négatifs
/// (404 / erreurs SHOM), c'est-à-dire dont la taille est anormalement petite
/// pour un PNG cartographique.
///
/// Ce filtre s'applique uniquement à la chaîne de RENDU OFFLINE :
/// - Il ne supprime rien du cache.
/// - Il n'effectue aucune requête réseau.
/// - Il n'altère pas le téléchargement.
///
/// L'`ImageProvider` Flutter produit par `FMTCTileProvider.getImage` est
/// dérouté vers un `ImageStream` qui décode les bytes reçus ; si la taille est
/// inférieure à [_offlineMinValidTileBytes], on substitue [transparentTilePng]
/// avant l'étape de décodage pour que la couche supérieure apparaisse
/// transparente et laisse voir la couche inférieure (50k).
class _OfflineTransparentTileProvider extends FMTCTileProvider {
  _OfflineTransparentTileProvider({
    required super.stores,
    super.otherStoresStrategy,
    super.loadingStrategy,
    super.useOtherStoresAsFallbackOnly,
    // Ignored: ces paramètres sont conservés pour exposer la même API
    // complète que FMTCTileProvider, mais ne sont pas utilisés par
    // _NegativeFilteringImageProvider (cache-only, sans réseau).
    // ignore: unused_element_parameter
    super.recordHitsAndMisses,
    // ignore: unused_element_parameter
    super.cachedValidDuration,
    // ignore: unused_element_parameter
    super.urlTransformer,
    super.errorHandler,
    // ignore: unused_element_parameter
    super.tileLoadingInterceptor,
    super.httpClient,
    // ignore: unused_element_parameter
    super.fakeNetworkDisconnect,
    super.headers,
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _NegativeFilteringImageProvider(
      coords: coordinates,
      options: options,
      provider: this,
      transparentBytes: MapTileCacheService.transparentTilePng,
      minValidBytes: _offlineMinValidTileBytes,
    );
  }
}

/// [ImageProvider] qui intercepte la chaîne de décodage pour remplacer les
/// tiles dont les bytes sont trop petits (réponses HTTP 404/4xx stockées en
/// cache par FMTC) par un transparent.png, AVANT l'étape de décodage.
///
/// Contrairement à [_FMTCImageProvider] (privé à FMTC), ce fournisseur :
///  1. Lit directement les bytes depuis le cache FMTC (accès interne).
///  2. Filtre sur la taille des bytes avant le décodage.
///  3. Décode via le pipeline standard [ImmutableBuffer] → [decode].
///
/// IMPORTANT : ce fournisseur ne fait AUCUNE requête réseau. Il est destiné
/// à être utilisé avec un [FMTCTileProvider] configuré en
/// `BrowseLoadingStrategy.cacheOnly` (mode hors-ligne).
class _NegativeFilteringImageProvider
    extends ImageProvider<_NegativeFilteringImageProvider> {
  const _NegativeFilteringImageProvider({
    required this.coords,
    required this.options,
    required this.provider,
    required this.transparentBytes,
    required this.minValidBytes,
  });

  final TileCoordinates coords;
  final TileLayer options;
  final FMTCTileProvider provider;
  final Uint8List transparentBytes;
  final int minValidBytes;

  @override
  Future<_NegativeFilteringImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture<_NegativeFilteringImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _NegativeFilteringImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadTileAndDecode(decode: decode),
      scale: 1,
      debugLabel: coords.toString(),
      informationCollector: () {
        final tileUrl = provider.getTileUrl(coords, options);
        return <DiagnosticsNode>[
          DiagnosticsProperty<FMTCTileProvider>('FMTCTileProvider', provider),
          DiagnosticsProperty<TileCoordinates>('Tile coordinates', coords),
          DiagnosticsProperty<String>('Tile URL', tileUrl),
        ];
      },
    );
  }

  /// Lit les bytes du cache FMTC, filtre par taille, puis décode.
  Future<Codec> _loadTileAndDecode({
    required ImageDecoderCallback decode,
  }) async {
    // ── Construire l'URL transformée (même logique que FMTC) ──────────────
    final networkUrl = provider.getTileUrl(coords, options);
    final matcherUrl = provider.urlTransformer?.call(networkUrl) ?? networkUrl;

    // ── Compiler les stores lisibles (copie de FMTCTileProvider) ───────────
    final storeNames = provider.stores.entries
        .where((e) => e.value != null)
        .map((e) => e.key)
        .toList(growable: false);

    // ── Détection LiDAR vs Marine via l'URL ──────────────────────────────
    // Les layers LiDAR SHOM ont un wmtsLayerName qui commence par L3D_ ou LITTO3D_.
    // Les layers marines commencent par RASTER_MARINE_.
    final isLidar =
        networkUrl.contains('L3D_') || networkUrl.contains('LITTO3D_');

    // Extraire le wmtsLayerName de l'URL (après &LAYER= ou &layer=)
    String? wmtsLayerName;
    final layerMatch = RegExp(
      r'[&?]LAYER=([^&]+)',
      caseSensitive: false,
    ).firstMatch(networkUrl);
    if (layerMatch != null) {
      wmtsLayerName = layerMatch.group(1);
    }

    // Déduire le lidarLayerId du wmtsLayerName via le catalogue
    String? lidarLayerId;
    if (isLidar && wmtsLayerName != null) {
      final layer = Litto3DCatalog.findByWmtsName(wmtsLayerName);
      lidarLayerId = layer?.id;
    }

    // ── Lecture directe depuis le cache FMTC ──────────────────────────────
    // ignore: invalid_use_of_internal_member, experimental_member_use
    final result = await fmtc_internal.FMTCBackendAccess.internal.readTile(
      url: matcherUrl,
      storeNames: (storeNames: storeNames, includeOrExclude: true),
    );

    if (result.tile == null) {
      // ── Log de diagnostic UNIQUEMENT pour les lectures LiDAR ────────────
      if (isLidar) {
        debugPrint(
          '[REAL-OFFLINE-LIDAR-READ] '
          'layer=$wmtsLayerName '
          'layerId=$lidarLayerId '
          'store=${storeNames.join(",")} '
          'z=${coords.z} x=${coords.x} y=${coords.y} '
          'url=$matcherUrl',
        );
        debugPrint(
          '[REAL-OFFLINE-LIDAR-RESULT] '
          'layer=$wmtsLayerName '
          'store=${storeNames.join(",")} '
          'result=MISS '
          'bytes=0',
        );
      }

      // Tile absent du cache → utiliser le errorHandler si défini
      if (provider.errorHandler != null) {
        final fallback = provider.errorHandler!(
          // ignore: invalid_use_of_internal_member
          FMTCBrowsingError(
            type: FMTCBrowsingErrorType.missingInCacheOnlyMode,
            networkUrl: networkUrl,
            storageSuitableUID: matcherUrl,
          ),
        );
        if (fallback != null) {
          final buf = await ImmutableBuffer.fromUint8List(fallback);
          return decode(buf);
        }
      }
      // ignore: invalid_use_of_internal_member
      throw FMTCBrowsingError(
        type: FMTCBrowsingErrorType.missingInCacheOnlyMode,
        networkUrl: networkUrl,
        storageSuitableUID: matcherUrl,
      );
    }

    // ── Filtrage : remplace les bytes trop courts par un PNG transparent ──
    final bytes = result.tile!.bytes;

    // ── Log de diagnostic UNIQUEMENT pour les lectures LiDAR ──────────────
    if (isLidar) {
      debugPrint(
        '[REAL-OFFLINE-LIDAR-READ] '
        'layer=$wmtsLayerName '
        'layerId=$lidarLayerId '
        'store=${storeNames.join(",")} '
        'z=${coords.z} x=${coords.x} y=${coords.y} '
        'url=$matcherUrl',
      );
      debugPrint(
        '[REAL-OFFLINE-LIDAR-RESULT] '
        'layer=$wmtsLayerName '
        'store=${storeNames.join(",")} '
        'result=HIT '
        'bytes=${bytes.length}',
      );
    }

    final bytesToDecode = bytes.length < minValidBytes
        ? transparentBytes
        : bytes;

    // ── Décodage via le pipeline standard Flutter ──────────────────────────
    final ImmutableBuffer buffer = await ImmutableBuffer.fromUint8List(
      bytesToDecode,
    );

    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _NegativeFilteringImageProvider &&
          other.coords == coords &&
          other.provider == provider);

  @override
  int get hashCode => Object.hash(coords, provider);
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

  /// Name of the old bathymetry/LiDAR general-purpose store (pre-zone-scoped).
  /// Kept as the fallback general store for LiDAR layers.
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

  /// Long-lived HTTP client to avoid "Client is already closed" errors
  static final Client _httpClient = Client();

  static String bathymetryStoreForLayer(String layerName) =>
      'bathymetryOverlay_$layerName';

  static String marineStoreForLayer(String layerName) =>
      'marineBase_$layerName';

  /// Intercepte silencieusement les erreurs FMTC et renvoie une tuile transparente
  /// pour éviter la propagation d'exceptions au thread UI.
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
      urlTransformer: null,
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

  /// Builds a [TileProvider] for marine tiles.
  ///
  /// - Without [zoneUuids] (null or empty): returns the cached general-purpose
  ///   provider (`_marineTileProviders`). The general store (`marineBase_<layer>`)
  ///   is the sole store; FMTC fetches from the network on cache miss.
  ///
  /// - With [zoneUuids]: builds a one-shot provider each call (not cached)
  ///   with the general store as the primary store (`readUpdateCreate`) and
  ///   the zone stores as read-only fallbacks. The network is always queried
  ///   first (`onlineFirst`); zone stores are consulted only on network miss.
  ///   `useOtherStoresAsFallbackOnly: true` prevents the general store from
  ///   being demoted when the zone store contains a tile.
  ///
  /// [zoneUuids] must remain optional to preserve backward compatibility with
  /// existing callers (e.g. `marine_map_service.dart:111`).
  static TileProvider marineTileProviderFor(
    String layerName, {
    List<String>? zoneUuids,
  }) {
    if (zoneUuids == null || zoneUuids.isEmpty) {
      return _marineTileProviders.putIfAbsent(layerName, () {
        return _createProvider(
          stores: {
            marineStoreForLayer(layerName):
                BrowseStoreStrategy.readUpdateCreate,
          },
          headers: shomTileHeaders,
        );
      });
    }

    // General store: primary (read + write). Zone stores: read-only fallbacks.
    final Map<String, BrowseStoreStrategy> stores = {
      marineStoreForLayer(layerName): BrowseStoreStrategy.readUpdateCreate,
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
      httpClient: _httpClient,
    );
  }

  /// Builds a [TileProvider] for bathymetry/LiDAR tiles.
  ///
  /// - Without [zoneUuids] (null or empty): returns the cached general-purpose
  ///   provider (`_bathymetryTileProviders`). The general store
  ///   (`bathymetryOverlay_<layer>`) is the sole store; FMTC fetches from the
  ///   network on cache miss.
  ///
  /// - With [zoneUuids]: builds a one-shot provider each call (not cached)
  ///   with the general store as the primary store (`readUpdateCreate`) and
  ///   the zone stores as read-only fallbacks. The network is always queried
  ///   first (`onlineFirst`); zone stores are consulted only on network miss.
  ///   `useOtherStoresAsFallbackOnly: true` prevents the general store from
  ///   being demoted when the zone store contains a tile.
  ///
  /// [zoneUuids] must remain optional to preserve backward compatibility with
  /// existing callers (e.g. `marine_map_service.dart:221`).
  static TileProvider bathymetryTileProviderFor(
    String layerName, {
    List<String>? zoneUuids,
  }) {
    if (zoneUuids == null || zoneUuids.isEmpty) {
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

    // Déduire le lidarLayerId du wmtsLayerName via le catalogue
    final lidarLayer = Litto3DCatalog.findByWmtsName(layerName);
    final lidarLayerId = lidarLayer?.id;

    final Map<String, BrowseStoreStrategy> stores = {
      bathymetryStoreForLayer(layerName): BrowseStoreStrategy.readUpdateCreate,
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
      httpClient: _httpClient,
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

  // ─── Zone-scoped FMTC stores (one store per zone, per type) ───

  /// Returns the FMTC store dedicated to marine tiles for the given zone.
  ///
  /// Naming: `marine_zone_$zoneUuid`.
  ///
  /// The caller is responsible for creating the store
  /// ([FMTCStore.manage.create]) before downloading and for disposing
  /// it via [deleteStoresForZone] when the zone is deleted.
  static FMTCStore marineStoreForZone(String zoneUuid) =>
      FMTCStore('marine_zone_$zoneUuid');

  /// Returns the FMTC store dedicated to LiDAR tiles for the given zone.
  ///
  /// Naming: `lidar_zone_$zoneUuid`.
  ///
  /// The caller is responsible for creating the store
  /// ([FMTCStore.manage.create]) before downloading and for disposing
  /// it via [deleteStoresForZone] when the zone is deleted.
  static FMTCStore lidarStoreForZone(String zoneUuid) =>
      FMTCStore('lidar_zone_$zoneUuid');

  /// Builds a [FMTCTileProvider] for a zone-scoped store.
  ///
  /// Uses only the public FMTC API ([FMTCTileProvider]).
  /// The returned provider reads from / writes to the specified [storeName].
  static TileProvider zoneTileProvider({
    required String storeName,
    required Map<String, String> headers,
  }) {
    return FMTCTileProvider(
      stores: {storeName: BrowseStoreStrategy.readUpdateCreate},
      headers: headers,
      errorHandler: handleFmtcBrowsingError,
      urlTransformer: null,
      httpClient: _httpClient,
    );
  }

  /// Builds a cache-only [FMTCTileProvider] for marine tiles (HORS-LIGNE mode).
  ///
  /// Strict offline policy:
  /// - The general `marineBase_*` FMTC store is **never** read — neither
  ///   via `stores` nor via `otherStoresStrategy` (which is `null`, so
  ///   unspecified stores are not consulted at all).
  /// - `loadingStrategy: cacheOnly` means the network is **never** queried.
  /// - `useOtherStoresAsFallbackOnly: false` is the default and is left
  ///   implicit — no other store is ever used as a fallback.
  ///
  /// Behaviour matrix:
  /// - `zoneUuids` empty:
  ///     Returns a provider whose `stores` map is **empty**. Combined with
  ///     `cacheOnly`, this means every requested tile is "missing in cache
  ///     only mode" — the FMTC error handler returns the transparent PNG
  ///     and **no HTTP request is ever made**.
  /// - `zoneUuids` non-empty:
  ///     The provider reads **only** from `marine_zone_<uuid>` stores.
  ///     Any tile that is not present in one of those stores renders
  ///     transparent. The general marine base store is completely ignored.
  static TileProvider offlineMarineTileProvider(List<String> zoneUuids) {
    if (zoneUuids.isEmpty) {
      // Empty stores + cacheOnly = every tile is missing => transparent
      // PNG via the error handler. No network, no other store consulted.
      return FMTCTileProvider(
        stores: const <String, BrowseStoreStrategy>{},
        otherStoresStrategy: null,
        loadingStrategy: BrowseLoadingStrategy.cacheOnly,
        headers: shomTileHeaders,
        errorHandler: handleFmtcBrowsingError,
        httpClient: _httpClient,
      );
    }

    final Map<String, BrowseStoreStrategy> explicitStores = {
      for (final uuid in zoneUuids)
        'marine_zone_$uuid': BrowseStoreStrategy.readUpdateCreate,
    };

    return _OfflineTransparentTileProvider(
      stores: explicitStores,
      otherStoresStrategy: null,
      loadingStrategy: BrowseLoadingStrategy.cacheOnly,
      useOtherStoresAsFallbackOnly: false,
      headers: shomTileHeaders,
      errorHandler: handleFmtcBrowsingError,
      httpClient: _httpClient,
    );
  }

  /// Builds a cache-only [FMTCTileProvider] for LiDAR/bathymetry tiles
  /// (HORS-LIGNE mode).
  ///
  /// Strict offline policy — mirror of [offlineMarineTileProvider]:
  /// - `otherStoresStrategy: null` → the general `bathymetryOverlay_*`
  ///   store is never read.
  /// - `loadingStrategy: cacheOnly` → the network is never queried.
  /// - `zoneUuids` empty → empty `stores`, all tiles render transparent.
  static TileProvider offlineLidarTileProvider(List<String> zoneUuids) {
    if (zoneUuids.isEmpty) {
      debugPrint(
        '[OFFLINE-LIDAR-PROVIDER] zoneUuids empty - returning transparent provider',
      );
      return _OfflineTransparentTileProvider(
        stores: const <String, BrowseStoreStrategy>{},
        otherStoresStrategy: null,
        loadingStrategy: BrowseLoadingStrategy.cacheOnly,
        headers: shomTileHeaders,
        errorHandler: handleFmtcBrowsingError,
        httpClient: _httpClient,
      );
    }

    debugPrint('[OFFLINE-LIDAR-PROVIDER] storeNames not empty: $zoneUuids');

    final Map<String, BrowseStoreStrategy> explicitStores = {
      for (final storeName in zoneUuids) storeName: BrowseStoreStrategy.read,
    };

    debugPrint(
      '[OFFLINE-LIDAR-PROVIDER] explicitStores: ${explicitStores.keys.toList()}',
    );

    return _OfflineTransparentTileProvider(
      stores: explicitStores,
      otherStoresStrategy: null,
      loadingStrategy: BrowseLoadingStrategy.cacheOnly,
      useOtherStoresAsFallbackOnly: false,
      headers: shomTileHeaders,
      errorHandler: handleFmtcBrowsingError,
      httpClient: _httpClient,
    );
  }

  static TileProvider? _lidarOmbrageTileProvider;

  static TileProvider lidarOmbrageTileProvider() {
    return _lidarOmbrageTileProvider ??= _OfflineTransparentTileProvider(
      stores: {lidarOmbrageStore: BrowseStoreStrategy.readUpdateCreate},
      otherStoresStrategy: null,
      loadingStrategy: BrowseLoadingStrategy.cacheOnly,
      headers: shomTileHeaders,
      errorHandler: handleFmtcBrowsingError,
      httpClient: _httpClient,
    );
  }

  /// Deletes ALL FMTC stores associated with a zone (marine + LiDAR).
  ///
  /// Uses only the public FMTC API ([FMTCStore.manage.delete]) — no
  /// direct calls to `fmtc_internal.FMTCBackendAccess.internal`.
  ///
  /// Silently ignores [StoreNotExists] errors (already absent).
  static Future<void> deleteStoresForZone(String zoneUuid) async {
    for (final store in [
      marineStoreForZone(zoneUuid),
      lidarStoreForZone(zoneUuid),
    ]) {
      try {
        await store.manage.delete();
      } catch (_) {
        // StoreNotExists or already absent — ignore.
      }
    }
  }

  /// Aggregates the size in bytes of the marine + LiDAR stores for a zone.
  ///
  /// Returns 0 if the stores do not exist or on any error.
  static Future<int> getZoneSizeBytes(String zoneUuid) async {
    final repo = FmtcTileCacheRepository.instance;
    final marineBytes = await repo.getStoreSizeBytes(
      marineStoreForZone(zoneUuid).storeName,
    );
    final lidarBytes = await repo.getStoreSizeBytes(
      lidarStoreForZone(zoneUuid).storeName,
    );
    return marineBytes + lidarBytes;
  }

  /// Formats a byte count as a human-readable French-style size string.
  ///
  /// Examples:
  /// - `formatBytes(0)` → `"0 o"`
  /// - `formatBytes(1500)` → `"1,5 Ko"`
  /// - `formatBytes(14_200_000)` → `"14,2 Mo"`
  /// - `formatBytes(2_500_000_000)` → `"2,5 Go"`
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
