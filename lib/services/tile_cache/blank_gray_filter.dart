import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';
import 'package:my_spots/services/tile_cache/message_tile_provider.dart';

class BlankGrayFilteringTileProvider extends TileProvider {
  BlankGrayFilteringTileProvider(this.inner, {this.paintMessage = false});

  final TileProvider inner;
  final bool paintMessage;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
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

  // ✅ Cache uniquement les BYTES, jamais les ui.Image
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
          completer.complete(await _transparentInfo());
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
    ui.Image? original = info.image;
    final scale = info.scale;

    try {
      final w = original.width;
      final h = original.height;

      final data = await original.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (data == null) {
        final cloned = original.clone();
        info.dispose(); // Libère le handle du provider intérieur
        original = null;
        completer.complete(ImageInfo(image: cloned, scale: scale));
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
          bytes[i + 3] = 0; // Rend le pixel transparent
          hasVoid = true;
        } else {
          hasContent = true;
        }
      }

      if (!hasVoid) {
        final cloned = original.clone();
        info.dispose();
        original = null;
        completer.complete(ImageInfo(image: cloned, scale: scale));
        return;
      }

      if (!hasContent) {
        info.dispose();
        original = null;
        if (paintMessage) {
          completer.complete(await _messageTileInfo());
        } else {
          completer.complete(await _transparentInfo());
        }
        return;
      }

      info.dispose(); // L'image originale n'est plus nécessaire
      original = null;

      final modifiedImage = await _imageFromRgba(bytes, w, h);

      if (paintMessage) {
        final msgImage = await _messageImage();
        try {
          final composited = await _compositeOnMessage(msgImage, modifiedImage);
          modifiedImage.dispose();
          msgImage.dispose();
          completer.complete(ImageInfo(image: composited, scale: scale));
        } catch (e) {
          modifiedImage.dispose();
          msgImage.dispose();
          rethrow;
        }
      } else {
        completer.complete(ImageInfo(image: modifiedImage, scale: scale));
      }
    } catch (e, st) {
      if (original != null) {
        info.dispose();
      }
      completer.completeError(e, st);
    }
  }

  /// Détermine si un pixel est "vide" (doit devenir transparent).
  @visibleForTesting
  static bool isVoidPixel(int r, int g, int b, int a) {
    if (a == 0) return true;
    final isGrayWhite = (r - g).abs() <= 3 && (g - b).abs() <= 3 && r >= 190;
    return isGrayWhite;
  }

  static Future<ui.Image> _imageFromRgba(Uint8List rgba, int w, int h) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: w,
      height: h,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();

    // ✅ Libération explicite des ressources natives
    descriptor.dispose();
    codec.dispose();
    buffer.dispose();

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

  static Future<ImageInfo> _messageTileInfo() async {
    return ImageInfo(image: await _messageImage(), scale: 1.0);
  }

  static Future<ui.Image> _messageImage() async {
    // Le générateur est l'unique propriétaire des bytes du message (cache unique).
    final bytes = await MessageTileProvider.getTileBytes(); // ← appel STATIQUE
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await ui.instantiateImageCodecWithSize(buffer);
    final frame = await codec.getNextFrame();

    codec.dispose();

    return frame.image;
  }

  static Future<ImageInfo> _transparentInfo() async {
    return ImageInfo(image: await _transparentImage(), scale: 1.0);
  }

  static Future<ui.Image> _transparentImage() async {
    _cachedTransparentBytes ??= TileProviderFactory.transparentTilePng;
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      _cachedTransparentBytes!,
    );
    final codec = await ui.instantiateImageCodecWithSize(buffer);
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
