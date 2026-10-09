import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_grid_cell.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/habitat_rules.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_engine.dart';

const mushroomViewportMinimumZoom = 11.0;
const mushroomViewportMaximumCells = 150;
const mushroomViewportDefaultCellsPerSide = 12;
const mushroomViewportAltitudePointLimit = 5000;
const mushroomViewportMaximumParallelRequests = 4;

String mushroomViewportPointKey(LatLng point) =>
    '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';

enum MushroomViewportStatus { ready, tooWide, cancelled }

class MushroomViewportForecastResult {
  const MushroomViewportForecastResult({
    required this.status,
    this.cells = const [],
    this.cellSizeMeters,
    this.message,
    this.failedCellCount = 0,
  });

  final MushroomViewportStatus status;
  final List<MushroomGridCell> cells;
  final int? cellSizeMeters;
  final String? message;
  final int failedCellCount;
}

/// Token de validité : le batch source peut vérifier l'annulation entre lots.
class MushroomViewportCancellationToken {
  bool isCancelled = false;
  void cancel() => isCancelled = true;
}

/// Données météo et sol d'une maille ECMWF partagées par ses cellules.
class MushroomViewportWeather {
  const MushroomViewportWeather({
    required this.history,
    required this.forecast,
    required this.soil,
  });

  final List<WeatherDay> history;
  final List<WeatherDay> forecast;
  final List<SoilMoistureData> soil;
}

/// Contrat batch pour les fournisseurs réseau/cache du calcul viewport.
///
/// Implémentations : altitude par patchs 3x3 groupés (<=5000 points/requête,
/// <=5 requêtes/s), une réponse météo par maille ECMWF unique, et une seule
/// interrogation BD Forêt par bbox accompagnée des tuiles OSM nécessaires.
/// En mode hors-ligne, chaque méthode doit consulter uniquement ses caches.
abstract interface class MushroomViewportBatchSource {
  Future<Map<String, TerrainData>> loadTerrainBatch(
    List<LatLng> cellCenters,
    MushroomViewportCancellationToken cancellation,
  );

  Future<Map<String, MushroomViewportWeather>> loadWeatherByGrid(
    List<LatLng> uniqueModelGridCenters,
    MushroomViewportCancellationToken cancellation,
  );

  Future<Map<String, ForestData>> loadForestForZone(
    LatLngBounds bounds,
    List<LatLng> eligibleCellCenters,
    MushroomViewportCancellationToken cancellation,
  );
}

/// Calcule les prévisions locales d'un viewport après chargement batch.
class MushroomViewportForecastService {
  MushroomViewportForecastService({
    required MushroomViewportBatchSource source,
    required MushroomForecastEngine engine,
    this.minimumZoom = mushroomViewportMinimumZoom,
    this.maximumCells = mushroomViewportMaximumCells,
  }) : _source = source,
       _engine = engine;

  final MushroomViewportBatchSource _source;
  final MushroomForecastEngine _engine;
  final double minimumZoom;
  final int maximumCells;
  MushroomViewportCancellationToken? _activeCalculation;

