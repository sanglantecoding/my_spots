import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/satellite_service.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';

class AppBootstrap {
  AppBootstrap._();

  static Future<void> initialize() async {
    // Charger les paramètres de l'application
    await AppSettings.loadSettings();

    // Charger les waypoints depuis le stockage
    await WaypointStore.load();

    // Initialiser le service de cache des tuiles de carte
    await MapTileCacheService.initialise();

    // Initialiser le service des satellites pour synchronisation immédiate
    await SatelliteService.initialize();
  }
}
