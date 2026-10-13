import 'package:flutter/material.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';

Color indexToGradientColor(int index, {double opacityMultiplier = 1.0}) {
  final clamped = index.clamp(0, 100);
  final t = clamped / 100;

  final isContrasted =
      AppSettings.mushroomPalette == MushroomPalette.contrasted;

  if (isContrasted) {
    // Contrastée : rouge-orange-jaune-bleu
    const red = Color(0xFFE53935);
    const orange = Color(0xFFFF9800);
    const yellow = Color(0xFFFDD835);
    const blue = Color(0xFF1976D2);

    final Color base;
    if (t < 0.33) {
      final local = t / 0.33;
      base = Color.lerp(red, orange, local)!;
    } else if (t < 0.66) {
      final local = (t - 0.33) / 0.33;
      base = Color.lerp(orange, yellow, local)!;
    } else {
      final local = (t - 0.66) / 0.34;
      base = Color.lerp(yellow, blue, local)!;
    }
    return base.withValues(alpha: base.a * opacityMultiplier);
  } else {
    // Classique : rouge-jaune-vert
    const red = Color(0xFFE53935);
    const yellow = Color(0xFFFDD835);
    const green = Color(0xFF2E7D32);
    final Color base;
    if (t < 0.5) {
      final local = t / 0.5;
      base = Color.lerp(red, yellow, local)!;
    } else {
      final local = (t - 0.5) / 0.5;
      base = Color.lerp(yellow, green, local)!;
    }
    return base.withValues(alpha: base.a * opacityMultiplier);
  }
}

({Color fill, Color border, bool hatch}) cellDisplayColors({
  required MushroomForecast forecast,
  required double overlayOpacity,
}) {
  final excluded = forecast.habitat == HabitatStatus.excluded;
  final unknown = forecast.habitat == HabitatStatus.unknown;

  // Check if terrain data is missing (source null means no terrain data available)
  final hasTerrain = forecast.dataSources['terrain'] != null;

  // Unknown altitude (no terrain data) -> gray dotted, no gradient
  if (!hasTerrain) {
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
  final isContrasted =
      AppSettings.mushroomPalette == MushroomPalette.contrasted;
  if (isContrasted) {
    return [
      const Color(0xFFE53935),
      const Color(0xFFFF9800),
      const Color(0xFFFDD835),
      const Color(0xFF1976D2),
    ];
  }
  return [
    const Color(0xFFE53935),
    const Color(0xFFFDD835),
    const Color(0xFF2E7D32),
  ];
}

String bestDaySummary(List<MushroomForecast> forecasts) {
  final suitable = forecasts
      .where((f) => f.habitat != HabitatStatus.excluded)
      .toList();
  if (suitable.isEmpty) return 'Hors habitat sur la zone';
  final best = suitable.reduce((a, b) => a.index >= b.index ? a : b);
  final dayIndex = forecasts.indexOf(best);
  final date =
      '${best.date.day.toString().padLeft(2, '0')}/${best.date.month.toString().padLeft(2, '0')}';
  return dayIndex == 0
      ? 'Meilleur jour : aujourd\'hui ($date, indice ${best.index})'
      : 'Meilleur jour : J+$dayIndex ($date, indice ${best.index})';
}
