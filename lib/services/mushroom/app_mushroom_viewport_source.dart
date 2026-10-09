import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/forest_service.dart';
import 'package:my_spots/services/mushroom/ign_bd_foret_forest_service.dart';
import 'package:my_spots/services/mushroom/ign_open_elevation_terrain_service.dart';
import 'package:my_spots/services/mushroom/mushroom_viewport_forecast_service.dart';
import 'package:my_spots/services/mushroom/open_meteo_weather_service.dart';
import 'package:my_spots/services/mushroom/overpass_forest_service.dart';
import 'package:my_spots/services/mushroom/terrain_service.dart';
import 'package:my_spots/services/mushroom/weather_service.dart';

class AppMushroomViewportSource implements MushroomViewportBatchSource {
  AppMushroomViewportSource({
    TerrainService? terrain,
    WeatherService? weather,
    ForestService? forest,
  }) : terrainService = terrain ?? IgnOpenElevationTerrainService(),
       weatherService = weather ?? OpenMeteoWeatherService(),
       forestService =
           forest ??
           CompositeForestService(
             bdForet: IgnBdForetForestService(),
             overpass: OverpassForestService(),
           );

  final TerrainService terrainService;
  final WeatherService weatherService;
  final ForestService forestService;
  static const _batchConcurrency = 4;

  @override
  Future<Map<String, TerrainData>> loadTerrainBatch(
    List<LatLng> cellCenters,
    MushroomViewportCancellationToken cancellation,
  ) async {
    final result = <String, TerrainData>{};
    await _runBatched(
      items: cellCenters,
      concurrency: _batchConcurrency,
      cancellation: cancellation,
      action: (center) async {
        final key = mushroomViewportPointKey(center);
        TerrainData data;
        try {
          data = await terrainService.getTerrainData(
            lat: center.latitude,
            lng: center.longitude,
          );
        } catch (_) {
          data = TerrainData(
            latitude: center.latitude,
            longitude: center.longitude,
            elevation: null,
            noElevationData: false,
            slope: null,
            aspect: null,
            source: null,
          );
        }
        result[key] = data;
      },
    );
    return result;
  }

  @override
  Future<Map<String, MushroomViewportWeather>> loadWeatherByGrid(
    List<LatLng> uniqueModelGridCenters,
    MushroomViewportCancellationToken cancellation,
  ) async {
    final result = <String, MushroomViewportWeather>{};
    await _runBatched(
      items: uniqueModelGridCenters,
      concurrency: _batchConcurrency,
      cancellation: cancellation,
      action: (center) async {
        final key = mushroomViewportPointKey(center);
        List<WeatherDay> history;
        List<WeatherDay> forecast;
        List<SoilMoistureData> soil;
        try {
          final results = await Future.wait([
            weatherService
                .getHistoricalWeather(
                  lat: center.latitude,
                  lng: center.longitude,
                  days: 60,
                )
                .catchError((_) => <WeatherDay>[]),
            weatherService
                .getWeatherForecast(
                  lat: center.latitude,
                  lng: center.longitude,
                  days: 7,
                )
                .catchError((_) => <WeatherDay>[]),
            weatherService
                .getSoilMoisture(lat: center.latitude, lng: center.longitude)
                .catchError((_) => <SoilMoistureData>[]),
          ]);
          history = results[0] as List<WeatherDay>;
          forecast = results[1] as List<WeatherDay>;
          soil = results[2] as List<SoilMoistureData>;
        } catch (_) {
          history = const [];
          forecast = const [];
          soil = const [];
        }
        result[key] = MushroomViewportWeather(
          history: history,
          forecast: forecast,
          soil: soil,
        );
      },
    );
    return result;
  }

  @override
  Future<Map<String, ForestData>> loadForestForZone(
    LatLngBounds bounds,
    List<LatLng> eligibleCellCenters,
    MushroomViewportCancellationToken cancellation,
  ) async {
    final result = <String, ForestData>{};
    await _runBatched(
      items: eligibleCellCenters,
      concurrency: _batchConcurrency,
      cancellation: cancellation,
      action: (center) async {
        final key = mushroomViewportPointKey(center);
        ForestData data;
        try {
          data = await forestService.getForestData(
            lat: center.latitude,
            lng: center.longitude,
          );
        } catch (_) {
          data = ForestData(
            latitude: center.latitude,
            longitude: center.longitude,
            isForest: null,
            forestType: null,
            canopyClass: null,
            treeDensity: null,
            canopyCover: null,
            source: null,
          );
        }
        result[key] = data;
      },
    );
    return result;
  }

  Future<void> _runBatched<T>({
    required List<T> items,
    required int concurrency,
    required MushroomViewportCancellationToken cancellation,
    required Future<void> Function(T item) action,
  }) async {
    if (items.isEmpty) return;
    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < items.length) {
        if (cancellation.isCancelled) return;
        if (AppSettings.offlineModeEnabled) return;
        final i = nextIndex++;
        try {
          await action(items[i]);
        } catch (_) {}
      }
    }

    final workers = List.generate(
      AppSettings.offlineModeEnabled ? 1 : concurrency,
      (_) => worker(),
    );
    await Future.wait(workers);
  }
}
