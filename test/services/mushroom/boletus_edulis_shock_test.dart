import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/boletus_edulis_model.dart';

void main() {
  final model = BoletusEdulisModel();
  final target = DateTime.utc(2026, 10, 30);

  List<WeatherDay> weatherSeries({
    int firstDay = -20,
    int lastDay = 0,
    Map<int, double?> rain = const {},
    Map<int, double?> temperatures = const {},
    double? defaultRain = 0,
    double? defaultTemperature = 17,
  }) => [
    for (var offset = firstDay; offset <= lastDay; offset++)
      WeatherDay(
        date: target.add(Duration(days: offset)),
        precipitation: rain.containsKey(offset) ? rain[offset] : defaultRain,
        temperatureMean: temperatures.containsKey(offset)
            ? temperatures[offset]
            : defaultTemperature,
      ),
  ];

  List<SoilMoistureData> soilSeries({
    required int firstDay,
    required int lastDay,
    double? moisture = 10,
    double? soilTemperature,
    double depthStart = 7,
    double depthEnd = 28,
  }) => [
    for (var offset = firstDay; offset <= lastDay; offset++)
      SoilMoistureData(
        date: target.add(Duration(days: offset)),
        depthStart: depthStart,
        depthEnd: depthEnd,
        soilMoisture: moisture,
        soilTemperature: soilTemperature,
      ),
  ];

  MushroomForecast calculate(
    List<WeatherDay> weather, {
    DateTime? targetDate,
    List<SoilMoistureData> soil = const [],
  }) => model.calculate(
    weatherHistory: weather,
    weatherForecast: const [],
    soilMoistureLayers: soil,
    terrain: TerrainData(latitude: 43.5, longitude: 3.5),
    forest: ForestData.mock(isForest: null),
    targetDate: targetDate ?? target,
  );

  group('choc hydro-thermique', () {
    test('choc 8 jours avant la cible produit un facteur élevé', () {
      final weather = weatherSeries(
        rain: {-9: 15, -8: 15},
        temperatures: {-12: 20, -11: 20, -10: 20, -8: 10, -7: 10},
      );
      final result = calculate(weather);

      expect(result.factors.shockFactor, 1.0);
      expect(result.shockDate, target.subtract(const Duration(days: 8)));
      expect(result.shockRainMm, 30);
      expect(result.shockTempDropC, 10);
    });

    test('choc 3 jours avant la cible est hors fenêtre', () {
      final result = calculate(weatherSeries(rain: {-4: 15, -3: 15}));
      expect(result.factors.shockFactor, 0.0);
    });

    test('absence de pluie produit un facteur choc nul', () {
      final result = calculate(weatherSeries());
      expect(result.factors.shockFactor, 0.0);
    });

    test('températures manquantes laissent la composante pluie seule', () {
      final result = calculate(
        weatherSeries(rain: {-9: 15, -8: 15}, defaultTemperature: null),
      );
      expect(result.factors.shockFactor, 1.0);
      expect(result.shockTempDropC, isNull);
    });

    test('pluie après sécheresse sans humidité maintenue reste limitée', () {
      final result = calculate(
        weatherSeries(
          firstDay: -60,
          rain: {0: 40},
          temperatures: {for (var day = -60; day <= 0; day++) day: 17},
        ),
        soil: soilSeries(firstDay: -60, lastDay: 0, moisture: 10),
      );
      expect(result.wetStreak, 0);
      expect(result.hydricGate, lessThan(1));
      expect(result.index, lessThanOrEqualTo(50));
    });

    test('la courbe J+0 à J+7 monte après un choc à J-3', () {
      final weather = weatherSeries(
        firstDay: -60,
        lastDay: 7,
        rain: {-4: 20, -3: 20},
        temperatures: {-7: 22, -6: 22, -5: 22, -3: 10, -2: 10},
      );
      final soil = soilSeries(firstDay: -60, lastDay: 7, moisture: 10);
      final forecasts = [
        for (var day = 0; day <= 7; day++)
          calculate(
            weather,
            targetDate: target.add(Duration(days: day)),
            soil: soil,
          ),
      ];

      expect(forecasts[0].factors.shockFactor, 0.0);
      expect(
        forecasts[3].factors.shockFactor,
        greaterThan(forecasts[2].factors.shockFactor!),
      );
      expect(forecasts[3].factors.shockFactor, 1.0);
      expect(forecasts[7].factors.shockFactor, 1.0);
      expect(forecasts[3].index, greaterThan(forecasts[0].index));
    });

    test('température du sol 0–7 cm remplace celle de l’air', () {
      final result = calculate(
        weatherSeries(),
        soil: soilSeries(
          firstDay: 0,
          lastDay: 0,
          moisture: 30,
          soilTemperature: 10,
          depthStart: 0,
          depthEnd: 7,
        ),
      );
      expect(result.temperatureSource, 'soil_0_7cm');
      expect(result.factors.temperatureFactor, 0.5);
    });
  });
}
