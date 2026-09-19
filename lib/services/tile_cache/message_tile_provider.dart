import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Générateur pur de la tuile PNG 256×256 contenant le message
/// « Dézoomez pour voir la carte ».
///
/// Simplifié selon l'audit : plus d'héritage [TileProvider], plus de
/// `getImage()`, plus de `_MessageImageProvider` — cette classe est
/// uniquement l'unique propriétaire des bytes PNG du message (cache unique).
class MessageTileProvider {
  MessageTileProvider._();

  /// Bytes PNG de la tuile message, générés une seule fois puis mis en cache.
  static Uint8List? _cachedTile;

  /// Retourne les bytes PNG de la tuile message (génération au premier appel).
  static Future<Uint8List> getTileBytes() async {
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

    // Cercle avec un "-" au centre
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
      text: const TextSpan(
        text: 'Dézoomez',
        style: TextStyle(
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
    textPainter.dispose();

    // Texte secondaire
    final textPainter2 = TextPainter(
      text: const TextSpan(
        text: 'pour voir la carte',
        style: TextStyle(color: Color(0xFF8899AA), fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter2.layout();
    textPainter2.paint(
      canvas,
      Offset((size - textPainter2.width) / 2, size / 2 + 32),
    );
    textPainter2.dispose();

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    // ✅ Libération explicite des ressources natives (audit point 5)
    picture.dispose();
    image.dispose();

    _cachedTile = byteData!.buffer.asUint8List();
    return _cachedTile!;
  }
}
