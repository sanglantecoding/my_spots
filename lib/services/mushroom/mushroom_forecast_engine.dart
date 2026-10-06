import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';

/// Interface pour les moteurs de prévision par espèce de champignon.
abstract class MushroomForecastEngine {
  /// Espèce gérée par ce moteur.
  MushroomSpecies get species;

  /// Calcule l'indice de conditions favorables pour une position et un jour.
  ///
  /// [weatherHistory] : Données météo historiques (60 derniers jours)
  /// [weatherForecast] : Prévisions météo (J+0 à J+7)
  /// [soilMoistureLayers] : Données d'humidité du sol pour différentes profondeurs
  /// [terrain] : Données de terrain (altitude, pente, exposition)
  /// [forest] : Données de forêt (type, densité)
  /// [targetDate] : Date pour laquelle calculer l'indice
  MushroomForecast calculate({
    required List<WeatherDay> weatherHistory,
    required List<WeatherDay> weatherForecast,
    required List<SoilMoistureData> soilMoistureLayers,
    required TerrainData terrain,
    required ForestData forest,
    required DateTime targetDate,
  });
}
