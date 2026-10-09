import 'package:flutter/material.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';

Color indexToGradientColor(int index, {double opacityMultiplier = 1.0}) {
  final clamped = index.clamp(0, 100);
  final t = clamped / 100;
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

({Color fill, Color border, bool hatch}) cellDisplayColors({
  required MushroomForecast forecast,
  required double overlayOpacity,
}) {
  final excluded = forecast.habitat == HabitatStatus.excluded;
  final unknown = forecast.habitat == HabitatStatus.unknown;
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
  return (
    fill: color.withValues(alpha: color.a * overlayOpacity),
    border: Colors.black.withValues(alpha: 0.22 * overlayOpacity),
    hatch: false,
  );
}

List<Color> legendGradientStops() => [
  const Color(0xFFE53935),
  const Color(0xFFFDD835),
  const Color(0xFF2E7D32),
];

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
