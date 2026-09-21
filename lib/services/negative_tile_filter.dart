import 'dart:ui' show Codec, ImmutableBuffer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
// ignore: implementation_imports
import 'package:flutter_map_tile_caching/src/backend/backend_access.dart'
    as fmtc_internal;
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/tile_cache/message_tile_provider.dart';

/// Sous-classe de [FMTCTileProvider] qui gère les tuiles absentes en cacheOnly.
class OfflineTransparentTileProvider extends FMTCTileProvider {
  OfflineTransparentTileProvider({
    required super.stores,
    super.otherStoresStrategy,
    super.loadingStrategy,
    super.useOtherStoresAsFallbackOnly,
    super.errorHandler,
    super.httpClient,
    super.headers,
    this.missingTileMessage = false,
  });

  /// Si `true`, une tuile ABSENTE du cache renvoie la tuile-message
  /// « Dézoomez » au lieu d'un PNG transparent.
  ///
  /// À n'activer QUE sur la couche marine du BAS en hors-ligne : sinon les
  /// couches supérieures dessineraient un texte fantôme au-dessus de la
  /// carte téléchargée. Le LiDAR hors-ligne reste à `false`.
  final bool missingTileMessage;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return NegativeFilteringImageProvider(
      coords: coordinates,
      options: options,
      provider: this,
      showMessageOnMiss: missingTileMessage,
    );
  }
}

/// Intercepte le décodage : tuile absente/placeholder → transparent OU
/// message « Dézoomez » selon [showMessageOnMiss].
class NegativeFilteringImageProvider
    extends ImageProvider<NegativeFilteringImageProvider> {
  const NegativeFilteringImageProvider({
    required this.coords,
    required this.options,
    required this.provider,
    this.showMessageOnMiss = false,
  });

  final TileCoordinates coords;
  final TileLayer options;
  final FMTCTileProvider provider;
  final bool showMessageOnMiss;

  static Codec? _cachedTransparentCodec;
  static Codec? _cachedMessageCodec;
  static final Map<int, List<String>> _storeNamesCache = {};

  /// À appeler à la suppression d'une zone (stores invalidés).
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
    return MultiFrameImageStreamCompleter(
      codec: _loadTileAndDecode(decode: decode),
      scale: 1,
      debugLabel: coords.toString(),
    );
  }

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

  Future<Codec> _getTransparentCodec() async {
    if (_cachedTransparentCodec != null) return _cachedTransparentCodec!;
    final buffer = await ImmutableBuffer.fromUint8List(
      MapTileCacheService.transparentTilePng,
    );
    // ignore: invalid_use_of_internal_member
    final codec = await PaintingBinding.instance.instantiateImageCodecWithSize(
      buffer,
    );
    // ⚠️ PAS de buffer.dispose() : le codec possède le buffer.
    _cachedTransparentCodec = codec;
    return codec;
  }

  Future<Codec> _getMessageCodec() async {
    if (_cachedMessageCodec != null) return _cachedMessageCodec!;
    final bytes = await MessageTileProvider.getTileBytes();
    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    // ignore: invalid_use_of_internal_member
    final codec = await PaintingBinding.instance.instantiateImageCodecWithSize(
      buffer,
    );
    // ⚠️ PAS de buffer.dispose() : le codec possède le buffer.
    _cachedMessageCodec = codec;
    return codec;
  }

  /// Une tuile stockée identique au PNG transparent = placeholder = miss.
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
    final storeNames = _getCachedStoreNames();

    final networkUrl = provider.getTileUrl(coords, options);
    final transformer = provider.urlTransformer;
    final matcherUrl = transformer != null
        ? transformer.call(networkUrl)
        : networkUrl;

    // ignore: invalid_use_of_internal_member, experimental_member_use
    final result = await fmtc_internal.FMTCBackendAccess.internal.readTile(
      url: matcherUrl,
      storeNames: (storeNames: storeNames, includeOrExclude: true),
    );

    // Tuile absente (hors zones / zoom non téléchargé) ou placeholder :
    // message « Dézoomez » sur la couche du bas, transparent ailleurs.
    if (result.tile == null || _isTransparentPlaceholder(result.tile!.bytes)) {
      return showMessageOnMiss ? _getMessageCodec() : _getTransparentCodec();
    }

    final buffer = await ImmutableBuffer.fromUint8List(result.tile!.bytes);
    // ignore: invalid_use_of_internal_member
    final codec = await PaintingBinding.instance.instantiateImageCodecWithSize(
      buffer,
    );
    // ⚠️ PAS de buffer.dispose() : le codec possède le buffer.
    return codec;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NegativeFilteringImageProvider &&
          other.coords == coords &&
          other.provider == provider &&
          other.showMessageOnMiss == showMessageOnMiss);

  @override
  int get hashCode => Object.hash(coords, provider, showMessageOnMiss);
}
