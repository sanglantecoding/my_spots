import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/services/tile_cache/message_tile_provider.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';

/// Filtre gris/blanc : rend transparents les pixels gris/blanc (zones sans
/// couverture SHOM) pour laisser voir la couche inférieure. Sur la couche du
/// bas, une tuile 100 % vide affiche la tuile-message « Dézoomez ».
class BlankGrayFilteringTileProvider extends TileProvider {
  BlankGrayFilteringTileProvider(this.inner, {this.paintMessage = false});

  final TileProvider inner;
  final bool paintMessage;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    debugPrint(
      '[BlankGrayFilter] getImage: z=${coordinates.z} x=${coordinates.x} y=${coordinates.y} layerKey=${options.key} minNativeZoom=${options.minNativeZoom} maxNativeZoom=${options.maxNativeZoom}',
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

  // ⚠️ JAMAIS de ui.Image en cache statique : on ne cache que des BYTES.
  static Uint8List? _cachedMessageBytes;
  static Uint8List? _cachedTransparentBytes;

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
        _processTile(image, completer, decode);
      },
      onError: (Object error, StackTrace? stack) async {
        stream.removeListener(listener);
        try {
          completer.complete(await _transparentInfo(decode));
        } catch (e, st) {
          completer.completeError(e, st);
        }
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  Future<void> _processTile(
    ImageInfo info,
    Completer<ImageInfo> completer,
    ImageDecoderCallback decode,
  ) async {
    var ownsInfo = true;
    try {
      final original = info.image;
      final scale = info.scale;
      final w = original.width;
      final h = original.height;

      final data = await original.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (data == null) {
        ownsInfo = false;
        completer.complete(info); // illisible : transmise telle quelle
        return;
      }
      final bytes = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );

      var hasContent = false;
      var hasVoid = false;
      for (var i = 0; i < bytes.length; i += 4) {
        final a = bytes[i + 3];
        final r = bytes[i];
        final g = bytes[i + 1];
        final b = bytes[i + 2];
        if (isVoidPixel(r, g, b, a)) {
          bytes[i + 3] = 0; // rend le pixel transparent
          hasVoid = true;
        } else {
          hasContent = true;
        }
      }

      if (!hasVoid) {
        // Tuile pleine : transmise telle quelle, aucune copie.
        ownsInfo = false;
        completer.complete(info);
        return;
      }

      info.dispose();
      ownsInfo = false;

      if (!hasContent) {
        // Tuile 100 % vide (opaque SHOM ou déjà transparente) :
        // message « Dézoomez » sur la couche du bas, transparent au-dessus.
        completer.complete(
          paintMessage
              ? await _messageTileInfo(decode)
              : await _transparentInfo(decode),
        );
        return;
      }

      // Tuile mixte : trous transparents ; message composite sous le contenu
      // uniquement sur la couche du bas.
      final modifiedImage = await _imageFromRgba(bytes, w, h, decode);
      if (!paintMessage) {
        completer.complete(ImageInfo(image: modifiedImage, scale: scale));
        return;
      }
      final msgImage = await _messageImage(decode);
      try {
        final composited = await _compositeOnMessage(msgImage, modifiedImage);
        completer.complete(ImageInfo(image: composited, scale: scale));
      } finally {
        modifiedImage.dispose();
        msgImage.dispose();
      }
    } catch (e, st) {
      if (ownsInfo) {
        info.dispose();
      }
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
    }
  }

  /// Détermine si un pixel est "vide" (doit devenir transparent).
  @visibleForTesting
  static bool isVoidPixel(int r, int g, int b, int a) {
    if (a == 0) return true;
    final isGrayWhite = (r - g).abs() <= 3 && (g - b).abs() <= 3 && r >= 190;
    return isGrayWhite;
  }

  static Future<ui.Image> _imageFromRgba(
    Uint8List rgba,
    int w,
    int h,
    ImageDecoderCallback decode,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: w,
      height: h,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    // ⚠️ PAS de buffer.dispose() : cause historique des assertions natives.
    return frame.image;
  }

  static Future<ui.Image> _compositeOnMessage(
    ui.Image background,
    ui.Image overlay,
  ) async {
    final w = overlay.width;
    final h = overlay.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    canvas.drawImageRect(background, rect, rect, Paint());
    canvas.drawImageRect(overlay, rect, rect, Paint());
    final picture = recorder.endRecording();
    final result = await picture.toImage(w, h);
    picture.dispose();
    return result;
  }

  static Future<ImageInfo> _messageTileInfo(ImageDecoderCallback decode) async {
    return ImageInfo(image: await _messageImage(decode), scale: 1.0);
  }

  static Future<ui.Image> _messageImage(ImageDecoderCallback decode) async {
    _cachedMessageBytes ??= await MessageTileProvider.getTileBytes();
    return _decodeBytes(_cachedMessageBytes!, decode);
  }

  static Future<ImageInfo> _transparentInfo(ImageDecoderCallback decode) async {
    return ImageInfo(image: await _transparentImage(decode), scale: 1.0);
  }

  static Future<ui.Image> _transparentImage(ImageDecoderCallback decode) async {
    _cachedTransparentBytes ??= TileProviderFactory.transparentTilePng;
    return _decodeBytes(_cachedTransparentBytes!, decode);
  }

  /// ⚠️ Le codec prend la propriété du buffer : JAMAIS de buffer.dispose().
  static Future<ui.Image> _decodeBytes(
    Uint8List bytes,
    ImageDecoderCallback decode,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlankGrayFilteringImageProvider &&
          other.inner == inner &&
          other.coords == coords &&
          other.layerKey == layerKey &&
          other.paintMessage == paintMessage);

  @override
  int get hashCode => Object.hash(inner, coords, layerKey, paintMessage);
}

class MessageBaseTileProvider extends TileProvider {
  MessageBaseTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MessageBaseImageProvider(coords: coordinates);
  }
}

class MessageBaseImageProvider extends ImageProvider<MessageBaseImageProvider> {
  const MessageBaseImageProvider({required this.coords});

  final TileCoordinates coords;
  static Uint8List? _cachedBytes;

  @override
  Future<MessageBaseImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<MessageBaseImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    MessageBaseImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_resolve(decode));
  }

  Future<ImageInfo> _resolve(ImageDecoderCallback decode) async {
    _cachedBytes ??= await MessageTileProvider.getTileBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(_cachedBytes!);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    codec.dispose(); // ⚠️ jamais de buffer.dispose() ici
    return ImageInfo(image: frame.image, scale: 1.0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageBaseImageProvider && other.coords == coords);

  @override
  int get hashCode => coords.hashCode;
}
