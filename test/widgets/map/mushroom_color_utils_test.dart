import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/app_settings.dart';
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

    test('palette classique -> rouge-jaune-vert', () {
      AppSettings.mushroomPalette = MushroomPalette.classic;
      final c0 = indexToGradientColor(0);
      final c50 = indexToGradientColor(50);
      final c100 = indexToGradientColor(100);
      expect(c0.toARGB32(), equals(const Color(0xFFE53935).toARGB32()));
      expect(c100.toARGB32(), equals(const Color(0xFF2E7D32).toARGB32()));
      expect(_byte(c50.g), greaterThan(_byte(c0.g)));
    });

    test('palette contrastée -> rouge-orange-jaune-bleu', () {
      AppSettings.mushroomPalette = MushroomPalette.contrasted;
      final c0 = indexToGradientColor(0);
      final c100 = indexToGradientColor(100);
      expect(c0.toARGB32(), equals(const Color(0xFFE53935).toARGB32()));
      expect(c100.toARGB32(), equals(const Color(0xFF1976D2).toARGB32()));
    });
  });

  group('MushroomColorUtils - cellDisplayColors', () {
    test('Habitat excluded -> hachure gris, pas de couleur', () {
      final f = MushroomForecast.mock(
        index: 80,
        habitat: HabitatStatus.excluded,
        dataSources: {'terrain': 'ign_rge_alti_wld'},
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
        dataSources: {'terrain': 'ign_rge_alti_wld'},
      );
      final colors = cellDisplayColors(forecast: f, overlayOpacity: 1.0);
      expect(colors.hatch, isFalse);
      expect(_byte(colors.fill.a), greaterThan(200));
    });

    test('Habitat unknown -> couleur attenuee', () {
      final suitable = MushroomForecast.mock(
        index: 60,
        habitat: HabitatStatus.suitable,
        dataSources: {'terrain': 'ign_rge_alti_wld'},
      );
      final unknown = MushroomForecast.mock(
        index: 60,
        habitat: HabitatStatus.unknown,
        dataSources: {'terrain': 'ign_rge_alti_wld'},
      );
      final s = cellDisplayColors(forecast: suitable, overlayOpacity: 1.0);
      final u = cellDisplayColors(forecast: unknown, overlayOpacity: 1.0);
      expect(_byte(u.fill.a), closeTo((_byte(s.fill.a) * 0.55).round(), 2));
      expect(u.hatch, isFalse);
    });

    test('dataMissing true -> gray dotted', () {
      final f = MushroomForecast.mock(
        index: 60,
        habitat: HabitatStatus.suitable,
        dataSources: {'terrain': 'ign_rge_alti_wld'},
      );
      final colors = cellDisplayColors(
        forecast: f,
        overlayOpacity: 1.0,
        dataMissing: true,
      );
      expect(colors.hatch, isTrue);
      expect(_byte(colors.fill.r), equals(158));
      expect(_byte(colors.fill.g), equals(158));
      expect(_byte(colors.fill.b), equals(158));
    });

    test('dataMissing false -> colored fill not gray', () {
      final f = MushroomForecast.mock(
        index: 60,
        habitat: HabitatStatus.suitable,
        dataSources: {'terrain': 'ign_rge_alti_wld'},
      );
      final colors = cellDisplayColors(
        forecast: f,
        overlayOpacity: 1.0,
        dataMissing: false,
      );
      expect(colors.hatch, isFalse);
      expect(_byte(colors.fill.r), isNot(equals(158)));
    });

    test('unknown forest -> attenuated non-gray', () {
      final suitable = MushroomForecast.mock(
        index: 60,
        habitat: HabitatStatus.suitable,
        dataSources: {'terrain': 'ign_rge_alti_wld'},
      );
      final unknown = MushroomForecast.mock(
        index: 60,
        habitat: HabitatStatus.unknown,
        dataSources: {'terrain': 'ign_rge_alti_wld'},
      );
      final s = cellDisplayColors(
        forecast: suitable,
        overlayOpacity: 1.0,
        dataMissing: false,
      );
      final u = cellDisplayColors(
        forecast: unknown,
        overlayOpacity: 1.0,
        dataMissing: false,
      );
      // Unknown habitat should be attenuated (0.55 multiplier) but not gray
      expect(_byte(u.fill.a), closeTo((_byte(s.fill.a) * 0.55).round(), 2));
      expect(u.hatch, isFalse);
      expect(_byte(u.fill.r), isNot(equals(158))); // Not gray
    });

    test('pastille color always opaque (opacityMultiplier 1.0)', () {
      // Pastilles use indexToGradientColor with opacityMultiplier: 1.0
      // regardless of overlay opacity
      final color = indexToGradientColor(50, opacityMultiplier: 1.0);
      expect(_byte(color.a), equals(255)); // Fully opaque
    });

    test('overlayOpacity appique sur toutes les branches', () {
      final excluded = MushroomForecast.mock(
        habitat: HabitatStatus.excluded,
        dataSources: {'terrain': 'ign_rge_alti_wld'},
      );
      final c1 = cellDisplayColors(forecast: excluded, overlayOpacity: 1.0);
      final c2 = cellDisplayColors(forecast: excluded, overlayOpacity: 0.2);
      expect(_byte(c2.fill.a), closeTo((_byte(c1.fill.a) * 0.2).round(), 1));

      final suitable = MushroomForecast.mock(
        index: 50,
        habitat: HabitatStatus.suitable,
        dataSources: {'terrain': 'ign_rge_alti_wld'},
      );
      final s1 = cellDisplayColors(forecast: suitable, overlayOpacity: 1.0);
      final s2 = cellDisplayColors(forecast: suitable, overlayOpacity: 0.3);
      // Minimum alpha of 0.35 is applied, so 0.3 becomes 0.35
      expect(_byte(s2.fill.a), closeTo((_byte(s1.fill.a) * 0.35).round(), 1));
    });
  });
}
