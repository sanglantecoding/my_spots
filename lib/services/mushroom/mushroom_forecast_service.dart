import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
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

    // Récupérer les données météo et forêt en parallèle
    final results = await Future.wait([
      _weatherService.getHistoricalWeather(lat: lat, lng: lng, days: 60),
      _weatherService.getWeatherForecast(lat: lat, lng: lng, days: 7),
      _weatherService.getSoilMoisture(lat: lat, lng: lng),
      _forestService.getForestData(lat: lat, lng: lng),
    ]);

    final weatherHistory = results[0] as List<WeatherDay>;
    final weatherForecast = results[1] as List<WeatherDay>;
    final soilMoistureLayers = results[2] as List<SoilMoistureData>;
    final forest = results[3] as ForestData;

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

    // Récupérer les autres données une seule fois en parallèle.
    final results = await Future.wait([
      _weatherService.getHistoricalWeather(lat: lat, lng: lng, days: 60),
      _weatherService.getWeatherForecast(lat: lat, lng: lng, days: days),
      _weatherService.getSoilMoisture(lat: lat, lng: lng),
      _forestService.getForestData(lat: lat, lng: lng),
    ]);

    final weatherHistory = results[0] as List<WeatherDay>;
    final weatherForecast = results[1] as List<WeatherDay>;
    final soilMoistureLayers = results[2] as List<SoilMoistureData>;
    final forest = results[3] as ForestData;

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
    return MushroomForecast.excluded(
      date: targetDate,
      species: species,
      habitat: exclusion.status,
      habitatReason: exclusion.reason,
    );
  }

  MushroomForecast _withWeatherSource(MushroomForecast forecast) =>
      forecast.copyWith(
        dataSources: {
          ...forecast.dataSources,
          'weather': _weatherService.runtimeType.toString(),
        },
      );
}
