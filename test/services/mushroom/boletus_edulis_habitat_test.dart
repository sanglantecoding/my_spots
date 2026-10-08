import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/services/mushroom/boletus_edulis_model.dart';

void main() {
  group('BoletusEdulisModel habitat', () {
    final model = BoletusEdulisModel();

    MushroomForecast calculate({
      required double? elevation,
      required bool? isForest,
      bool noElevationData = false,
      String? landCover,
    }) => model.calculate(
      weatherHistory: [],
      weatherForecast: [],
      soilMoistureLayers: [],
      terrain: TerrainData(
        latitude: 43.5,
        longitude: 3.5,
        elevation: elevation,
        noElevationData: noElevationData,
      ),
      forest: ForestData.mock(
        isForest: isForest,
        forestType: isForest == true ? 'feuillu' : null,
        treeDensity: isForest == true ? 60 : null,
        landCover: landCover,
      ),
      targetDate: DateTime(2026, 9, 1),
    );

    test('altitude au niveau de la mer ou dessous exclut', () {
      for (final elevation in [0.0, -2.0]) {
        final forecast = calculate(elevation: elevation, isForest: true);
        expect(forecast.habitat, HabitatStatus.excluded);
        expect(forecast.habitatReason, 'Niveau de la mer ou en dessous');
        expect(forecast.index, 0);
      }
    });

    test('code IGN pas de donnée exclut sans créer une altitude', () {
      final forecast = calculate(
        elevation: null,
        isForest: true,
        noElevationData: true,
      );
      expect(forecast.habitat, HabitatStatus.excluded);
      expect(forecast.habitatReason, 'Pas d’altitude IGN : mer probable');
      expect(forecast.index, 0);
    });

    test('occupation beach exclut avec une raison explicite', () {
      final forecast = calculate(
        elevation: 600,
        isForest: true,
        landCover: 'beach',
      );
      expect(forecast.habitat, HabitatStatus.excluded);
      expect(forecast.habitatReason, 'Plage ou sable');
      expect(forecast.index, 0);
    });

    test('altitude inconnue sans code IGN reste inconnue et non bloquée', () {
      final forecast = calculate(elevation: null, isForest: true);
      expect(forecast.habitat, HabitatStatus.unknown);
      expect(forecast.index, greaterThan(0));
    });

    test('forêt inconnue à 600 m reste inconnue et non bloquée', () {
      final forecast = calculate(elevation: 600, isForest: null);
      expect(forecast.habitat, HabitatStatus.unknown);
      expect(forecast.index, greaterThan(0));
    });

    test('forêt confirmée à 600 m rend habitat favorable', () {
      final forecast = calculate(elevation: 600, isForest: true);
      expect(forecast.habitat, HabitatStatus.suitable);
      expect(forecast.habitatReason, isNull);
    });

    test('altitude connue sous 100 m est exclue avec altitude arrondie', () {
      final forecast = calculate(elevation: 50.4, isForest: true);
      expect(forecast.habitat, HabitatStatus.excluded);
      expect(
        forecast.habitatReason,
        contains('Altitude 50 m : sous la limite basse'),
      );
    });

    test('bornes 100 m et 1800 m incluses', () {
      for (final elevation in [100.0, 1800.0]) {
        expect(
          calculate(elevation: elevation, isForest: true).habitat,
          isNot(HabitatStatus.excluded),
        );
      }
    });

    test('altitude au-dessus de 1800 m est exclue', () {
      final forecast = calculate(elevation: 1950, isForest: true);
      expect(forecast.habitat, HabitatStatus.excluded);
      expect(
        forecast.habitatReason,
        contains('au-dessus de la limite haute de 1800 m'),
      );
    });

    test('forêt absente seule ne bloque pas habitat', () {
      final forecast = calculate(elevation: 600, isForest: false);
      expect(forecast.habitat, HabitatStatus.suitable);
      expect(forecast.factors.forestFactor, 0);
    });
  });
}
