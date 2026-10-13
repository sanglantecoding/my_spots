import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_engine.dart';
import 'package:my_spots/services/mushroom/mushroom_viewport_forecast_service.dart';
import 'package:my_spots/services/mushroom/point_key.dart';

void main() {
  group('MushroomViewportForecastService.calculateForPoints timeouts', () {
    test('stage signaling order: altitude, météo, forêt', () async {
      final stages = <String>[];
      final warnings = <String>[];

      final mockSource = _MockSourceWithStages(
        onStage: (stage) => stages.add(stage),
        onWarning: (warning) => warnings.add(warning),
      );
      final mockEngine = _MockForecastEngine();
      final service = MushroomViewportForecastService(
        source: mockSource,
        engine: mockEngine,
      );

      final points = [const LatLng(43.5, 3.0), const LatLng(43.51, 3.01)];

      await service.calculateForPoints(
        points,
        (stage) => stages.add(stage),
        (warning) => warnings.add(warning),
      );

      // Verify stages are called in order
      expect(stages, contains('altitude'));
      expect(stages, contains('météo'));
      expect(stages, contains('forêt 0/0 tuiles'));

      // Verify altitude comes before weather
      final altitudeIndex = stages.indexOf('altitude');
      final meteoIndex = stages.indexOf('météo');
      expect(altitudeIndex, lessThan(meteoIndex));
    });

    test(
      'forest timeout gives forecasts with unknown forest and warning',
      () async {
        final warnings = <String>[];

        final mockSource = _MockSourceWithForestTimeout();
        final mockEngine = _MockForecastEngine();
        final service = MushroomViewportForecastService(
          source: mockSource,
          engine: mockEngine,
        );

        final points = [const LatLng(43.5, 3.0)];

        final results = await service.calculateForPoints(
          points,
          null,
          (warning) => warnings.add(warning),
        );

        // Should return 8 forecasts even with forest timeout
        expect(results.length, equals(1));
        expect(results[0].length, equals(8));

        // Should have warning about forest timeout
        expect(warnings, contains('Forêt non chargée (délai)'));
      },
    );
  });
}

class _MockSourceWithStages implements MushroomViewportBatchSource {
  _MockSourceWithStages({this.onStage, this.onWarning});

  final void Function(String)? onStage;
  final void Function(String)? onWarning;

  @override
  Future<Map<String, TerrainData>> loadTerrainBatch(
    List<LatLng> cellCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    onStage?.call('altitude');
    return {
      for (final center in cellCenters)
        mushroomViewportPointKey(center): TerrainData(
          latitude: center.latitude,
          longitude: center.longitude,
          elevation: 500,
          slope: 5,
          aspect: 180,
          source: 'mock',
        ),
    };
  }

  @override
  Future<Map<String, MushroomViewportWeather>> loadWeatherByGrid(
    List<LatLng> uniqueModelGridCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    onStage?.call('météo');
    return {
      for (final center in uniqueModelGridCenters)
        mushroomViewportPointKey(center): const MushroomViewportWeather(
          history: [],
          forecast: [],
          soil: [],
        ),
    };
  }

  @override
  Future<Map<String, ForestData>> loadForestForZone(
    LatLngBounds bounds,
    List<LatLng> eligibleCellCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    onStage?.call('forêt 0/0 tuiles');
    return {
      for (final center in eligibleCellCenters)
        mushroomViewportPointKey(center): ForestData(
          latitude: center.latitude,
          longitude: center.longitude,
          isForest: true,
          forestType: 'feuillu',
          source: 'mock',
        ),
    };
  }
}

class _MockSourceWithForestTimeout implements MushroomViewportBatchSource {
  @override
  Future<Map<String, TerrainData>> loadTerrainBatch(
    List<LatLng> cellCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    return {
      for (final center in cellCenters)
        mushroomViewportPointKey(center): TerrainData(
          latitude: center.latitude,
          longitude: center.longitude,
          elevation: 500,
          slope: 5,
          aspect: 180,
          source: 'mock',
        ),
    };
  }

  @override
  Future<Map<String, MushroomViewportWeather>> loadWeatherByGrid(
    List<LatLng> uniqueModelGridCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    return {
      for (final center in uniqueModelGridCenters)
        mushroomViewportPointKey(center): const MushroomViewportWeather(
          history: [],
          forecast: [],
          soil: [],
        ),
    };
  }

  @override
  Future<Map<String, ForestData>> loadForestForZone(
    LatLngBounds bounds,
    List<LatLng> eligibleCellCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    // Simulate timeout by throwing immediately
    throw TimeoutException('Forest timeout');
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
      habitat: forest.isForest == true
          ? HabitatStatus.suitable
          : HabitatStatus.unknown,
    );
  }
}
