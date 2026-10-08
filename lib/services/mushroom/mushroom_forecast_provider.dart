import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/services/mushroom/boletus_edulis_model.dart';
import 'package:my_spots/services/mushroom/forest_service.dart';
import 'package:my_spots/services/mushroom/ign_open_elevation_terrain_service.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_service.dart';
import 'package:my_spots/services/mushroom/open_meteo_weather_service.dart';

/// Point d'accès unique aux prévisions de champignons.
class MushroomForecastProvider {
  MushroomForecastProvider._();

  static final MushroomForecastService _service = _createService();

  static MushroomForecastService _createService() {
    final service = MushroomForecastService(
      weatherService: OpenMeteoWeatherService(),
      terrainService: IgnOpenElevationTerrainService(),
      forestService: NeutralForestService(),
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
    return _service.calculateForecastRange(
      lat: latitude,
      lng: longitude,
      species: MushroomSpecies.boletusEdulis,
      startDate: startDate,
      days: 7,
    );
  }
}
