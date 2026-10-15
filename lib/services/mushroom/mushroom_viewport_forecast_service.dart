import 'dart:async';
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
import 'package:my_spots/services/mushroom/point_key.dart';

const mushroomViewportMinimumZoom = 11.0;
const mushroomViewportMaximumCells = 150;
const mushroomViewportDefaultCellsPerSide = 12;

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
    this.meshElevation,
  });

  final List<WeatherDay> history;
  final List<WeatherDay> forecast;
  final List<SoilMoistureData> soil;
  final double? meshElevation; // Altitude de la maille météo (m)
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
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  });

  Future<Map<String, MushroomViewportWeather>> loadWeatherByGrid(
    List<LatLng> uniqueModelGridCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  });

  Future<Map<String, ForestData>> loadForestForZone(
    LatLngBounds bounds,
    List<LatLng> eligibleCellCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  });
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

  /// Annule le calcul en cours.
  void cancelActive() {
    _activeCalculation?.cancel();
    _activeCalculation = null;
  }

  /// Le curseur utilise [startDate] comme J+0 ; chaque cellule contient les
  /// huit jours déjà calculés. Une nouvelle invocation annule la précédente.
  Future<MushroomViewportForecastResult> calculate({
    required LatLngBounds bounds,
    required double zoom,
    DateTime? startDate,
    void Function(String)? onStage,
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
      terrains = await _source.loadTerrainBatch(
        centers,
        cancellation,
        onStage: onStage,
      );
    } catch (_) {
      terrains = const {};
    }
    if (cancellation.isCancelled) return _cancelled();

    final eligible = <MushroomGridCell>[];
    final excluded = <String, MushroomForecast>{};
    for (final cell in cells) {
      final key = mushroomViewportPointKey(cell.center);
      final terrain = terrains[key] ?? _unknownTerrain(cell.center);
      final terrainKnown = terrain.elevation != null;
      if (!terrainKnown) {
        failedCellCount++;
      }
      final habitat = HabitatRules.evaluateTerrain(terrain);
      if (habitat != null) {
        excluded[key] = _excludedForecasts(terrain, habitat, targetStart).first;
      } else {
        eligible.add(
          MushroomGridCell(
            bounds: cell.bounds,
            forecasts: cell.forecasts,
            calculationDate: cell.calculationDate,
            terrainKnown: terrainKnown,
            weatherKnown: cell.weatherKnown,
          ),
        );
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
              .loadWeatherByGrid(
                modelCenters.values.toList(),
                cancellation,
                onStage: onStage,
              )
              .catchError((_) => const <String, MushroomViewportWeather>{});
    final forestFuture = eligible.isEmpty
        ? Future.value(const <String, ForestData>{})
        : _source
              .loadForestForZone(
                bounds,
                eligible.map((cell) => cell.center).toList(),
                cancellation,
                onStage: onStage,
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
      final gridKey = mushroomViewportPointKey(_modelGridCenter(cell.center));
      final weather = weatherByGrid[gridKey];

      final cellTerrainKnown =
          terrain.elevation != null || terrain.noElevationData;
      final cellWeatherKnown =
          weather != null &&
          (weather.history.isNotEmpty || weather.forecast.isNotEmpty);

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
          forecasts: forecasts,
          calculationDate: DateTime.now(),
          terrainKnown: cellTerrainKnown,
          weatherKnown: cellWeatherKnown,
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

    // Apply temperature correction based on altitude difference
    // Standard lapse rate: 0.0065 °C/m (6.5°C per 1000m)
    // Correction: (meshElevation - cellAltitude) * 0.0065
    final meshElevation = weather?.meshElevation;
    final cellAltitude = terrain.elevation;
    final tempCorrection = (meshElevation != null && cellAltitude != null)
        ? (meshElevation - cellAltitude) * 0.0065
        : 0.0;

    // Create corrected weather copies if correction is needed
    final correctedHistory = tempCorrection != 0
        ? _applyTempCorrection(availableWeather.history, tempCorrection)
        : availableWeather.history;
    final correctedForecast = tempCorrection != 0
        ? _applyTempCorrection(availableWeather.forecast, tempCorrection)
        : availableWeather.forecast;

    return List.generate(8, (i) {
      final forecast = _engine.calculate(
        weatherHistory: correctedHistory,
        weatherForecast: correctedForecast,
        soilMoistureLayers: availableWeather.soil,
        terrain: terrain,
        forest: forest,
        targetDate: startDate.add(Duration(days: i)),
      );
      // Fill dataSources for all cells
      return forecast.copyWith(
        dataSources: {
          'terrain': terrain.source,
          'weather': weather != null ? 'ecmwf_ifs025' : null,
          'forest': forest.source,
        },
      );
    });
  }

  /// Applique une correction de température à une liste de WeatherDay.
  /// Approximation du gradient thermique standard (0.0065 °C/m).
  List<WeatherDay> _applyTempCorrection(
    List<WeatherDay> days,
    double correction,
  ) {
    return days.map((day) {
      if (day.temperatureMin == null &&
          day.temperatureMax == null &&
          day.temperatureMean == null) {
        return day;
      }
      return WeatherDay(
        date: day.date,
        kind: day.kind,
        temperatureMin: day.temperatureMin != null
            ? day.temperatureMin! + correction
            : null,
        temperatureMax: day.temperatureMax != null
            ? day.temperatureMax! + correction
            : null,
        temperatureMean: day.temperatureMean != null
            ? day.temperatureMean! + correction
            : null,
        precipitation: day.precipitation,
        humidity: day.humidity,
        et0: day.et0,
        windSpeed: day.windSpeed,
        windGust: day.windGust,
        solarRadiation: day.solarRadiation,
      );
    }).toList();
  }

  List<MushroomForecast> _excludedForecasts(
    TerrainData terrain,
    ({HabitatStatus status, String? reason}) habitat,
    DateTime start,
  ) => List.generate(
    8,
    (i) => MushroomForecast.excluded(
      date: start.add(Duration(days: i)),
      species: _engine.species,
      habitat: habitat.status,
      habitatReason: habitat.reason,
      dataSources: {'terrain': terrain.source, 'weather': null, 'forest': null},
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
    // Use cos(latitude rounded to 0.1°) for longitude step
    final centerLatRounded = (bounds.center.latitude * 10).round() / 10.0;
    final lngMeters =
        (bounds.east - bounds.west).abs() *
        111320 *
        math.cos(centerLatRounded * math.pi / 180).abs();
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
    // Include border row and column in count
    for (final size in sizes.where((value) => value >= selected)) {
      final rows = (latMeters / size).ceil() + 1;
      final columns = (lngMeters / size).ceil() + 1;
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
      rows: (latMeters / selected).ceil() + 1,
      columns: (lngMeters / selected).ceil() + 1,
      cellSizeMeters: selected,
      cellCount:
          ((latMeters / selected).ceil() + 1) *
          ((lngMeters / selected).ceil() + 1),
    );
  }

  List<MushroomGridCell> _buildCells(
    LatLngBounds bounds,
    ({int rows, int columns, int cellSizeMeters, int cellCount}) geometry,
  ) {
    final stepLat = geometry.cellSizeMeters / 111320;
    // Use cos(latitude rounded to 0.1°) for longitude step
    final centerLatRounded = (bounds.center.latitude * 10).round() / 10.0;
    final stepLng =
        geometry.cellSizeMeters /
        (111320 * math.cos(centerLatRounded * math.pi / 180).abs());

    // Anchor grid to fixed network: floor(bound / step) * step
    final originLat = (bounds.south / stepLat).floor() * stepLat;
    final originLng = (bounds.west / stepLng).floor() * stepLng;

    final result = <MushroomGridCell>[];
    for (var row = 0; row < geometry.rows; row++) {
      for (var column = 0; column < geometry.columns; column++) {
        final south = originLat + row * stepLat;
        final west = originLng + column * stepLng;
        final north = math.min(south + stepLat, bounds.north);
        final east = math.min(west + stepLng, bounds.east);
        if (north <= south || east <= west) continue;
        result.add(
          MushroomGridCell(
            bounds: LatLngBounds(LatLng(south, west), LatLng(north, east)),
            forecasts: [MushroomForecast.mock()],
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

  static TerrainData _unknownTerrain(LatLng center) =>
      TerrainData.unknown(center.latitude, center.longitude);

  static ForestData _unknownForest(LatLng center) =>
      ForestData.unknown(center.latitude, center.longitude);
  Future<List<List<MushroomForecast>>> calculateForPoints(
    List<LatLng> points,
    void Function(String)? onStage,
    void Function(String)? onWarning,
  ) async {
    if (points.isEmpty) return [];
    if (points.length > 50) throw ArgumentError('Maximum 50 points');
    final cancellation = MushroomViewportCancellationToken();

    // Load terrain with 20s timeout
    onStage?.call('altitude');
    Map<String, TerrainData> terrains;
    try {
      terrains = await _source
          .loadTerrainBatch(points, cancellation, onStage: onStage)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      onWarning?.call('Altitude non chargée (délai)');
      terrains = {};
    } catch (_) {
      onWarning?.call('Altitude non chargée (erreur)');
      terrains = {};
    }
    if (cancellation.isCancelled) return [];

    // Determine eligible points (habitat not excluded by altitude)
    final eligible = <LatLng>[];
    for (final point in points) {
      final terrain =
          terrains[mushroomViewportPointKey(point)] ?? _unknownTerrain(point);
      final habitat = HabitatRules.evaluateTerrain(terrain);
      if (habitat == null) {
        eligible.add(point);
      }
    }
    // Compute unique model grid centers from eligible points only (weather only for non-excluded)
    final modelCenters = <String, LatLng>{};
    for (final point in eligible) {
      final center = _modelGridCenter(point);
      modelCenters.putIfAbsent(mushroomViewportPointKey(center), () => center);
    }
    // Load weather with 20s timeout
    onStage?.call('météo');
    Map<String, MushroomViewportWeather> weatherByGrid;
    try {
      final weatherFuture = modelCenters.isEmpty
          ? Future.value(const <String, MushroomViewportWeather>{})
          : _source.loadWeatherByGrid(
              modelCenters.values.toList(),
              cancellation,
              onStage: onStage,
            );
      weatherByGrid = await weatherFuture.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      onWarning?.call('Météo non chargée (délai)');
      weatherByGrid = {};
    } catch (_) {
      onWarning?.call('Météo non chargée (erreur)');
      weatherByGrid = {};
    }
    // Load forest for zone (bounds of all points) using eligible points with 30s timeout
    onStage?.call('forêt');
    final bounds = LatLngBounds.fromPoints(points);
    Map<String, ForestData> forests;
    try {
      final forestFuture = eligible.isEmpty
          ? Future.value(const <String, ForestData>{})
          : _source.loadForestForZone(
              bounds,
              eligible,
              cancellation,
              onStage: onStage,
            );
      forests = await forestFuture.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      onWarning?.call('Forêt non chargée (délai)');
      forests = {};
    } catch (_) {
      onWarning?.call('Forêt non chargée (erreur)');
      forests = {};
    }
    if (cancellation.isCancelled) return [];
    // Compute forecasts for each point
    final forecasts = <List<MushroomForecast>>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final point in points) {
      final terrainKey = mushroomViewportPointKey(point);
      final terrain = terrains[terrainKey] ?? _unknownTerrain(point);
      final gridKey = mushroomViewportPointKey(_modelGridCenter(point));
      final weather =
          weatherByGrid[gridKey] ??
          const MushroomViewportWeather(history: [], forecast: [], soil: []);
      final forest =
          forests[mushroomViewportPointKey(point)] ?? _unknownForest(point);
      final List<MushroomForecast> pointForecasts = List.generate(8, (i) {
        final targetDate = today.add(Duration(days: i));
        final forecast = _engine.calculate(
          weatherHistory: weather.history,
          weatherForecast: weather.forecast,
          soilMoistureLayers: weather.soil,
          terrain: terrain,
          forest: forest,
          targetDate: targetDate,
        );
        // Fill dataSources for each forecast
        return forecast.copyWith(
          dataSources: {
            'terrain': terrain.source,
            'weather': weatherByGrid.containsKey(gridKey)
                ? 'ecmwf_ifs025'
                : null,
            'forest': forest.source,
          },
        );
      });
      forecasts.add(pointForecasts);
    }
    return forecasts;
  }
}
