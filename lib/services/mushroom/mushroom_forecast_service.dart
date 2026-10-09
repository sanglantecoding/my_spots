import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_grid_cell.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/services/mushroom/forest_service.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_engine.dart';
import 'package:my_spots/services/mushroom/terrain_service.dart';
import 'package:my_spots/services/mushroom/weather_service.dart';
import 'package:my_spots/services/mushroom/habitat_rules.dart';

/// Service principal pour le calcul de prévisions champignon.
class MushroomForecastService {
  MushroomForecastService({
    required WeatherService weatherService,
    required TerrainService terrainService,
    required ForestService forestService,
  }) : _weatherService = weatherService,
       _terrainService = terrainService,
       _forestService = forestService;

  final WeatherService _weatherService;
  final TerrainService _terrainService;
  final ForestService _forestService;

  /// Registre des moteurs de prévision par espèce.
  final Map<MushroomSpecies, MushroomForecastEngine> _engines = {};

  /// Enregistre un moteur de prévision pour une espèce.
  void registerEngine(MushroomForecastEngine engine) {
    _engines[engine.species] = engine;
  }

  /// Récupère le moteur pour une espèce, ou null si non enregistré.
  MushroomForecastEngine? getEngine(MushroomSpecies species) {
    return _engines[species];
  }

  /// Calcule la prévision pour une position, une espèce et un jour donné.
  Future<MushroomForecast> calculateForecast({
    required double lat,
    required double lng,
    required MushroomSpecies species,
    required DateTime targetDate,
  }) async {
    final engine = _engines[species];
    if (engine == null) {
      throw ArgumentError('Aucun moteur enregistré pour $species');
    }

    final terrain = await _terrainService.getTerrainData(lat: lat, lng: lng);
    final excludedForecast = _excludedTerrainForecast(
      terrain,
      species: species,
      targetDate: targetDate,
    );
    if (excludedForecast != null) return excludedForecast;

    // Récupérer les données météo
    final weatherHistory = await _weatherService.getHistoricalWeather(
      lat: lat,
      lng: lng,
      days: 60,
    );
    final weatherForecast = await _weatherService.getWeatherForecast(
      lat: lat,
      lng: lng,
      days: 7,
    );
    final soilMoistureLayers = await _weatherService.getSoilMoisture(
      lat: lat,
      lng: lng,
    );

    // Récupérer les données de forêt
    final forest = await _forestService.getForestData(lat: lat, lng: lng);

    // Calculer la prévision via le moteur
    final forecast = engine.calculate(
      weatherHistory: weatherHistory,
      weatherForecast: weatherForecast,
      soilMoistureLayers: soilMoistureLayers,
      terrain: terrain,
      forest: forest,
      targetDate: targetDate,
    );
    return _withWeatherSource(forecast);
  }

  /// Calcule les prévisions pour J+0 à J+7 pour une position et une espèce.
  ///
  /// Récupère les données météo/terrain/forêt une seule fois, puis calcule
  /// les prévisions pour chaque jour pour éviter les appels réseau redondants.
  Future<List<MushroomForecast>> calculateForecastRange({
    required double lat,
    required double lng,
    required MushroomSpecies species,
    required DateTime startDate,
    int days = 7,
  }) async {
    final engine = _engines[species];
    if (engine == null) {
      throw ArgumentError('Aucun moteur enregistré pour $species');
    }

    // Le terrain est évalué en premier : une altitude connue hors habitat
    // évite les appels réseau météo, sol et forêt.
    final terrain = await _terrainService.getTerrainData(lat: lat, lng: lng);
    final firstExcludedForecast = _excludedTerrainForecast(
      terrain,
      species: species,
      targetDate: startDate,
    );
    if (firstExcludedForecast != null) {
      return List.generate(days + 1, (i) {
        return _excludedTerrainForecast(
          terrain,
          species: species,
          targetDate: startDate.add(Duration(days: i)),
        )!;
      });
    }

    // Récupérer les autres données une seule fois.
    final weatherHistory = await _weatherService.getHistoricalWeather(
      lat: lat,
      lng: lng,
      days: 60,
    );
    final weatherForecast = await _weatherService.getWeatherForecast(
      lat: lat,
      lng: lng,
      days: days,
    );
    final soilMoistureLayers = await _weatherService.getSoilMoisture(
      lat: lat,
      lng: lng,
    );
    final forest = await _forestService.getForestData(lat: lat, lng: lng);

    // Calculer les prévisions pour chaque jour avec les mêmes données
    // Convention : days = index du dernier jour (J+days), J+0 inclus → days+1 itérations
    final forecasts = <MushroomForecast>[];
    for (int i = 0; i <= days; i++) {
      final targetDate = startDate.add(Duration(days: i));
      final forecast = engine.calculate(
        weatherHistory: weatherHistory,
        weatherForecast: weatherForecast,
        soilMoistureLayers: soilMoistureLayers,
        terrain: terrain,
        forest: forest,
        targetDate: targetDate,
      );
      forecasts.add(_withWeatherSource(forecast));
    }
    return forecasts;
  }

