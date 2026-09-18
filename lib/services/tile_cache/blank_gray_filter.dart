import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/services/tile_cache/message_tile_provider.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';

class BlankGrayFilteringTileProvider extends TileProvider {
  BlankGrayFilteringTileProvider(this.inner, {this.paintMessage = false});

  final TileProvider inner;
  final bool paintMessage;

  static bool verboseLogs = false;
  static void log(String message) {
    if (verboseLogs) debugPrint('[BlankGrayFilter] $message');
  }

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
  static Uint8List? _cachedMessageTileBytes;
  static Uint8List? _cachedTransparentBytes;

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
        _processTile(image, completer, decode);
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
        BlankGrayFilteringTileProvider.log(
          '$_tag : ⚠️ erreur réseau : $error → transparent',
        );
        _transparentInfo().then(completer.complete);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  void _processTile(
    ImageInfo info,
    Completer<ImageInfo> completer,
    ImageDecoderCallback decode,
  ) async {
    try {
      final original = info.image;
      final w = original.width;
      final h = original.height;

      final data = await original.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (data == null) {
        completer.complete(info);
        return;
      }

      final bytes = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );

      var hasContent = false;
      var hasVoid = false;
      for (var i = 0; i < bytes.length; i += 4) {
        final a = bytes[i + 3];
        if (a == 0) {
          hasVoid = true;
          continue;
        }
        final r = bytes[i];
        final g = bytes[i + 1];
        final b = bytes[i + 2];

        final isGrayWhite =
            (r - g).abs() <= 3 && (g - b).abs() <= 3 && r >= 190;

        if (isGrayWhite) {
          bytes[i + 3] = 0;
          hasVoid = true;
        } else {
          hasContent = true;
        }
      }

      if (!hasVoid) {
        BlankGrayFilteringTileProvider.log('$_tag : pleine → gardée');
        completer.complete(info);
        return;
      }

      if (!hasContent) {
        if (paintMessage) {
          BlankGrayFilteringTileProvider.log(
            '$_tag : 100% vide + couche BAS → MESSAGE',
          );
          _messageTileInfo().then(completer.complete);
        } else {
          BlankGrayFilteringTileProvider.log(
            '$_tag : 100% vide + couche DESSUS → transparent',
          );
          _transparentInfo().then(completer.complete);
        }
        return;
      }

      BlankGrayFilteringTileProvider.log(
        '$_tag : tuile mixte (contenu + vides) → compositing',
      );
      final modifiedImage = await _imageFromRgba(bytes, w, h);

      if (paintMessage) {
        final msgImage = await _messageImage();
        final composited = await _compositeOnMessage(msgImage, modifiedImage);
        modifiedImage.dispose();
        msgImage.dispose(); // ✅ Dispose l'image temporaire
        completer.complete(ImageInfo(image: composited));
      } else {
        completer.complete(ImageInfo(image: modifiedImage));
      }
    } catch (e) {
      BlankGrayFilteringTileProvider.log('$_tag : ❌ $e');
      completer.complete(info);
    }
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
    descriptor.dispose();
    codec.dispose();
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

  // ✅ Recrée l'image à chaque appel (pas de cache de ui.Image)
  static Future<ImageInfo> _messageTileInfo() async {
    return ImageInfo(image: await _messageImage());
  }

  static Future<ui.Image> _messageImage() async {
    if (_cachedMessageTileBytes == null) {
      final provider = MessageTileProvider();
      _cachedMessageTileBytes = await provider.getTileBytes();
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      _cachedMessageTileBytes!,
    );
    final codec = await ui.instantiateImageCodecWithSize(buffer);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image; // ✅ Nouvelle image à chaque appel
  }

  static Future<ImageInfo> _transparentInfo() async {
    return ImageInfo(image: await _transparentImage());
  }

  static Future<ui.Image> _transparentImage() async {
    _cachedTransparentBytes ??= TileProviderFactory.transparentTilePng;
    final codec = await ui.instantiateImageCodec(_cachedTransparentBytes!);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image; // ✅ Nouvelle image à chaque appel
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
