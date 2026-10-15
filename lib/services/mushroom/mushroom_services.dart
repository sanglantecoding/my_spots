import 'package:flutter/foundation.dart';
import 'package:my_spots/services/mushroom/ign_bd_foret_forest_service.dart';
import 'package:my_spots/services/mushroom/ign_open_elevation_terrain_service.dart';
import 'package:my_spots/services/mushroom/open_meteo_weather_service.dart';
import 'package:my_spots/services/mushroom/overpass_forest_service.dart';
import 'package:my_spots/services/mushroom/shared_http_client.dart';

/// Singleton paresseux pour les services partagés du module champignons.
///
/// Possède une instance unique de chaque service réseau/cache pour éviter
/// les connexions multiples et permettre un nettoyage centralisé.
class MushroomServices {
  MushroomServices._internal();

  static MushroomServices? _instance;

  /// Instance singleton paresseuse.
  static MushroomServices get instance {
    _instance ??= MushroomServices._internal();
    return _instance!;
  }

  /// Client HTTP partagé par tous les services.
  final SharedHttpClient _sharedClient = SharedHttpClient();

  /// Service météo Open-Meteo.
  late final OpenMeteoWeatherService weatherService = OpenMeteoWeatherService(
    client: _sharedClient.client,
  );

  /// Service d'altitude IGN Open Elevation.
  late final IgnOpenElevationTerrainService terrainService =
      IgnOpenElevationTerrainService(client: _sharedClient.client);

  /// Service forêt IGN BD Forêt.
  late final IgnBdForetForestService ignBdForetService =
      IgnBdForetForestService(client: _sharedClient.client);

  /// Service forêt Overpass (OSM).
  late final OverpassForestService overpassForestService =
      OverpassForestService(client: _sharedClient.client);

  /// Libère les ressources (ferme le client HTTP).
  ///
  /// Doit être appelé à la fermeture de l'application ou lorsque les services
  /// ne sont plus nécessaires.
  void dispose() {
    _sharedClient.dispose();
  }

  /// Réinitialise l'instance singleton (tests uniquement).
  @visibleForTesting
  static void resetForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}