  MushroomForecast? _excludedTerrainForecast(
    TerrainData terrain, {
    required MushroomSpecies species,
    required DateTime targetDate,
  }) {
    final exclusion = HabitatRules.evaluateTerrain(terrain);
    if (exclusion == null) return null;
    return MushroomForecast(
      date: targetDate,
      species: species,
      index: 0,
      confidence: 1.0,
      habitat: exclusion.status,
      habitatReason: exclusion.reason,
      factors: ForecastFactors(
        waterFactor: null,
        temperatureFactor: null,
        dryingFactor: 0,
        terrainFactor: null,
        forestFactor: null,
        shockFactor: null,
      ),
    );
  }

  MushroomForecast _withWeatherSource(MushroomForecast forecast) =>
      MushroomForecast(
        date: forecast.date,
        species: forecast.species,
        index: forecast.index,
        confidence: forecast.confidence,
        factors: forecast.factors,
        habitat: forecast.habitat,
        habitatReason: forecast.habitatReason,
        wetStreak: forecast.wetStreak,
        dryBefore: forecast.dryBefore,
        soilMoistureAvailable: forecast.soilMoistureAvailable,
        soilMoisture0To7Percent: forecast.soilMoisture0To7Percent,
        soilMoisture7To28Percent: forecast.soilMoisture7To28Percent,
        soilMoisture7To28Min60dPercent: forecast.soilMoisture7To28Min60dPercent,
        soilMoisture7To28Median60dPercent:
            forecast.soilMoisture7To28Median60dPercent,
        soilMoisture7To28Max60dPercent: forecast.soilMoisture7To28Max60dPercent,
        soilMoisture7To28Percentile60d: forecast.soilMoisture7To28Percentile60d,
        soilTemperature0To7C: forecast.soilTemperature0To7C,
        hydricGate: forecast.hydricGate,
        shockDate: forecast.shockDate,
        shockRainMm: forecast.shockRainMm,
        shockTempDropC: forecast.shockTempDropC,
        temperatureSource: forecast.temperatureSource,
        dataSources: {
          ...forecast.dataSources,
          'weather': _weatherService.runtimeType.toString(),
        },
      );

  /// Calcule une grille de prévisions pour une zone géographique.
  ///
  /// [bounds] : Zone géographique
  /// [species] : Espèce de champignon
  /// [targetDate] : Date cible
  /// [gridSizeKm] : Taille des cellules de grille en km
  ///
  /// NOTE : Cette méthode appelle calculateForecast pour chaque cellule.
  /// Pour éviter les appels réseau par cellule, les implémentations des services
  /// (WeatherService, TerrainService, ForestService) DOIVENT implémenter un
  /// cache interne. Alternativement, utiliser une version batch avec données
  /// pré-chargées dans une future évolution.
  Future<List<MushroomGridCell>> calculateGridForecast({
    required LatLngBounds bounds,
    required MushroomSpecies species,
    required DateTime targetDate,
    double gridSizeKm = 1.0,
  }) async {
    final cells = <MushroomGridCell>[];

    // Calculer le nombre de cellules en latitude et longitude
    final latStep = gridSizeKm / 111.0; // ~1° lat = 111 km
    final lngStep = gridSizeKm / (111.0 * _cosLat(bounds.center.latitude));

    final latSteps = ((bounds.north - bounds.south) / latStep).ceil();
    final lngSteps = ((bounds.east - bounds.west) / lngStep).ceil();

    // Itérer sur la grille
    for (int i = 0; i < latSteps; i++) {
      for (int j = 0; j < lngSteps; j++) {
        final cellSouth = bounds.south + i * latStep;
        final cellNorth = (cellSouth + latStep).clamp(0.0, bounds.north);
        final cellWest = bounds.west + j * lngStep;
        final cellEast = (cellWest + lngStep).clamp(0.0, bounds.east);

        final cellBounds = LatLngBounds(
          LatLng(cellSouth, cellWest),
          LatLng(cellNorth, cellEast),
        );

        final cellCenter = cellBounds.center;
        final forecast = await calculateForecast(
          lat: cellCenter.latitude,
          lng: cellCenter.longitude,
          species: species,
          targetDate: targetDate,
        );

        cells.add(
          MushroomGridCell(
            bounds: cellBounds,
            forecast: forecast,
            calculationDate: DateTime.now(),
          ),
        );
      }
    }

    return cells;
  }

  double _cosLat(double lat) {
    return math.cos(lat * math.pi / 180); // Conversion radians
  }
}
