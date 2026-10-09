import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/views/widgets/map/mushroom_color_utils.dart';

int _byte(double v) => (v * 255.0).round().clamp(0, 255);

void main() {
  group('MushroomColorUtils - Gradient', () {
    test('indexToGradientColor 0 -> rouge', () {
      final c = indexToGradientColor(0);
      expect(c.toARGB32(), equals(const Color(0xFFE53935).toARGB32()));
    });

    test('indexToGradientColor 25 -> orange intermediaire', () {
      final c = indexToGradientColor(25);
      const yellow = Color(0xFFFDD835);
      const red = Color(0xFFE53935);
      expect(_byte(c.r), greaterThan(_byte(red.r) - 20));
      expect(_byte(c.g), greaterThan(120));
      expect(_byte(c.g), lessThan(_byte(yellow.g)));
      expect(c.toARGB32(), isNot(equals(yellow.toARGB32())));
      expect(c.toARGB32(), isNot(equals(red.toARGB32())));
    });

    test('indexToGradientColor 100 -> vert', () {
      final c = indexToGradientColor(100);
      expect(c.toARGB32(), equals(const Color(0xFF2E7D32).toARGB32()));
    });

    test('indexToGradientColor clamp hors borne', () {
      final low = indexToGradientColor(-50);
      final high = indexToGradientColor(500);
      expect(low.toARGB32(), equals(indexToGradientColor(0).toARGB32()));
      expect(high.toARGB32(), equals(indexToGradientColor(100).toARGB32()));
    });

    test('indexToGradientColor opacityMultiplier reduit alpha', () {
      final full = indexToGradientColor(50);
      final half = indexToGradientColor(50, opacityMultiplier: 0.5);
      expect(_byte(half.a), lessThan(_byte(full.a)));
      expect(_byte(half.a), closeTo(_byte(full.a) ~/ 2, 1));
    });
  });

  group('MushroomColorUtils - cellDisplayColors', () {
    test('Habitat excluded -> hachure gris, pas de couleur', () {
      final f = MushroomForecast.mock(
        index: 80,
        habitat: HabitatStatus.excluded,
      );
      final colors = cellDisplayColors(forecast: f, overlayOpacity: 1.0);
      expect(colors.hatch, isTrue);
      expect(_byte(colors.fill.r), equals(158));
      expect(_byte(colors.fill.g), equals(158));
      expect(_byte(colors.fill.b), equals(158));
    });

    test('Habitat suitable -> couleur pleine', () {
      final f = MushroomForecast.mock(
        index: 60,
        habitat: HabitatStatus.suitable,
      );
      final colors = cellDisplayColors(forecast: f, overlayOpacity: 1.0);
      expect(colors.hatch, isFalse);
      expect(_byte(colors.fill.a), greaterThan(200));
    });

    test('Habitat unknown -> couleur attenuee', () {
      final suitable = MushroomForecast.mock(
        index: 60,
        habitat: HabitatStatus.suitable,
      );
      final unknown = MushroomForecast.mock(
        index: 60,
        habitat: HabitatStatus.unknown,
      );
      final s = cellDisplayColors(forecast: suitable, overlayOpacity: 1.0);
      final u = cellDisplayColors(forecast: unknown, overlayOpacity: 1.0);
      expect(_byte(u.fill.a), closeTo((_byte(s.fill.a) * 0.55).round(), 2));
      expect(u.hatch, isFalse);
    });

    test('overlayOpacity appique sur toutes les branches', () {
      final excluded = MushroomForecast.mock(habitat: HabitatStatus.excluded);
      final c1 = cellDisplayColors(forecast: excluded, overlayOpacity: 1.0);
      final c2 = cellDisplayColors(forecast: excluded, overlayOpacity: 0.2);
      expect(_byte(c2.fill.a), closeTo((_byte(c1.fill.a) * 0.2).round(), 1));

      final suitable = MushroomForecast.mock(
        index: 50,
        habitat: HabitatStatus.suitable,
      );
      final s1 = cellDisplayColors(forecast: suitable, overlayOpacity: 1.0);
      final s2 = cellDisplayColors(forecast: suitable, overlayOpacity: 0.3);
      expect(_byte(s2.fill.a), closeTo((_byte(s1.fill.a) * 0.3).round(), 1));
    });
  });

  group('MushroomColorUtils - bestDaySummary', () {
    test('Tous excluded -> message habitat exclu', () {
      final forecasts = List.generate(
        3,
        (i) => MushroomForecast.mock(
          date: DateTime(2025, 1, 1 + i),
          index: 50,
          habitat: HabitatStatus.excluded,
        ),
      );
      expect(bestDaySummary(forecasts), contains('Hors habitat'));
    });

    test('Meilleur jour = J+0 quand premier est le meilleur', () {
      final d0 = DateTime(2025, 4, 12);
      final forecasts = [
        MushroomForecast.mock(
          date: d0,
          index: 90,
          habitat: HabitatStatus.suitable,
        ),
        MushroomForecast.mock(date: d0.add(const Duration(days: 1)), index: 40),
      ];
      final s = bestDaySummary(forecasts);
      expect(s, contains("aujourd'hui"));
      expect(s, contains('12/04'));
      expect(s, contains('indice 90'));
    });

    test('Meilleur jour = J+N quand dernier est meilleur', () {
      final d0 = DateTime(2025, 4, 12);
      final forecasts = [
        MushroomForecast.mock(date: d0, index: 20),
        MushroomForecast.mock(date: d0.add(const Duration(days: 1)), index: 30),
        MushroomForecast.mock(date: d0.add(const Duration(days: 2)), index: 95),
      ];
      final s = bestDaySummary(forecasts);
      expect(s, contains('J+2'));
      expect(s, contains('14/04'));
      expect(s, contains('indice 95'));
    });
  });
}
