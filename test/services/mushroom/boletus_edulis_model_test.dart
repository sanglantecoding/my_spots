import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/boletus_edulis_model.dart';

void main() {
  group('BoletusEdulisModel', () {
    late BoletusEdulisModel model;

    setUp(() {
      model = BoletusEdulisModel();
    });

    test('species returns boletusEdulis', () {
      expect(model.species, MushroomSpecies.boletusEdulis);
    });

    test('calculate returns forecast with valid data', () async {
      // Données météo historiques (60 jours)
      final weatherHistory = List.generate(
        60,
        (i) => WeatherDay.mock(
          date: DateTime.now().subtract(Duration(days: 60 - i)),
          precip: i < 14 ? 5.0 : 0.0, // Pluie sur les 14 derniers jours
          tempMean: 18.0,
        ),
      );

      // Prévisions météo (7 jours)
      final weatherForecast = List.generate(
        7,
        (i) => WeatherDay.mock(
          date: DateTime.now().add(Duration(days: i)),
          precip: 2.0,
          tempMean: 18.0,
        ),
      );

      final soilMoisture = SoilMoistureData.mock(moisture: 30.0);
      final terrain = TerrainData.mock(
        elevation: 400.0,
        slope: 12.0,
        aspect: 45.0, // NE
      );
      final forest = ForestData.mock(
        isForest: true,
        forestType: 'feuillu',
        treeDensity: 60.0,
      );

      final forecast = model.calculate(
        weatherHistory: weatherHistory,
        weatherForecast: weatherForecast,
        soilMoistureLayers: [soilMoisture],
        terrain: terrain,
        forest: forest,
        targetDate: DateTime.now(),
      );

      expect(forecast.species, MushroomSpecies.boletusEdulis);
      expect(forecast.index, greaterThanOrEqualTo(0));
      expect(forecast.index, lessThanOrEqualTo(100));
      expect(forecast.confidence, greaterThanOrEqualTo(0.0));
      expect(forecast.confidence, lessThanOrEqualTo(1.0));
    });

    test('calculate handles empty weather history', () async {
      final forecast = model.calculate(
        weatherHistory: [],
        weatherForecast: [],
        soilMoistureLayers: [SoilMoistureData.mock()],
        terrain: TerrainData.mock(),
        forest: ForestData.mock(isForest: true),
        targetDate: DateTime.now(),
      );

      expect(forecast.index, greaterThanOrEqualTo(0));
      expect(forecast.confidence, lessThan(1.0)); // Confiance réduite
    });

    test('calculate returns higher index with optimal conditions', () async {
      // Conditions optimales
      final optimalHistory = List.generate(
        60,
        (i) => WeatherDay.mock(precip: i < 14 ? 10.0 : 0.0, tempMean: 18.0),
      );
      final optimalForecast = List.generate(
        7,
        (i) => WeatherDay.mock(precip: 2.0, tempMean: 18.0),
      );

      final optimalForecastResult = model.calculate(
        weatherHistory: optimalHistory,
        weatherForecast: optimalForecast,
        soilMoistureLayers: [SoilMoistureData.mock(moisture: 50.0)],
        terrain: TerrainData.mock(elevation: 400.0, slope: 12.0, aspect: 45.0),
        forest: ForestData.mock(
          isForest: true,
          forestType: 'feuillu',
          treeDensity: 60.0,
        ),
        targetDate: DateTime.now(),
      );

      // Conditions sous-optimales
      final poorHistory = List.generate(
        60,
        (i) => WeatherDay.mock(precip: 0.0, tempMean: 5.0),
      );
      final poorForecast = List.generate(
        7,
        (i) => WeatherDay.mock(precip: 0.0, tempMean: 5.0),
      );

      final poorForecastResult = model.calculate(
        weatherHistory: poorHistory,
        weatherForecast: poorForecast,
        soilMoistureLayers: [SoilMoistureData.mock(moisture: 10.0)],
        terrain: TerrainData.mock(elevation: 50.0, slope: 35.0, aspect: 180.0),
        forest: ForestData.mock(
          isForest: true,
          forestType: 'conifère',
          treeDensity: 20.0,
        ),
        targetDate: DateTime.now(),
      );

      expect(
        optimalForecastResult.index,
        greaterThan(poorForecastResult.index),
      );
    });
  });
}
