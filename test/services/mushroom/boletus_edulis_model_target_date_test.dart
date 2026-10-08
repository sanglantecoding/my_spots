import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/boletus_edulis_model.dart';

void main() {
  group('BoletusEdulisModel – targetDate influence l\'indice', () {
    final terrain = TerrainData.mock(
      lat: 44.0,
      lng: 1.0,
      elevation: 500.0,
      slope: 10.0,
      aspect: 90.0,
    );
    final forest = ForestData.mock(
      lat: 44.0,
      lng: 1.0,
      isForest: true,
      forestType: 'feuillu',
      treeDensity: 60.0,
    );

    final model = BoletusEdulisModel();

    // Dates racines : historique 60 j, prévisions 8 j
    final today = DateTime.utc(2026, 8, 1);
    final j0 = today; // J+0
    final j7 = today.add(const Duration(days: 7));

    List<WeatherDay> buildHistorical({
      required double tempC,
      required double precipMm,
    }) {
      final days = <WeatherDay>[];
      for (var i = 60; i >= 1; i--) {
        final d = today.subtract(Duration(days: i));
        days.add(
          WeatherDay(
            date: d,
            kind: WeatherDataKind.historical,
            temperatureMin: tempC - 2,
            temperatureMax: tempC + 2,
            temperatureMean: tempC,
            precipitation: precipMm,
          ),
        );
      }
      return days;
    }

    List<WeatherDay> buildForecast({
      required List<double> temps, // length = 8
      required List<double> preci, // length = 8
    }) {
      assert(temps.length == 8);
      assert(preci.length == 8);
      return List<WeatherDay>.generate(8, (i) {
        return WeatherDay(
          date: today.add(Duration(days: i)),
          kind: WeatherDataKind.forecast,
          temperatureMin: temps[i] - 2,
          temperatureMax: temps[i] + 2,
          temperatureMean: temps[i],
          precipitation: preci[i],
        );
      });
    }

    List<SoilMoistureData> buildSoilMoisture({
      required double humidityPct,
      required int days, // jours historiques
    }) {
      final layers = <SoilMoistureData>[];
      final layerSpecs = const <(double s, double e)>[
        (0, 1),
        (1, 3),
        (3, 9),
        (9, 27),
        (27, 81),
      ];
      for (var i = days - 1; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        for (final (s, e) in layerSpecs) {
          layers.add(
            SoilMoistureData(
              date: d,
              kind: SoilMoistureDataKind.historical,
              depthStart: s,
              depthEnd: e,
              soilMoisture: humidityPct,
              source: 'ecmwf_ifs025',
            ),
          );
        }
      }
      // Ajouter aussi 8 j de prévisions pour pouvoir cibler J+0..J+7
      for (var i = 0; i < 8; i++) {
        final d = today.add(Duration(days: i));
        for (final (s, e) in layerSpecs) {
          layers.add(
            SoilMoistureData(
              date: d,
              kind: SoilMoistureDataKind.forecast,
              depthStart: s,
              depthEnd: e,
              soilMoisture: humidityPct,
              source: 'ecmwf_ifs025',
            ),
          );
        }
      }
      return layers;
    }

    test('J+0 ≠ J+7 : scénario canicule J+7 vs pluie J+0', () {
      // Historique global : T=16°C, pluie moyenne
      final history = buildHistorical(tempC: 16.0, precipMm: 4.0);
      const baseTemp = 16.0;
      const basePrecip = 4.0;
      // Prévisions : J+0 reste conforme à l'historique (16°C, 4 mm)
      // puis J+1..J+7 deviennent caniculaires : 28°C + zéro pluie.
      final forecastTemps = <double>[
        baseTemp,
        20.0,
        24.0,
        26.0,
        27.0,
        27.5,
        27.8,
        28.0,
      ];
      final forecastPreci = <double>[
        basePrecip,
        1.0,
        0.5,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
      ];
      final forecast = buildForecast(
        temps: forecastTemps,
        preci: forecastPreci,
      );
      final soil = buildSoilMoisture(humidityPct: 28.0, days: 60);

      final MushroomForecast f0 = model.calculate(
        weatherHistory: history,
        weatherForecast: forecast,
        soilMoistureLayers: soil,
        terrain: terrain,
        forest: forest,
        targetDate: j0,
      );
      final MushroomForecast f7 = model.calculate(
        weatherHistory: history,
        weatherForecast: forecast,
        soilMoistureLayers: soil,
        terrain: terrain,
        forest: forest,
        targetDate: j7,
      );

      // Vérifie que les dates sont bien positionnées
      expect(f0.date.year, j0.year);
      expect(f0.date.month, j0.month);
      expect(f0.date.day, j0.day);
      expect(f7.date.year, j7.year);
      expect(f7.date.month, j7.month);
      expect(f7.date.day, j7.day);

      // L'indice J+7 doit être SIGNIFICATIVEMENT inférieur à J+0
      // (pénalités : T élevée, jours secs cumulés, pluie récente nulle)
      expect(f7.index, lessThan(f0.index - 5));

      // Le facteur température doit être dégradé à J+7
      expect(
        f7.factors.temperatureFactor!,
        lessThanOrEqualTo(f0.factors.temperatureFactor!),
      );

      // Le facteur séchage doit être dégradé à J+7 (plusieurs jours secs)
      expect(
        f7.factors.dryingFactor,
        lessThanOrEqualTo(f0.factors.dryingFactor),
      );
    });
  });
}
