import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
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
    group('facteurs nullables et renormalisation', () {
      late List<WeatherDay> weatherHistory;
      late List<WeatherDay> forecast;
      late SoilMoistureData soilMoisture;
      late TerrainData terrain;

      setUp(() {
        weatherHistory = List.generate(
          60,
          (i) => WeatherDay.mock(
            date: DateTime.now().subtract(Duration(days: 60 - i)),
            precip: i < 14 ? 5.0 : 0.0,
            tempMean: 18.0,
          ),
        );
        forecast = List.generate(
          7,
          (i) => WeatherDay.mock(
            date: DateTime.now().add(Duration(days: i)),
            precip: 2.0,
            tempMean: 18.0,
          ),
        );
        soilMoisture = SoilMoistureData.mock(moisture: 30.0);
        terrain = TerrainData.mock(elevation: 400.0, slope: 12.0, aspect: 45.0);
      });

      test('(a) forêt inconnue ne baisse pas l\'indice par rapport au '
          'calcul renormalisé sur les 4 autres facteurs connus', () {
        final forestKnownZero = ForestData.mock(
          isForest: false, // forêt connue et défavorable -> facteur = 0.0
        );
        final forestUnknown = ForestData.mock(
          isForest: null,
          forestType: null,
          treeDensity: null,
        );

        final withForestKnownZero = model.calculate(
          weatherHistory: weatherHistory,
          weatherForecast: forecast,
          soilMoistureLayers: [soilMoisture],
          terrain: terrain,
          forest: forestKnownZero,
          targetDate: DateTime.now(),
        );
        final withForestUnknown = model.calculate(
          weatherHistory: weatherHistory,
          weatherForecast: forecast,
          soilMoistureLayers: [soilMoisture],
          terrain: terrain,
          forest: forestUnknown,
          targetDate: DateTime.now(),
        );

        // Le facteur forêt est bien null dans le cas inconnu.
        expect(withForestUnknown.factors.forestFactor, isNull);

        // Avec forêt connue = 0, le facteur forêt participe (valeur 0)
        // et le poids 0.15 est gaspillé sur une valeur nulle.
        // Avec forêt inconnue, elle est exclue et les 4 poids connus sont
        // renormalisés (somme 0.85 -> 1.0), donc l\'indice ne doit pas
        // être pénalisé.
        expect(withForestUnknown.index, greaterThan(withForestKnownZero.index));
      });

      test('(b) la confiance est plus basse quand la forêt est inconnue '
          'par rapport à une forêt connue', () {
        final fullTerrain = TerrainData.mock(
          elevation: 400.0,
          slope: 12.0,
          aspect: 45.0,
        );
        final forestKnown = ForestData.mock(
          isForest: true,
          forestType: 'feuillu',
          treeDensity: 60.0,
        );
        final forestUnknown = ForestData.mock(
          isForest: null,
          forestType: null,
          treeDensity: null,
        );
        final targetDate = DateTime.utc(2026, 9, 1);
        final weather = List<WeatherDay>.generate(40, (index) {
          return WeatherDay(
            date: targetDate.subtract(Duration(days: 39 - index)),
            precipitation: 4,
            temperatureMean: 17,
          );
        });
        final soil = [
          SoilMoistureData(
            date: targetDate,
            depthStart: 7,
            depthEnd: 28,
            soilMoisture: 30,
            soilTemperature: 15,
          ),
        ];

        final withForestKnown = model.calculate(
          weatherHistory: weather,
          weatherForecast: [],
          soilMoistureLayers: soil,
          terrain: fullTerrain,
          forest: forestKnown,
          targetDate: targetDate,
        );
        final withForestUnknown = model.calculate(
          weatherHistory: weather,
          weatherForecast: [],
          soilMoistureLayers: soil,
          terrain: fullTerrain,
          forest: forestUnknown,
          targetDate: targetDate,
        );

        expect(
          withForestUnknown.confidence,
          lessThan(withForestKnown.confidence),
        );
      });

      test('la confiance baisse lorsque les mesures du sol manquent', () {
        final targetDate = DateTime(2026, 9, 1);
        final history = List.generate(
          40,
          (i) => WeatherDay.mock(
            date: targetDate.subtract(Duration(days: 39 - i)),
            tempMean: 16,
            precip: 4,
          ),
        );
        final terrain = TerrainData.mock(elevation: 400, slope: 10, aspect: 90);
        final forest = ForestData.mock(isForest: true);
        final withSoil = model.calculate(
          weatherHistory: history,
          weatherForecast: const [],
          terrain: terrain,
          forest: forest,
          soilMoistureLayers: [
            SoilMoistureData.mock(
              date: targetDate,
              moisture: 30,
              soilTemperature: 15,
              depthStart: 0,
              depthEnd: 7,
            ),
          ],
          targetDate: targetDate,
        );
        final withoutSoil = model.calculate(
          weatherHistory: history,
          weatherForecast: const [],
          terrain: terrain,
          forest: forest,
          soilMoistureLayers: const [],
          targetDate: targetDate,
        );

        expect(withoutSoil.confidence, lessThan(withSoil.confidence));
      });

      test('(c) terrain entièrement null donne terrainFactor == null', () {
        // TerrainData.mock() a des valeurs par défaut non nulls ; on utilise
        // le constructeur direct pour obtenir elevation/slope/aspect == null.
        final terrainNull = TerrainData(latitude: 43.5, longitude: 3.5);
        final forestKnown = ForestData.mock(
          isForest: true,
          forestType: 'feuillu',
          treeDensity: 60.0,
        );

        final forecast = model.calculate(
          weatherHistory: [],
          weatherForecast: [],
          soilMoistureLayers: [],
          terrain: terrainNull,
          forest: forestKnown,
          targetDate: DateTime.now(),
        );

        expect(forecast.factors.terrainFactor, isNull);
      });

      test('(d) avec toutes les données, les facteurs restent non-nulls', () {
        final terrain = TerrainData.mock(
          elevation: 400.0,
          slope: 12.0,
          aspect: 45.0,
        );
        final forest = ForestData.mock(
          isForest: true,
          forestType: 'feuillu',
          treeDensity: 60.0,
        );
        final forecast = model.calculate(
          weatherHistory: [],
          weatherForecast: [],
          soilMoistureLayers: [],
          terrain: terrain,
          forest: forest,
          targetDate: DateTime.now(),
        );

        expect(forecast.factors.terrainFactor, isNotNull);
        expect(forecast.factors.forestFactor, isNotNull);
      });

      test('terrain renormalise les seuls sous-scores connus', () {
        final slopeOnly = model.calculate(
          weatherHistory: [],
          weatherForecast: [],
          soilMoistureLayers: [],
          terrain: TerrainData(latitude: 43.5, longitude: 3.5, slope: 12),
          forest: ForestData.mock(isForest: false),
          targetDate: DateTime(2026, 9, 1),
        );
        final slopeAndAspect = model.calculate(
          weatherHistory: [],
          weatherForecast: [],
          soilMoistureLayers: [],
          terrain: TerrainData(
            latitude: 43.5,
            longitude: 3.5,
            slope: 12,
            aspect: 180,
          ),
          forest: ForestData.mock(isForest: false),
          targetDate: DateTime(2026, 9, 1),
        );
        final elevationOnly = model.calculate(
          weatherHistory: [],
          weatherForecast: [],
          soilMoistureLayers: [],
          terrain: TerrainData(latitude: 43.5, longitude: 3.5, elevation: 50),
          forest: ForestData.mock(isForest: false),
          targetDate: DateTime(2026, 9, 1),
        );

        expect(slopeOnly.factors.terrainFactor, 1.0);
        expect(slopeAndAspect.factors.terrainFactor, closeTo(0.785714, 0.0001));
        expect(elevationOnly.factors.terrainFactor, 0.5);
      });

      test('forêt utilise seulement les sous-scores connus', () {
        MushroomForecast calculate(ForestData forest) => model.calculate(
          weatherHistory: [],
          weatherForecast: [],
          soilMoistureLayers: [],
          terrain: TerrainData(latitude: 43.5, longitude: 3.5),
          forest: forest,
          targetDate: DateTime(2026, 9, 1),
        );

        expect(
          calculate(ForestData.mock(isForest: true)).factors.forestFactor,
          1.0,
        );
        expect(
          calculate(
            ForestData.mock(isForest: true, treeDensity: 30),
          ).factors.forestFactor,
          closeTo(0.7, 0.0001),
        );
        expect(
          calculate(
            ForestData.mock(isForest: true, forestType: 'feuillu'),
          ).factors.forestFactor,
          1.0,
        );
        expect(
          calculate(ForestData.mock(isForest: false)).factors.forestFactor,
          0.0,
        );
      });

      test(
        'eau exclut les entrées manquantes et devient null si tout manque',
        () {
          MushroomForecast calculate({
            List<WeatherDay> weather = const [],
            List<SoilMoistureData> soil = const [],
          }) => model.calculate(
            weatherHistory: weather,
            weatherForecast: [],
            soilMoistureLayers: soil,
            terrain: TerrainData(latitude: 43.5, longitude: 3.5),
            forest: ForestData.mock(isForest: true),
            targetDate: DateTime(2026, 9, 1),
          );

          final rainOnly = calculate(
            weather: [
              WeatherDay.mock(
                date: DateTime(2026, 9, 1),
                precip: 25,
                tempMean: 16,
              ),
              WeatherDay.mock(date: DateTime(2026, 8, 31)),
            ],
          );
          final moistureOnly = calculate(
            soil: [
              SoilMoistureData.mock(
                date: DateTime(2026, 9, 1),
                depthStart: 0,
                depthEnd: 7,
                moisture: 25,
              ),
            ],
          );
          final noWaterData = calculate(
            weather: [WeatherDay.mock(date: DateTime(2026, 9, 1))],
          );
          final knownZeroWater = calculate(
            weather: [
              WeatherDay.mock(
                date: DateTime(2026, 9, 1),
                precip: 0,
                tempMean: 5,
              ),
            ],
            soil: [
              SoilMoistureData.mock(date: DateTime(2026, 9, 1), moisture: 0),
            ],
          );

          expect(rainOnly.factors.waterFactor, closeTo(0.083333, 0.00001));
          expect(moistureOnly.factors.waterFactor, closeTo(0.2, 0.00001));
          expect(noWaterData.factors.waterFactor, isNull);
          expect(noWaterData.index, greaterThan(knownZeroWater.index));
        },
      );

      test(
        'température exclut les mesures nulles et devient inconnue sans mesure',
        () {
          MushroomForecast calculate(List<WeatherDay> weather) =>
              model.calculate(
                weatherHistory: weather,
                weatherForecast: [],
                soilMoistureLayers: [],
                terrain: TerrainData(latitude: 43.5, longitude: 3.5),
                forest: ForestData.mock(isForest: true),
                targetDate: DateTime(2026, 9, 1),
              );

          final partial = calculate([
            WeatherDay.mock(date: DateTime(2026, 9, 1), tempMean: 16),
            WeatherDay.mock(date: DateTime(2026, 8, 31)),
          ]);
          final missing = calculate([
            WeatherDay.mock(date: DateTime(2026, 9, 1), precip: 4),
          ]);

          expect(partial.factors.temperatureFactor, 1.0);
          expect(missing.factors.temperatureFactor, isNull);
        },
      );

      test(
        'confiance baisse quand les facteurs eau et température manquent',
        () {
          MushroomForecast calculate(List<WeatherDay> weather) =>
              model.calculate(
                weatherHistory: weather,
                weatherForecast: [],
                soilMoistureLayers: [],
                terrain: TerrainData(
                  latitude: 43.5,
                  longitude: 3.5,
                  slope: 12,
                  aspect: 45,
                  elevation: 400,
                ),
                forest: ForestData.mock(
                  isForest: true,
                  forestType: 'feuillu',
                  treeDensity: 60,
                ),
                targetDate: DateTime(2026, 9, 1),
              );

          final known = calculate([
            WeatherDay.mock(
              date: DateTime(2026, 9, 1),
              precip: 4,
              tempMean: 16,
            ),
          ]);
          final missing = calculate([
            WeatherDay.mock(date: DateTime(2026, 9, 1)),
          ]);

          expect(missing.confidence, lessThan(known.confidence));
        },
      );
    });
  });
}