  /// Le curseur utilise [startDate] comme J+0 ; chaque cellule contient les
  /// huit jours déjà calculés. Une nouvelle invocation annule la précédente.
  Future<MushroomViewportForecastResult> calculate({
    required LatLngBounds bounds,
    required double zoom,
    DateTime? startDate,
  }) async {
    _activeCalculation?.cancel();
    final cancellation = MushroomViewportCancellationToken();
    _activeCalculation = cancellation;
    if (zoom < minimumZoom) {
      return const MushroomViewportForecastResult(
        status: MushroomViewportStatus.tooWide,
        message: 'Zone trop large : zoomez pour calculer la prévision.',
      );
    }

    final geometry = _gridGeometry(bounds);
    if (geometry == null || geometry.cellCount > maximumCells) {
      return const MushroomViewportForecastResult(
        status: MushroomViewportStatus.tooWide,
        message: 'Zone trop large : réduisez la zone visible.',
      );
    }
    final cells = _buildCells(bounds, geometry);
    if (cells.isEmpty) {
      return const MushroomViewportForecastResult(
        status: MushroomViewportStatus.tooWide,
        message: 'Zone trop large ou sans cellules calculables.',
      );
    }

    final targetStart = _day(startDate ?? DateTime.now());
    final centers = cells.map((cell) => cell.bounds.center).toList();
    Map<String, TerrainData> terrains;
    var failedCellCount = 0;
    try {
      terrains = await _source.loadTerrainBatch(centers, cancellation);
    } catch (_) {
      terrains = const {};
    }
    if (cancellation.isCancelled) return _cancelled();

    final eligible = <MushroomGridCell>[];
    final excluded = <String, MushroomForecast>{};
    for (final cell in cells) {
      final key = mushroomViewportPointKey(cell.center);
      final terrain = terrains[key] ?? _unknownTerrain(cell.center);
      if (terrain.elevation == null) {
        failedCellCount++;
      }
      final habitat = HabitatRules.evaluateTerrain(terrain);
      if (habitat != null) {
        excluded[key] = _excludedForecasts(terrain, habitat, targetStart).first;
      } else {
        eligible.add(cell);
      }
    }

    final modelCenters = <String, LatLng>{};
    for (final cell in eligible) {
      final center = _modelGridCenter(cell.center);
      modelCenters.putIfAbsent(mushroomViewportPointKey(center), () => center);
    }

    final weatherFuture = modelCenters.isEmpty
        ? Future.value(const <String, MushroomViewportWeather>{})
        : _source
              .loadWeatherByGrid(modelCenters.values.toList(), cancellation)
              .catchError((_) => const <String, MushroomViewportWeather>{});
    final forestFuture = eligible.isEmpty
        ? Future.value(const <String, ForestData>{})
        : _source
              .loadForestForZone(
                bounds,
                eligible.map((cell) => cell.center).toList(),
                cancellation,
              )
              .catchError((_) => const <String, ForestData>{});
    final batches = await Future.wait([weatherFuture, forestFuture]);
    final weatherByGrid = batches[0] as Map<String, MushroomViewportWeather>;
    final forests = batches[1] as Map<String, ForestData>;
    if (cancellation.isCancelled) return _cancelled();

    final results = <MushroomGridCell>[];
    for (final cell in cells) {
      final key = mushroomViewportPointKey(cell.center);
      final terrain = terrains[key] ?? _unknownTerrain(cell.center);
      final excludedForecast = excluded[key];
      final forecasts = excludedForecast == null
          ? _calculateCellForecasts(
              cell: cell,
              terrain: terrain,
              weatherByGrid: weatherByGrid,
              forest: forests[key] ?? _unknownForest(cell.center),
              startDate: targetStart,
            )
          : _excludedForecasts(terrain, (
              status: excludedForecast.habitat,
              reason: excludedForecast.habitatReason,
            ), targetStart);
      results.add(
        MushroomGridCell(
          bounds: cell.bounds,
          forecast: forecasts.first,
          forecasts: forecasts,
          calculationDate: DateTime.now(),
        ),
      );
    }
    if (cancellation.isCancelled) return _cancelled();
    return MushroomViewportForecastResult(
      status: MushroomViewportStatus.ready,
      cells: results,
      cellSizeMeters: geometry.cellSizeMeters,
      failedCellCount: failedCellCount,
    );
  }

  List<MushroomForecast> _calculateCellForecasts({
    required MushroomGridCell cell,
    required TerrainData terrain,
    required Map<String, MushroomViewportWeather> weatherByGrid,
    required ForestData forest,
    required DateTime startDate,
  }) {
    final gridKey = mushroomViewportPointKey(_modelGridCenter(cell.center));
    final weather = weatherByGrid[gridKey];
    final availableWeather =
        weather ??
        const MushroomViewportWeather(history: [], forecast: [], soil: []);
    return List.generate(8, (i) {
      return _engine.calculate(
        weatherHistory: availableWeather.history,
        weatherForecast: availableWeather.forecast,
        soilMoistureLayers: availableWeather.soil,
        terrain: terrain,
        forest: forest,
        targetDate: startDate.add(Duration(days: i)),
      );
    });
  }

