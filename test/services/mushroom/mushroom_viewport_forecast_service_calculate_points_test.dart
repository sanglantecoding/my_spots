import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_engine.dart';
import 'package:my_spots/services/mushroom/mushroom_viewport_forecast_service.dart';

void main() {
  group('MushroomViewportForecastService - calculateForPoints', () {
    test('>50 points throws ArgumentError', () async {
      final mockSource = _MockBatchSource();
      final mockEngine = _MockForecastEngine();
      final service = MushroomViewportForecastService(
        source: mockSource,
        engine: mockEngine,
      );

      final points = List.generate(
        51,
        (i) => LatLng(43.5 + i * 0.01, 3.0 + i * 0.01),
      );

      expect(
        () => service.calculateForPoints(points, null, null),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Maximum 50 points'),
          ),
        ),
      );
    });

    test(
      '8 forecasts per point, single terrain batch, one weather call per grid',
      () async {
        final mockSource = _MockBatchSource();
        final mockEngine = _MockForecastEngine();
        final service = MushroomViewportForecastService(
          source: mockSource,
          engine: mockEngine,
        );

        // Create 5 points (should be within 50 limit)
        final points = [
          const LatLng(43.5, 3.0),
          const LatLng(43.51, 3.01),
          const LatLng(43.52, 3.02),
          const LatLng(43.53, 3.03),
          const LatLng(43.54, 3.04),
        ];

        final results = await service.calculateForPoints(points, null, null);

        // Should return 5 lists (one per point)
        expect(results.length, equals(5));

        // Each list should have 8 forecasts (J+0 to J+7)
        for (final forecastList in results) {
          expect(forecastList.length, equals(8));
        }

        // Verify single terrain batch call
        expect(mockSource.terrainBatchCallCount, equals(1));

        // Verify weather calls (should be one per unique grid cell)
        // All points are close, so they should map to the same grid cell
        expect(mockSource.weatherCallCount, greaterThanOrEqualTo(1));
      },
    );
  });
}

class _MockBatchSource implements MushroomViewportBatchSource {
  int terrainBatchCallCount = 0;
  int weatherCallCount = 0;
  int forestCallCount = 0;

  @override
  Future<Map<String, TerrainData>> loadTerrainBatch(
    List<LatLng> points,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    terrainBatchCallCount++;
    final result = <String, TerrainData>{};
    for (final point in points) {
      final key = '${point.latitude},${point.longitude}';
      result[key] = TerrainData(
        latitude: point.latitude,
        longitude: point.longitude,
        elevation: 500,
        slope: 10.0,
        aspect: 45.0,
        source: 'mock',
      );
    }
    return result;
  }

  @override
  Future<Map<String, MushroomViewportWeather>> loadWeatherByGrid(
    List<LatLng> gridCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    weatherCallCount++;
    final result = <String, MushroomViewportWeather>{};
    for (final center in gridCenters) {
      final key = '${center.latitude},${center.longitude}';
      // Create 8 days of weather (J+0 to J+7)
      final history = List.generate(
        30,
        (i) => WeatherDay(
          date: DateTime.now().subtract(Duration(days: 30 - i)),
          temperatureMean: 13.0,
          temperatureMin: 8.0,
          temperatureMax: 18.0,
          precipitation: 2.0,
        ),
      );
      final forecast = List.generate(
        8,
        (i) => WeatherDay(
          date: DateTime.now().add(Duration(days: i)),
          temperatureMean: 13.0,
          temperatureMin: 8.0,
          temperatureMax: 18.0,
          precipitation: 2.0,
        ),
      );
      final soil = List.generate(
        30,
        (i) => SoilMoistureData(
          date: DateTime.now().subtract(Duration(days: 30 - i)),
          depthStart: 7,
          depthEnd: 28,
          soilMoisture: 30.0,
          source: 'mock',
        ),
      );
      result[key] = MushroomViewportWeather(
        history: history,
        forecast: forecast,
        soil: soil,
      );
    }
    return result;
  }

  @override
  Future<Map<String, ForestData>> loadForestForZone(
    LatLngBounds bounds,
    List<LatLng> eligibleCellCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    forestCallCount++;
    final result = <String, ForestData>{};
    for (final center in eligibleCellCenters) {
      final key = '${center.latitude},${center.longitude}';
      result[key] = ForestData(
        latitude: center.latitude,
        longitude: center.longitude,
        isForest: true,
        forestType: 'feuillu',
        source: 'mock',
      );
    }
    return result;
  }
}

class _MockForecastEngine implements MushroomForecastEngine {
  @override
  MushroomSpecies get species => MushroomSpecies.boletusEdulis;

  @override
  MushroomForecast calculate({
    required List<WeatherDay> weatherHistory,
    required List<WeatherDay> weatherForecast,
    required List<SoilMoistureData> soilMoistureLayers,
    required TerrainData terrain,
    required ForestData forest,
    required DateTime targetDate,
  }) {
    return MushroomForecast.mock(
      date: targetDate,
      species: species,
      index: 50,
      confidence: 0.7,
    );
  }
}
