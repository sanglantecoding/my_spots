import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/services/mushroom/boletus_edulis_model.dart';
import 'package:my_spots/services/mushroom/forest_service.dart';
import 'package:my_spots/services/mushroom/ign_open_elevation_terrain_service.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_service.dart';
import 'package:my_spots/services/mushroom/open_meteo_weather_service.dart';
import 'package:my_spots/services/mushroom/overpass_forest_service.dart';

/// Point d'accès unique aux prévisions de champignons.
class MushroomForecastProvider {
  MushroomForecastProvider._();

  static final Map<String, MushroomForecast> _forecastCache = {};
  static final MushroomForecastService _service = _createService();

  static String _cacheKey(double latitude, double longitude, DateTime date) =>
      '${latitude.toStringAsPrecision(12)}:${longitude.toStringAsPrecision(12)}:'
      '${date.year}-${date.month}-${date.day}';

  static MushroomForecastService _createService() {
    final service = MushroomForecastService(
      weatherService: OpenMeteoWeatherService(),
      terrainService: IgnOpenElevationTerrainService(),
      forestService: _ForestServiceWithFallback(
        OverpassForestService(),
        NeutralForestService(),
      ),
    );
    service.registerEngine(BoletusEdulisModel());
    return service;
  }

  static Future<List<MushroomForecast>> forecastBoletusRange({
    required double latitude,
    required double longitude,
    required DateTime startDate,
  }) {
    if (AppSettings.offlineModeEnabled) {
      throw StateError('Prévisions champignons indisponibles hors-ligne.');
    }
    return _service
        .calculateForecastRange(
          lat: latitude,
          lng: longitude,
          species: MushroomSpecies.boletusEdulis,
          startDate: startDate,
          days: 7,
        )
        .then((forecasts) {
          for (final forecast in forecasts) {
            _forecastCache[_cacheKey(latitude, longitude, forecast.date)] =
                forecast;
          }
          return forecasts;
        });
  }

  /// Réutilise d'abord une prévision déjà affichée, puis calcule en ligne.
  /// En mode hors-ligne, l'absence de cache renvoie null sans appel réseau.
  static Future<MushroomForecast?> forecastForObservation({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async {
    final key = _cacheKey(latitude, longitude, date);
    final cached = _forecastCache[key];
    if (cached != null) return cached;
    if (AppSettings.offlineModeEnabled) return null;

    final forecast = await _service.calculateForecast(
      lat: latitude,
      lng: longitude,
      species: MushroomSpecies.boletusEdulis,
      targetDate: date,
    );
    _forecastCache[key] = forecast;
    return forecast;
  }
}

class _ForestServiceWithFallback implements ForestService {
  const _ForestServiceWithFallback(this.primary, this.fallback);

  final ForestService primary;
  final ForestService fallback;

  @override
  Future<ForestData> getForestData({
    required double lat,
    required double lng,
  }) async {
    try {
      return await primary.getForestData(lat: lat, lng: lng);
    } catch (_) {
      return fallback.getForestData(lat: lat, lng: lng);
    }
  }
}
