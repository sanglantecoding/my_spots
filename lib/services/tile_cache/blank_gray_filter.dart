import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/services/tile_cache/message_tile_provider.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';

/// Enrobe un TileProvider pour détecter les tuiles "vides" du serveur SHOM
/// (100 % transparentes, ou pavé de gris uniforme) et, UNIQUEMENT pour la
/// couche du BAS de la pile (paintMessage: true), les remplacer par la tuile
/// message "Dézoomez pour voir la carte".
///
/// Règle absolue : les couches du DESSUS (25K, 10K...) ne doivent JAMAIS
/// peindre le message : leurs tuiles vides restent transparentes pour laisser
/// voir le contenu valide des couches inférieures. Sinon le message (opaque)
/// masque la carte → "tuiles noires avec message" au milieu de la carte.
class BlankGrayFilteringTileProvider extends TileProvider {
  BlankGrayFilteringTileProvider(this.inner, {this.paintMessage = false});

  final TileProvider inner;

  /// SEULE la couche du BAS de la pile marine peint le message.
  /// Toujours false pour les couches supérieures et le LiDAR.
  final bool paintMessage;

  /// Mettre à false une fois le diagnostic terminé (fluidité + logs propres).
  static bool verboseLogs = true;

  static void log(String message) {
    if (verboseLogs) debugPrint('[BlankGrayFilter] $message');
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    log(
      '▶ getImage — ${options.key} z=${coordinates.z} x=${coordinates.x} '
      'y=${coordinates.y} paintMessage=$paintMessage',
    );
    return BlankGrayFilteringImageProvider(
      inner: inner.getImage(coordinates, options),
      coords: coordinates,
      layerKey: '${options.key}',
      paintMessage: paintMessage,
    );
  }
}

