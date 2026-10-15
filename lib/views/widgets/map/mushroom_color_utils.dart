import 'package:flutter/material.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';

/// Définit une palette avec ses couleurs et leurs positions (0.0 à 1.0).
class _Palette {
  const _Palette({required this.stops, required this.colors});

  /// Liste des positions (0.0 à 1.0) pour l'interpolation.
  final List<double> stops;
  final List<Color> colors;

  Color interpolate(double t) {
    if (stops.isEmpty) return Colors.grey;
    if (stops.length == 1) return colors[0];

    // Trouver le segment contenant t
    int i = 0;
    while (i < stops.length - 1 && t > stops[i + 1]) {
      i++;
    }

    final t0 = stops[i];
    final t1 = stops[i + 1];
    final local = (t - t0) / (t1 - t0);

    return Color.lerp(colors[i], colors[i + 1], local)!;
  }

  List<Color> get legendColors => colors;
}

/// Palette classique : rouge-jaune-vert
const _classicPalette = _Palette(
  stops: [0.0, 0.5, 1.0],
  colors: [
    Color(0xFFE53935), // red
    Color(0xFFFDD835), // yellow
    Color(0xFF2E7D32), // green
  ],
);

/// Palette contrastée : rouge-orange-jaune-bleu
const _contrastedPalette = _Palette(
  stops: [0.0, 0.33, 0.66, 1.0],
  colors: [
    Color(0xFFE53935), // red
    Color(0xFFFF9800), // orange
    Color(0xFFFDD835), // yellow
    Color(0xFF1976D2), // blue
  ],
);

_Palette _getPalette() {
  return AppSettings.mushroomPalette == MushroomPalette.contrasted
      ? _contrastedPalette
      : _classicPalette;
}

Color indexToGradientColor(int index, {double opacityMultiplier = 1.0}) {
  final clamped = index.clamp(0, 100);
  final t = clamped / 100;
  final palette = _getPalette();
  final base = palette.interpolate(t);
  return base.withValues(alpha: base.a * opacityMultiplier);
}

({Color fill, Color border, bool hatch}) cellDisplayColors({
  required MushroomForecast forecast,
  required double overlayOpacity,
  bool dataMissing = false,
}) {
  final excluded = forecast.habitat == HabitatStatus.excluded;
  final unknown = forecast.habitat == HabitatStatus.unknown;

  // Missing data (no terrain or weather) -> gray dotted, no gradient
  if (dataMissing) {
    return (
      fill: Colors.grey.withValues(alpha: 0.3 * overlayOpacity),
      border: Colors.grey.withValues(alpha: 0.5 * overlayOpacity),
      hatch: true,
    );
  }

  if (excluded) {
    return (
      fill: Colors.grey.withValues(alpha: 0.18 * overlayOpacity),
      border: Colors.grey.withValues(alpha: 0.35 * overlayOpacity),
      hatch: true,
    );
  }
  final color = indexToGradientColor(
    forecast.index,
    opacityMultiplier: unknown ? 0.55 : 1.0,
  );

  // Minimum alpha of 0.35 for fill color
  final fillAlpha = (color.a * overlayOpacity).clamp(0.35, 1.0);
  final fillColor = color.withValues(alpha: fillAlpha);

  // Border is same hue but 30% darker
  final hsl = HSLColor.fromColor(color);
  final darkerHsl = hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0));
  final borderColor = darkerHsl.toColor();

  return (fill: fillColor, border: borderColor, hatch: false);
}

List<Color> legendGradientStops() {
  return _getPalette().legendColors;
}
