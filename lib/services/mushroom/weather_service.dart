import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';

/// Interface pour le service météo.
///
/// Indépendant du fournisseur de données (Open-Meteo, Météo-France, etc.).
abstract class WeatherService {
  /// Récupère l'historique météo pour une position.
  ///
  /// [lat] : Latitude
  /// [lng] : Longitude
  /// [days] : Nombre de jours d'historique (typiquement 60)
  ///
  /// Retourne une liste chronologique (du plus ancien au plus récent).
  Future<List<WeatherDay>> getHistoricalWeather({
    required double lat,
    required double lng,
    required int days,
  });

  /// Récupère les prévisions météo pour une position.
  ///
  /// [lat] : Latitude
  /// [lng] : Longitude
  /// [days] : Nombre de jours de prévision (typiquement 7)
  ///
  /// Retourne une liste chronologique (J+0 à J+N).
  Future<List<WeatherDay>> getWeatherForecast({
    required double lat,
    required double lng,
    required int days,
  });

  /// Récupère les données d'humidité du sol pour une position.
  ///
  /// [lat] : Latitude
  /// [lng] : Longitude
  ///
  /// Retourne une liste de données d'humidité pour différentes profondeurs.
  /// Le fournisseur peut retourner une ou plusieurs couches (ex: 0-7cm, 7-28cm).
  Future<List<SoilMoistureData>> getSoilMoisture({
    required double lat,
    required double lng,
  });
}
