import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/services/mushroom/boletus_edulis_model.dart';
import 'package:my_spots/services/mushroom/mushroom_viewport_forecast_service.dart';

void main() {
  const salvetat = LatLng(43.57158, 2.71777);
  final bounds = LatLngBounds(
    const LatLng(43.5703, 2.7162),
    const LatLng(43.5728, 2.7193),
  );

  test(
    'zone Salvetat charge altitude/forêt en batch et météo par maille',
    () async {
      final source = _FakeViewportSource();
      final service = _service(source);
      final result = await service.calculate(
        bounds: bounds,
        zoom: 13,
        startDate: DateTime(2026, 10, 9),
      );

      expect(result.status, MushroomViewportStatus.ready);
      expect(result.cells, isNotEmpty);
      expect(result.cells.length, lessThanOrEqualTo(400));
      expect(result.cells.first.forecasts, hasLength(8));
      expect(result.cells.first.forecasts.first.date, DateTime(2026, 10, 9));
      expect(source.terrainBatchCalls, 1);
      expect(source.forestZoneCalls, 1);
      expect(source.weatherBatchCalls, 1);
      expect(source.weatherGridCenters, 1);
      // Fake provider records grouped operations, not one request per cell.
      expect(source.requestCounters, {
        'altitudeBatch': 1,
        'weatherGrid': 1,
        'forestZone': 1,
      });
      expect(
        salvetat.latitude,
        closeTo(result.cells.first.center.latitude, 0.01),
      );
    },
  );

  test(
    'altitude exclue saute météo et forêt pour toutes les cellules',
    () async {
      final source = _FakeViewportSource(excludedElevation: 50);
      final result = await _service(source).calculate(bounds: bounds, zoom: 13);

      expect(result.status, MushroomViewportStatus.ready);
      expect(result.cells, isNotEmpty);
      expect(source.terrainBatchCalls, 1);
      expect(source.weatherBatchCalls, 0);
      expect(source.forestZoneCalls, 0);
      expect(
        result.cells
            .expand((cell) => cell.forecasts)
            .every(
              (forecast) =>
                  forecast.habitatReason?.contains('sous la limite basse') ??
                  false,
            ),
        isTrue,
      );
    },
  );

  test('sous le zoom minimal retourne zone trop large sans requête', () async {
    final source = _FakeViewportSource();
    final result = await _service(source).calculate(bounds: bounds, zoom: 10.9);

    expect(result.status, MushroomViewportStatus.tooWide);
    expect(result.message, contains('Zone trop large'));
    expect(source.requestCounters, isEmpty);
  });

  test('une nouvelle zone annule proprement le chargement précédent', () async {
    final source = _FakeViewportSource(delayTerrain: true);
    final service = _service(source);
    final first = service.calculate(bounds: bounds, zoom: 13);
    await source.terrainStarted.future;
    final second = service.calculate(bounds: bounds, zoom: 10);
    source.releaseTerrain.complete();

    expect((await first).status, MushroomViewportStatus.cancelled);
    expect((await second).status, MushroomViewportStatus.tooWide);
  });

  test('hors-ligne sans cache ne déclenche aucun appel réseau', () async {
    final source = _FakeViewportSource(offline: true);
    final result = await _service(source).calculate(bounds: bounds, zoom: 13);

    expect(result.status, MushroomViewportStatus.ready);
    expect(source.networkCalls, 0);
    expect(source.terrainBatchCalls, 1);
    expect(source.weatherBatchCalls, 1);
    expect(source.forestZoneCalls, 1);
    expect(
      result.cells
          .expand((cell) => cell.forecasts)
          .every((forecast) => forecast.habitat == HabitatStatus.unknown),
      isTrue,
    );
  });
}

MushroomViewportForecastService _service(_FakeViewportSource source) =>
    MushroomViewportForecastService(
      source: source,
      engine: BoletusEdulisModel(),
    );

class _FakeViewportSource implements MushroomViewportBatchSource {
  _FakeViewportSource({
    this.excludedElevation,
    this.offline = false,
    this.delayTerrain = false,
  });

  final double? excludedElevation;
  final bool offline;
  final bool delayTerrain;
  int terrainBatchCalls = 0;
  int weatherBatchCalls = 0;
  int forestZoneCalls = 0;
  int networkCalls = 0;
  int weatherGridCenters = 0;
  final terrainStarted = Completer<void>();
  final releaseTerrain = Completer<void>();

  Map<String, int> get requestCounters => {
    if (terrainBatchCalls > 0) 'altitudeBatch': terrainBatchCalls,
    if (weatherBatchCalls > 0) 'weatherGrid': weatherBatchCalls,
    if (forestZoneCalls > 0) 'forestZone': forestZoneCalls,
  };

  @override
  Future<Map<String, TerrainData>> loadTerrainBatch(
    List<LatLng> cellCenters,
    MushroomViewportCancellationToken cancellation,
  ) async {
    terrainBatchCalls++;
    if (!offline) networkCalls++;
    if (delayTerrain) {
      if (!terrainStarted.isCompleted) terrainStarted.complete();
      await releaseTerrain.future;
    }
    return {
      for (final center in cellCenters)
        mushroomViewportPointKey(center): TerrainData(
          latitude: center.latitude,
          longitude: center.longitude,
          elevation: excludedElevation ?? 600,
          slope: 5,
          aspect: 180,
          source: offline ? null : 'fake_ign_batch',
        ),
    };
  }

  @override
  Future<Map<String, MushroomViewportWeather>> loadWeatherByGrid(
    List<LatLng> uniqueModelGridCenters,
    MushroomViewportCancellationToken cancellation,
  ) async {
    weatherBatchCalls++;
    weatherGridCenters = uniqueModelGridCenters.length;
    if (!offline) networkCalls++;
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
    MushroomViewportCancellationToken cancellation,
  ) async {
    forestZoneCalls++;
    if (!offline) networkCalls++;
    return {
      for (final center in eligibleCellCenters)
        mushroomViewportPointKey(center): ForestData(
          latitude: center.latitude,
          longitude: center.longitude,
          isForest: offline ? null : true,
          source: offline ? null : 'fake_forest_batch',
        ),
    };
  }
}
