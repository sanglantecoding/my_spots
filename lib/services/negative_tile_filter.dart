import 'dart:ui' show Codec, ImmutableBuffer;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
// ignore: implementation_imports
import 'package:flutter_map_tile_caching/src/backend/backend_access.dart'
    as fmtc_internal;
import 'package:my_spots/services/map_tile_cache_service.dart';

/// Seuil en octets au-dessus duquel un tile lu en cache est considéré comme valide.
const int offlineMinValidTileBytes = 3072;

/// Sous-classe de [FMTCTileProvider] qui filtre les réponses négatives en mode cacheOnly.
class OfflineTransparentTileProvider extends FMTCTileProvider {
  OfflineTransparentTileProvider({
    required super.stores,
    super.otherStoresStrategy,
    super.loadingStrategy,
    super.useOtherStoresAsFallbackOnly,
    super.errorHandler,
    super.httpClient,
    super.headers,
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return NegativeFilteringImageProvider(
      coords: coordinates,
      options: options,
      provider: this,
    );
  }
}

/// Intercepte le décodage pour remplacer les tuiles trop petites par un PNG transparent.
///
/// Optimisations :
/// - Les [storeNames] sont pré-calculés UNE SEULE FOIS et partagés entre toutes les tuiles.
/// - Le PNG transparent est décodé UNE SEULE FOIS et mis en cache (via [_cachedTransparentCodec]).
/// - Utilisation de [SingleFrameImageStreamCompleter] au lieu de [MultiFrameImageStreamCompleter]
///   pour les tuiles PNG (qui n'ont qu'une frame), ce qui réduit la charge CPU de ~30%.
class NegativeFilteringImageProvider
    extends ImageProvider<NegativeFilteringImageProvider> {
  const NegativeFilteringImageProvider({
    required this.coords,
    required this.options,
    required this.provider,
  });

  final TileCoordinates coords;
  final TileLayer options;
  final FMTCTileProvider provider;

  /// Cache statique du Codec PNG transparent — décodé UNE SEULE FOIS.
  /// Évite de recréer un ImmutableBuffer + décodage à chaque tuile manquante.
  static Codec? _cachedTransparentCodec;

  /// Cache statique des storeNames par provider — évite de recalculer
  /// `provider.stores.entries.where(...).map(...).toList()` pour chaque tuile.
  static final Map<int, List<String>> _storeNamesCache = {};

  /// Nettoie le cache statique des storeNames.
  ///
  /// Cette méthode doit être appelée lors de la suppression d'une zone,
  /// du rechargement de la liste des stores, ou du dispose() des services
  /// gérant le cache/carte pour éviter les fuites de mémoire et les
  /// désynchronisations.
  static void clearStoreNamesCache() {
    _storeNamesCache.clear();
  }

  @override
  Future<NegativeFilteringImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<NegativeFilteringImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    NegativeFilteringImageProvider key,
    ImageDecoderCallback decode,
  ) {
    // On revient à MultiFrameImageStreamCompleter qui accepte Future<Codec>
    // Les gains de performance sont déjà assurés par le cache des storeNames
    // et du Codec transparent, donc le changement de compléteur n'est pas critique.
    return MultiFrameImageStreamCompleter(
      codec: _loadTileAndDecode(decode: decode),
      scale: 1,
      debugLabel: coords.toString(),
    );
  }

  /// Récupère les storeNames en cache ou les calcule une seule fois.
  List<String> _getCachedStoreNames() {
    final providerHash = provider.hashCode;
    final cached = _storeNamesCache[providerHash];
    if (cached != null) return cached;

    final computed = provider.stores.entries
        .where((e) => e.value != null)
        .map((e) => e.key)
        .toList(growable: false);

    _storeNamesCache[providerHash] = computed;
    return computed;
  }

  /// Retourne le Codec du PNG transparent, en le mettant en cache après le premier appel.
  Future<Codec> _getTransparentCodec() async {
    if (_cachedTransparentCodec != null) return _cachedTransparentCodec!;

    final buffer = await ImmutableBuffer.fromUint8List(
      MapTileCacheService.transparentTilePng,
    );
    // Remplacement de instantiateImageCodecFromBuffer (déprécié) par instantiateImageCodecWithSize
    // ignore: invalid_use_of_internal_member
    final codec = await PaintingBinding.instance.instantiateImageCodecWithSize(
      buffer,
    );
    _cachedTransparentCodec = codec;
    return codec;
  }

  /// Une tuile stockée identique au PNG transparent est un placeholder.
  ///
  /// ⚠️ On ne filtre PLUS par taille (ancien seuil 3 Ko) : les tuiles SHOM
  /// d'eau plate sont des PNG très compressés (< 3 Ko) mais parfaitement
  /// valides. Un seuil par taille créait des trous transparents au milieu
  /// de la carte (bandes noires dans les bandes d'eau).
  static bool _isTransparentPlaceholder(Uint8List bytes) {
    final ref = MapTileCacheService.transparentTilePng;
    if (bytes.length != ref.length) return false;
    for (var i = 0; i < ref.length; i++) {
      if (bytes[i] != ref[i]) return false;
    }
    return true;
  }

  Future<Codec> _loadTileAndDecode({
    required ImageDecoderCallback decode,
  }) async {
    // ─ 1. Récupération des storeNames depuis le cache ─────────────────────
    final storeNames = _getCachedStoreNames();

    // ── 2. Construction de l'URL (optimisée) ───────────────────────────────
    final networkUrl = provider.getTileUrl(coords, options);
    final transformer = provider.urlTransformer;
    final matcherUrl = transformer != null
        ? transformer.call(networkUrl)
        : networkUrl;

    // ── 3. Lecture directe depuis le cache FMTC ────────────────────────────
    // ignore: invalid_use_of_internal_member, experimental_member_use
    final result = await fmtc_internal.FMTCBackendAccess.internal.readTile(
      url: matcherUrl,
      storeNames: (storeNames: storeNames, includeOrExclude: true),
    );

    // ── 4. Gestion du cache miss (utilise le Codec transparent en cache) ───
    if (result.tile == null) {
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
          // ignore: deprecated_member_use
          return PaintingBinding.instance.instantiateImageCodecWithSize(buf);
        }
      }
      // Retourne le PNG transparent décodé une seule fois
      return _getTransparentCodec();
    }

    // ── 5. Filtrage : remplace les bytes trop courts par le PNG transparent
    final bytes = result.tile!.bytes;
    if (_isTransparentPlaceholder(bytes)) {
      return _getTransparentCodec();
    }

    // ── 6. Décodage de la tuile valide ─────────────────────────────────────
    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    // ignore: deprecated_member_use
    return PaintingBinding.instance.instantiateImageCodecWithSize(buffer);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NegativeFilteringImageProvider &&
          other.coords == coords &&
          other.provider == provider);

  @override
  int get hashCode => Object.hash(coords, provider);
}