class BlankGrayFilteringImageProvider
    extends ImageProvider<BlankGrayFilteringImageProvider> {
  const BlankGrayFilteringImageProvider({
    required this.inner,
    required this.coords,
    required this.layerKey,
    required this.paintMessage,
  });

  final ImageProvider inner;
  final TileCoordinates coords;
  final String layerKey;
  final bool paintMessage;

  static Uint8List? _cachedMessageTileBytes;
  static ui.Image? _cachedTransparent;

  String get _tag => '$layerKey z=${coords.z} x=${coords.x} y=${coords.y}';

  @override
  Future<BlankGrayFilteringImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<BlankGrayFilteringImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    BlankGrayFilteringImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_resolveInner(decode));
  }

  Future<ImageInfo> _resolveInner(ImageDecoderCallback decode) async {
    final completer = Completer<ImageInfo>();
    final stream = inner.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronousCall) {
        stream.removeListener(listener);
        _checkAndComplete(image, completer, decode);
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
        // Erreur réseau / FMTC : on RETENTE une fois, puis tuile transparente.
        // JAMAIS de tuile message ici : un échec ne doit pas faire croire
        // qu'il n'y a pas de carte à cet endroit.
        BlankGrayFilteringTileProvider.log(
          '$_tag : ⚠️ ERREUR provider interne : $error → 1 retry',
        );
        _retryOnce().then((info) {
          if (info != null) {
            _checkAndComplete(info, completer, decode);
          } else {
            BlankGrayFilteringTileProvider.log(
              '$_tag : ❌ 2e échec → tuile transparente',
            );
            _transparentInfo().then(completer.complete);
          }
        });
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Une seule nouvelle tentative, après un court délai (erreurs transitoires).
  Future<ImageInfo?> _retryOnce() async {
    await Future.delayed(const Duration(milliseconds: 800));
    try {
      final completer = Completer<ImageInfo>();
      final stream = inner.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (image, synchronousCall) {
          stream.removeListener(listener);
          completer.complete(image);
        },
        onError: (Object error, StackTrace? stack) {
          stream.removeListener(listener);
          completer.completeError(error, stack);
        },
      );
      stream.addListener(listener);
      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  void _checkAndComplete(
    ImageInfo info,
    Completer<ImageInfo> completer,
    ImageDecoderCallback decode,
  ) async {
    try {
      final data = await info.image.toByteData();
      if (data == null) {
        BlankGrayFilteringTileProvider.log('$_tag : toByteData null → gardée');
        completer.complete(info);
        return;
      }

      final r0 = data.getUint8(0);
      final g0 = data.getUint8(1);
      final b0 = data.getUint8(2);
      final a0 = data.getUint8(3);

      // Tuile "vide" SHOM : 100 % transparente ou pavé de gris uniforme.
      if (_isFullyTransparent(data) || _isUniformGray(data)) {
        if (paintMessage) {
          BlankGrayFilteringTileProvider.log(
            '$_tag : ✅ tuile VIDE (pixel0 RGBA=$r0,$g0,$b0,$a0) '
            '+ couche du BAS → MESSAGE',
          );
          _messageTileInfo(decode).then((msg) => completer.complete(msg));
        } else {
          BlankGrayFilteringTileProvider.log(
            '$_tag : tuile VIDE (pixel0 RGBA=$r0,$g0,$b0,$a0) '
            'mais couche du DESSUS → laissée TRANSPARENTE',
          );
          completer.complete(info);
        }
        return;
      }

      BlankGrayFilteringTileProvider.log(
        '$_tag : contenu (pixel0 RGBA=$r0,$g0,$b0,$a0) → gardée',
      );
    } catch (e) {
      BlankGrayFilteringTileProvider.log('$_tag : ❌ EXCEPTION $e → gardée');
    }
    completer.complete(info);
  }

  /// Tuile "vide" du SHOM = PNG dont TOUS les pixels ont alpha = 0.
  /// Vérification EXHAUSTIVE (pas d'échantillonnage) : une tuile avec un
  /// trait fin (côte, isobathe, câble...) ne doit JAMAIS être remplacée.
  static bool _isFullyTransparent(ByteData data) {
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (bytes.length < 4) return false;
    for (var i = 3; i < bytes.length; i += 4) {
      if (bytes[i] != 0) return false; // pixel opaque → vraie tuile de carte
    }
    return true; // tous les alpha = 0 → tuile vide
  }

  /// Cas secondaire : pavé de gris parfaitement uniforme (r == g == b, clair).
  /// Les vraies tuiles (eau, terre, traits) ne sont jamais uniformes.
  static bool _isUniformGray(ByteData data) {
    if (data.lengthInBytes < 4) return false;
    final length = data.lengthInBytes;
    const step = 16 * 4; // 1 pixel sur 16

    final refR = data.getUint8(0);
    final refG = data.getUint8(1);
    final refB = data.getUint8(2);

    if ((refR - refG).abs() > 3 || (refG - refB).abs() > 3) return false;
    if (refR < 190) return false;

    final tol = refR >= 240 ? 14 : 4;

    for (var i = 0; i < length; i += step) {
      final r = data.getUint8(i);
      final g = data.getUint8(i + 1);
      final b = data.getUint8(i + 2);
      if ((r - refR).abs() > tol ||
          (g - refG).abs() > tol ||
          (b - refB).abs() > tol) {
        return false;
      }
    }
    // Contrôle du tout dernier pixel (sécurité)
    final last = length - 4;
    if ((data.getUint8(last) - refR).abs() > tol ||
        (data.getUint8(last + 1) - refG).abs() > tol ||
        (data.getUint8(last + 2) - refB).abs() > tol) {
      return false;
    }
    return true; // la tuile est bien un pavé de gris
  }

  /// Tuile message "Dézoomez pour voir la carte" (générée une seule fois).
  static Future<ImageInfo> _messageTileInfo(ImageDecoderCallback decode) async {
    if (_cachedMessageTileBytes != null) {
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        _cachedMessageTileBytes!,
      );
      final codec = await decode(buffer);
      final frame = await codec.getNextFrame();
      return ImageInfo(image: frame.image);
    }
    final provider = MessageTileProvider();
    final bytes = await provider.getTileBytes();
    _cachedMessageTileBytes = bytes;
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  /// Tuile 100 % transparente (fallback en cas d'erreur réseau persistante).
  static Future<ImageInfo> _transparentInfo() async {
    if (_cachedTransparent != null) {
      return ImageInfo(image: _cachedTransparent!);
    }
    final codec = await ui.instantiateImageCodec(
      TileProviderFactory.transparentTilePng,
    );
    final frame = await codec.getNextFrame();
    _cachedTransparent = frame.image;
    return ImageInfo(image: frame.image);
  }
}
