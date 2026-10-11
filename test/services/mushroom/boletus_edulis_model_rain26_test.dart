import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/boletus_edulis_model.dart';

void main() {
  group('BoletusEdulisModel - rain26 cap', () {
    test('rain26 200mm -> water factor <= 1.0, index <= 100', () {
      final model = BoletusEdulisModel();
      final targetDate = DateTime.utc(2026, 10, 15);

      // Create 26 days of weather with 200mm total rain
      final weatherHistory = List.generate(26, (i) {
        final date = targetDate.subtract(Duration(days: i + 1));
        return WeatherDay(
          date: date,
          precipitation: 200.0 / 26, // ~7.7mm per day
          temperatureMean: 13.0,
          temperatureMin: 8.0,
          temperatureMax: 18.0,
        );
      });

      final weatherForecast = <WeatherDay>[];

      // Create soil moisture data
      final soilMoistureLayers = [
        SoilMoistureData(
          date: targetDate,
          depthStart: 7,
          depthEnd: 28,
          soilMoisture: 30.0,
          source: 'ecmwf',
        ),
      ];

      // Create terrain data
      final terrain = TerrainData(
        latitude: 43.5,
        longitude: 3.0,
        elevation: 500,
        slope: 10.0,
        aspect: 45.0,
        source: 'ign',
      );

      // Create forest data
      final forest = ForestData(
        latitude: 43.5,
        longitude: 3.0,
        isForest: true,
        forestType: 'feuillu',
        source: 'ign',
      );

      final forecast = model.calculate(
        weatherHistory: weatherHistory,
        weatherForecast: weatherForecast,
        soilMoistureLayers: soilMoistureLayers,
        terrain: terrain,
        forest: forest,
        targetDate: targetDate,
      );

      // Water factor should be clamped to 1.0 (no excess penalty)
      expect(forecast.factors.waterFactor, lessThanOrEqualTo(1.0));

      // Index should be <= 100
      expect(forecast.index, lessThanOrEqualTo(100));

      // rain26 should be 200mm
      expect(forecast.rain26, closeTo(200.0, 1.0));
    });
  });
}