  List<MushroomForecast> _excludedForecasts(
    TerrainData terrain,
    ({HabitatStatus status, String? reason}) habitat,
    DateTime start,
  ) => List.generate(
    8,
    (i) => MushroomForecast(
      date: start.add(Duration(days: i)),
      species: _engine.species,
      index: 0,
      confidence: 1,
      habitat: habitat.status,
      habitatReason: habitat.reason,
      factors: ForecastFactors(
        waterFactor: null,
        temperatureFactor: null,
        dryingFactor: 0,
        terrainFactor: null,
        forestFactor: null,
        shockFactor: null,
      ),
      dataSources: {'terrain': terrain.source},
    ),
  );

  MushroomViewportForecastResult _cancelled() =>
      const MushroomViewportForecastResult(
        status: MushroomViewportStatus.cancelled,
        message: 'Calcul annulé car la zone visible a changé.',
      );

  static ({int rows, int columns, int cellSizeMeters, int cellCount})?
  _gridGeometry(LatLngBounds bounds) {
    final latMeters = (bounds.north - bounds.south).abs() * 111320;
    final lngMeters =
        (bounds.east - bounds.west).abs() *
        111320 *
        math.cos(bounds.center.latitude * math.pi / 180).abs();
    if (latMeters <= 0 || lngMeters <= 0) return null;
    final target = math.max(latMeters, lngMeters) / 20;
    const sizes = [100, 200, 500, 1000];
    var selected = sizes.first;
    var bestDistance = double.infinity;
    for (final size in sizes) {
      final distance = (size - target).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        selected = size;
      }
    }
    for (final size in sizes.where((value) => value >= selected)) {
      final rows = (latMeters / size).ceil();
      final columns = (lngMeters / size).ceil();
      if (rows * columns <= mushroomViewportMaximumCells) {
        return (
          rows: rows,
          columns: columns,
          cellSizeMeters: size,
          cellCount: rows * columns,
        );
      }
    }
    return (
      rows: (latMeters / selected).ceil(),
      columns: (lngMeters / selected).ceil(),
      cellSizeMeters: selected,
      cellCount:
          ((latMeters / selected).ceil()) * ((lngMeters / selected).ceil()),
    );
  }

  List<MushroomGridCell> _buildCells(
    LatLngBounds bounds,
    ({int rows, int columns, int cellSizeMeters, int cellCount}) geometry,
  ) {
    final stepLat = geometry.cellSizeMeters / 111320;
    final stepLng =
        geometry.cellSizeMeters /
        (111320 * math.cos(bounds.center.latitude * math.pi / 180).abs());
    final result = <MushroomGridCell>[];
    for (var row = 0; row < geometry.rows; row++) {
      for (var column = 0; column < geometry.columns; column++) {
        final south = bounds.south + row * stepLat;
        final west = bounds.west + column * stepLng;
        final north = math.min(south + stepLat, bounds.north);
        final east = math.min(west + stepLng, bounds.east);
        if (north <= south || east <= west) continue;
        result.add(
          MushroomGridCell(
            bounds: LatLngBounds(LatLng(south, west), LatLng(north, east)),
            forecast: MushroomForecast.mock(),
            calculationDate: DateTime.now(),
          ),
        );
      }
    }
    return result;
  }

  static LatLng _modelGridCenter(LatLng center) => LatLng(
    (center.latitude / 0.25).round() * 0.25,
    (center.longitude / 0.25).round() * 0.25,
  );

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static TerrainData _unknownTerrain(LatLng center) => TerrainData(
    latitude: center.latitude,
    longitude: center.longitude,
    elevation: null,
    noElevationData: false,
    slope: null,
    aspect: null,
    source: null,
  );

  static ForestData _unknownForest(LatLng center) => ForestData(
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
