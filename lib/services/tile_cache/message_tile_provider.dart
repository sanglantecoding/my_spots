import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Un TileProvider qui retourne toujours la même tuile PNG contenant
/// le message "Dézoomez pour voir la carte".
///
/// Utilisé comme couche de fond pour remplacer le gris par défaut
/// quand aucune carte n'est disponible à ce niveau de zoom.
class MessageTileProvider extends TileProvider {
  MessageTileProvider() : super();

  /// Tuile PNG 256x256 avec le message, générée une seule fois et mise en cache.
  static Uint8List? _cachedTile;

  /// Retourne les bytes PNG de la tuile de message.
  Future<Uint8List> getTileBytes() async {
    if (_cachedTile != null) return _cachedTile!;

    const int size = 256;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fond sombre (cohérent avec le thème de l'app)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint()..color = const Color(0xFF0A1929),
    );

    // Grille subtile pour donner un aspect "carte technique"
    final gridPaint = Paint()
      ..color = const Color(0xFF1A3A5C)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (int i = 0; i <= size; i += 32) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), size.toDouble()),
        gridPaint,
      );
      canvas.drawLine(
        Offset(0, i.toDouble()),
        Offset(size.toDouble(), i.toDouble()),
        gridPaint,
      );
    }

    // On dessine un cercle avec un "-" au centre
    final center = Offset(size / 2, size / 2 - 30);
    final circlePaint = Paint()
      ..color = const Color(0xFF0D6999)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 20, circlePaint);
    final minusPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - 10, center.dy),
      Offset(center.dx + 10, center.dy),
      minusPaint,
    );

    // Texte principal
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Dézoomez',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, size / 2 + 10),
    );

    // Texte secondaire
    final textPainter2 = TextPainter(
      text: TextSpan(
        text: 'pour voir la carte',
        style: const TextStyle(color: Color(0xFF8899AA), fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter2.layout();
    textPainter2.paint(
      canvas,
      Offset((size - textPainter2.width) / 2, size / 2 + 32),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();

    _cachedTile = byteData!.buffer.asUint8List();
    return _cachedTile!;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _MessageImageProvider(getTileBytes: getTileBytes);
  }
}

/// ImageProvider qui charge les bytes PNG depuis la méthode asynchrone.
class _MessageImageProvider extends ImageProvider<_MessageImageProvider> {
  final Future<Uint8List> Function() getTileBytes;

  const _MessageImageProvider({required this.getTileBytes});

  @override
  ImageStreamCompleter loadImage(
    _MessageImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_loadImageInfo());
  }

  Future<ImageInfo> _loadImageInfo() async {
    final bytes = await getTileBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image); // ← Enveloppe l'image dans ImageInfo
  }

  @override
  Future<_MessageImageProvider> obtainKey(ImageConfiguration configuration) {
    return Future.value(this);
  }

  @override
  bool operator ==(Object other) => other is _MessageImageProvider;

  @override
  int get hashCode => 0; // Toujours la même tuile
}
