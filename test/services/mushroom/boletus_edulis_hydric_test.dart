import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/boletus_edulis_model.dart';

void main() {
  final model = BoletusEdulisModel();
  final baseDate = DateTime.utc(2026, 9, 30);

  List<WeatherDay> rainSeries(List<double?> rain, {List<double?>? et0}) =>
      List<WeatherDay>.generate(rain.length, (index) {
        final date = baseDate.subtract(Duration(days: rain.length - index - 1));
        return WeatherDay(
          date: date,
          precipitation: rain[index],
          et0: et0?[index],
          temperatureMean: 17,
        );
      });

  List<SoilMoistureData> moistureSeries(
    List<double?> values, {
    double start = 7,
    double end = 28,
  }) => List<SoilMoistureData>.generate(values.length, (index) {
    final date = baseDate.subtract(Duration(days: values.length - index - 1));
    return SoilMoistureData(
      date: date,
      depthStart: start,
      depthEnd: end,
      soilMoisture: values[index],
    );
  });

  double? water(
    List<WeatherDay> weather, {
    List<SoilMoistureData> soil = const [],
    DateTime? target,
  }) => model
      .calculate(
        weatherHistory: weather,
        weatherForecast: const [],
        soilMoistureLayers: soil,
        terrain: TerrainData.mock(),
        forest: ForestData.mock(isForest: true),
        targetDate: target ?? baseDate,
      )
      .factors
      .waterFactor;

  group('persistance hydrique', () {
    test('statistiques 7-28 cm: min, médiane, max et percentile', () {
      final forecast = model.calculate(
        weatherHistory: const [],
        weatherForecast: const [],
        soilMoistureLayers: moistureSeries([10, 20, 30, 40, 50]),
        terrain: TerrainData.mock(),
        forest: ForestData.mock(isForest: true),
        targetDate: baseDate,
      );

      expect(forecast.soilMoisture7To28Min60dPercent, 10);
      expect(forecast.soilMoisture7To28Median60dPercent, 30);
      expect(forecast.soilMoisture7To28Max60dPercent, 50);
      expect(forecast.soilMoisture7To28Percentile60d, 100);
    });

    test('série vide laisse toutes les statistiques inconnues', () {
      final forecast = model.calculate(
        weatherHistory: const [],
        weatherForecast: const [],
        soilMoistureLayers: const [],
        terrain: TerrainData.mock(),
        forest: ForestData.mock(isForest: true),
        targetDate: baseDate,
      );

      expect(forecast.soilMoisture7To28Min60dPercent, isNull);
      expect(forecast.soilMoisture7To28Median60dPercent, isNull);
      expect(forecast.soilMoisture7To28Max60dPercent, isNull);
      expect(forecast.soilMoisture7To28Percentile60d, isNull);
    });

    test('série constante conserve min médiane max et rang à 100', () {
      final forecast = model.calculate(
        weatherHistory: const [],
        weatherForecast: const [],
        soilMoistureLayers: moistureSeries(List<double>.filled(4, 41)),
        terrain: TerrainData.mock(),
        forest: ForestData.mock(isForest: true),
        targetDate: baseDate,
      );

      expect(forecast.soilMoisture7To28Min60dPercent, 41);
      expect(forecast.soilMoisture7To28Median60dPercent, 41);
      expect(forecast.soilMoisture7To28Max60dPercent, 41);
      expect(forecast.soilMoisture7To28Percentile60d, 100);
    });

    test('7–28 cm est prioritaire et 0–7 cm est le repli', () {
      List<SoilMoistureData> layers({required bool includePrimary}) => [
        for (var offset = -4; offset <= 0; offset++) ...[
          if (includePrimary)
            SoilMoistureData(
              date: baseDate.add(Duration(days: offset)),
              depthStart: 7,
              depthEnd: 28,
              soilMoisture: 10,
            ),
          SoilMoistureData(
            date: baseDate.add(Duration(days: offset)),
            depthStart: 0,
            depthEnd: 7,
            soilMoisture: 40,
            soilTemperature: 14,
          ),
        ],
      ];
      MushroomForecast calculate(List<SoilMoistureData> soil) =>
          model.calculate(
            weatherHistory: rainSeries(List<double>.filled(5, 4)),
            weatherForecast: const [],
            soilMoistureLayers: soil,
            terrain: TerrainData.mock(),
            forest: ForestData.mock(isForest: true),
            targetDate: baseDate,
          );

      final priority = calculate(layers(includePrimary: true));
      final fallback = calculate(layers(includePrimary: false));

      expect(priority.wetStreak, 0);
      expect(fallback.wetStreak, 5);
      expect(priority.soilMoisture0To7Percent, 40);
      expect(priority.soilMoisture7To28Percent, 10);
      expect(priority.soilTemperature0To7C, 14);
    });

    test('60 jours secs puis 24 mm ponctuels : facteur plafonné', () {
      final weather = rainSeries([...List<double>.filled(60, 0), 24]);
      final result = model.calculate(
        weatherHistory: weather,
        weatherForecast: const [],
        soilMoistureLayers: moistureSeries(List<double>.filled(61, 10)),
        terrain: TerrainData.mock(),
        forest: ForestData.mock(isForest: true),
        targetDate: baseDate,
      );

      expect(result.factors.waterFactor, lessThanOrEqualTo(0.3));
      expect(result.wetStreak, 0);
      expect(result.dryBefore, greaterThanOrEqualTo(14));
    });

    test('5 jours de pluie et humidité croissante restaurent le facteur', () {
      final rain = <double?>[...List<double>.filled(60, 0), 5, 6, 7, 8, 9];
      final moisture = <double?>[
        ...List<double>.filled(60, 10),
        25.0,
        30.0,
        35.0,
        40.0,
        45.0,
      ];
      final result = model.calculate(
        weatherHistory: rainSeries(rain),
        weatherForecast: const [],
        soilMoistureLayers: moistureSeries(moisture),
        terrain: TerrainData.mock(),
        forest: ForestData.mock(isForest: true),
        targetDate: baseDate,
      );

      expect(result.factors.waterFactor, greaterThanOrEqualTo(0.7));
      expect(result.wetStreak, 5);
    });

    test('pluie régulière maintenue sur 60 jours donne un facteur élevé', () {
      final factor = water(
        rainSeries(List<double>.filled(60, 5), et0: List<double>.filled(60, 2)),
        soil: moistureSeries(List<double>.filled(60, 35)),
      );
      expect(factor, greaterThanOrEqualTo(0.7));
    });

    test('humidité du sol absente : les autres termes restent calculés', () {
      final factor = water(
        rainSeries(List<double>.filled(14, 5), et0: List<double>.filled(14, 2)),
      );
      expect(factor, isNotNull);
      expect(factor, greaterThan(0));
    });

    test('J+0 et J+7 ont des persistances hydriques distinctes', () {
      final history = List<WeatherDay>.generate(60, (index) {
        return WeatherDay(
          date: baseDate.subtract(Duration(days: 60 - index)),
          precipitation: 0,
        );
      });
      final forecast = List<WeatherDay>.generate(8, (index) {
        const precipitation = [24.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0, 0.0];
        return WeatherDay(
          date: baseDate.add(Duration(days: index)),
          kind: WeatherDataKind.forecast,
          precipitation: precipitation[index],
        );
      });
      final soil =
          moistureSeries(List<double>.filled(60, 28))
              .map(
                (item) => SoilMoistureData(
                  date: item.date.subtract(const Duration(days: 1)),
                  depthStart: item.depthStart,
                  depthEnd: item.depthEnd,
                  soilMoisture: item.soilMoisture,
                ),
              )
              .toList() +
          List<SoilMoistureData>.generate(8, (index) {
            return SoilMoistureData(
              date: baseDate.add(Duration(days: index)),
              kind: SoilMoistureDataKind.forecast,
              depthStart: 7,
              depthEnd: 28,
              soilMoisture: 28,
            );
          });
      final f0 = model.calculate(
        weatherHistory: history,
        weatherForecast: forecast,
        soilMoistureLayers: soil,
        terrain: TerrainData.mock(),
        forest: ForestData.mock(isForest: true),
        targetDate: baseDate,
      );
      final f7 = model.calculate(
        weatherHistory: history,
        weatherForecast: forecast,
        soilMoistureLayers: soil,
        terrain: TerrainData.mock(),
        forest: ForestData.mock(isForest: true),
        targetDate: baseDate.add(const Duration(days: 7)),
      );

      expect(f0.wetStreak, isNot(f7.wetStreak));
      expect(f0.factors.waterFactor, isNot(f7.factors.waterFactor));
    });

    test('sécheresse puis pluie ponctuelle limite l’indice final à 40', () {
      final weather = rainSeries([...List<double>.filled(60, 0), 24]);
      final forecast = model.calculate(
        weatherHistory: weather,
        weatherForecast: const [],
        soilMoistureLayers: moistureSeries(List<double>.filled(61, 10)),
        terrain: TerrainData(latitude: 43.5, longitude: 3.5),
        forest: ForestData.mock(isForest: null),
        targetDate: baseDate,
      );

      expect(forecast.factors.temperatureFactor, 1.0);
      expect(forecast.factors.waterFactor, lessThanOrEqualTo(0.3));
      expect(forecast.hydricGate, lessThanOrEqualTo(0.6));
      expect(forecast.index, lessThanOrEqualTo(40));
    });

    test(
      'humidité maintenue après pluie donne gate 1 et indice au moins 70',
      () {
        final rain = <double?>[...List<double>.filled(60, 0), 5, 6, 7, 8, 9];
        final moisture = <double?>[
          ...List<double>.filled(60, 10),
          25.0,
          30.0,
          35.0,
          40.0,
          45.0,
        ];
        final forecast = model.calculate(
          weatherHistory: rainSeries(rain),
          weatherForecast: const [],
          soilMoistureLayers: moistureSeries(moisture),
          terrain: TerrainData.mock(elevation: 500, slope: 10, aspect: 90),
          forest: ForestData.mock(
            isForest: true,
            forestType: 'feuillu',
            treeDensity: 60,
          ),
          targetDate: baseDate,
        );

        expect(forecast.hydricGate, 1.0);
        expect(forecast.index, greaterThanOrEqualTo(70));
      },
    );

    test('pluie régulière laisse l’agrégation pré-porte inchangée', () {
      final forecast = model.calculate(
        weatherHistory: rainSeries(
          List<double>.filled(60, 5),
          et0: List<double>.filled(60, 2),
        ),
        weatherForecast: const [],
        soilMoistureLayers: moistureSeries(List<double>.filled(60, 35)),
        terrain: TerrainData.mock(elevation: 500, slope: 10, aspect: 90),
        forest: ForestData.mock(
          isForest: true,
          forestType: 'feuillu',
          treeDensity: 60,
        ),
        targetDate: baseDate,
      );
      final factors = forecast.factors;
      final preGateIndex =
          ((factors.waterFactor! * 0.25 +
                      factors.temperatureFactor! * 0.15 +
                      factors.dryingFactor * 0.10 +
                      factors.shockFactor! * 0.20 +
                      factors.terrainFactor! * 0.15 +
                      factors.forestFactor! * 0.15) *
                  100)
              .round();

      expect(forecast.hydricGate, 1.0);
      expect(forecast.index, preGateIndex);
    });

    test('waterFactor inconnu laisse gate à 1 sans inventer une valeur', () {
      final forecast = model.calculate(
        weatherHistory: const [],
        weatherForecast: const [],
        soilMoistureLayers: const [],
        terrain: TerrainData(latitude: 43.5, longitude: 3.5),
        forest: ForestData.mock(isForest: null),
        targetDate: baseDate,
      );

      expect(forecast.factors.waterFactor, isNull);
      expect(forecast.hydricGate, 1.0);
    });
  });
}
