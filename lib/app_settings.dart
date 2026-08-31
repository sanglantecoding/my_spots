import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_spots/controllers/gps_controller.dart';
import 'package:my_spots/models/fishing_port.dart';
import 'package:my_spots/services/port_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

/// Clé API Thunderforest — chargée depuis le fichier .env via flutter_dotenv.
/// NE JAMAIS coder en dur cette clé dans le code source !
/// Voir main.dart pour le chargement de dotenv avant l'initialisation de l'app.
///
/// ⚠️ NOTE DE SÉCURITÉ :
/// La clé actuelle est valide et fonctionnelle.
/// Comme toute clé utilisée côté client, elle peut être extraite du binaire :
/// la sécurité repose sur la rotation régulière de la clé, pas sur son secret.
/// En cas de compromission avérée, révoquer l'ancienne clé et en générer
/// une nouvelle sur https://www.thunderforest.com/ → compte → API keys,
/// puis la définir dans le fichier .env (copié depuis .env.example).
final String thunderforestApiKey = String.fromEnvironment(
  'THUNDERFOREST_API_KEY',
  defaultValue: dotenv.env['THUNDERFOREST_API_KEY'] ?? '',
);

enum SpeedUnit { knots, kmh }

enum DistanceUnit { metric, nautical }

enum MapType { standard, relief, hiking, marine }

class AppSettings {
  static SpeedUnit speedUnit = SpeedUnit.kmh; // km/h par défaut
  static String? selectedPortKey;
  static bool waypointsVisible = true;
  static bool showWaypointNamesOnMap = true;
  static bool showWaypointDateOnMap = false;
  static DistanceUnit distanceUnit = DistanceUnit.metric;
  static double waypointLabelFontSize = 15.0; // 15 par défaut
  static MapType mapType = MapType.standard;
  static bool showSpeedOnMap = false; // false par défaut

  // Alarme de proximité waypoint
  static bool proximityAlarmEnabled = false;
  static double proximityDistanceX = 100.0; // Zone X (m) — bip lent
  static double proximityDistanceY = 20.0; // Zone Y (m) — bip-bip
  static double proximityDistanceZ = 5.0; // Zone Z (m) — bip continu

  // Filtre d'affichage par catégorie
  static bool showFishingWaypointsOnMap = true;
  static bool showMushroomWaypointsOnMap = true;
  static bool showOtherWaypointsOnMap = true; // Ajout de la catégorie Autre
  static bool energySavingMode = false;
  static List<FishingPort> favoritePorts = [];

  /// Keys of favorite ports (subset of [favoritePorts]).
  static Set<String> get favoritePortKeys =>
      favoritePorts.map((p) => p.key).toSet();

  /// Add a port to favorites by key.
  static Future<void> addFavorite(String portKey) async {
    final port = PortService.instance.getPortByKey(portKey);
    if (port == null) return;
    if (!favoritePorts.any((p) => p.key == portKey)) {
      await saveFavoritePorts([...favoritePorts, port]);
    }
  }

  /// Remove a port from favorites by key.
  static Future<void> removeFavorite(String portKey) async {
    final newList = favoritePorts.where((p) => p.key != portKey).toList();
    await saveFavoritePorts(newList);
  }

  // Superposition relief sous-marin / LiDAR (contrôles sur la carte)
  static bool bathymetryOverlayEnabled = false;
  static double bathymetryOverlayOpacity = 0.7;

  /// Alias pour [bathymetryOverlayEnabled].
  static bool get showBathymetry => bathymetryOverlayEnabled;

  static set showBathymetry(bool value) => bathymetryOverlayEnabled = value;

  /// Alias pour [bathymetryOverlayOpacity].
  static double get bathymetryOpacity => bathymetryOverlayOpacity;

  static set bathymetryOpacity(double value) =>
      bathymetryOverlayOpacity = value;

  static const String defaultWeatherUrl =
      'https://meteofrance.com/meteo-marine';

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    selectedPortKey = prefs.getString('selected_port');
    // Premier lancement : pas de port actif enregistré -> défaut Palavas-les-Flots.
    if (selectedPortKey == null) {
      selectedPortKey = 'palavas_les_flots';
      await prefs.setString('selected_port', 'palavas_les_flots');
    }

    speedUnit = getEnumFromIndex(
      SpeedUnit.values,
      prefs.getInt('speed_unit'),
      SpeedUnit.kmh,
    );

    waypointsVisible = prefs.getBool('waypoints_visible') ?? true;

    showWaypointNamesOnMap =
        prefs.getBool('show_waypoint_names_on_map') ?? true;

    showWaypointDateOnMap = prefs.getBool('show_waypoint_date_on_map') ?? false;

    distanceUnit = getEnumFromIndex(
      DistanceUnit.values,
      prefs.getInt('distance_unit'),
      DistanceUnit.metric,
    );

    mapType = getEnumFromIndex(
      MapType.values,
      prefs.getInt('map_type'),
      MapType.standard,
    );

    waypointLabelFontSize =
        prefs.getDouble('waypoint_label_font_size') ?? 15.0; // 15 par défaut
    waypointLabelFontSize = waypointLabelFontSize.clamp(10.0, 20.0);

    showSpeedOnMap =
        prefs.getBool('show_speed_on_map') ?? false; // false par défaut

    proximityAlarmEnabled = prefs.getBool('proximity_alarm_enabled') ?? false;
    _applyProximityDistances(
      prefs.getDouble('proximity_distance_x') ?? 100.0,
      prefs.getDouble('proximity_distance_y') ?? 20.0,
      prefs.getDouble('proximity_distance_z') ?? 5.0,
    );

    showFishingWaypointsOnMap =
        prefs.getBool('show_fishing_waypoints_on_map') ?? true;
    showMushroomWaypointsOnMap =
        prefs.getBool('show_mushroom_waypoints_on_map') ?? true;
    showOtherWaypointsOnMap =
        prefs.getBool('show_other_waypoints_on_map') ??
        true; // Ajout du chargement
    energySavingMode = prefs.getBool('energy_saving_mode') ?? false;

    bathymetryOverlayEnabled =
        prefs.getBool('bathymetry_overlay_enabled') ?? false;
    bathymetryOverlayOpacity =
        (prefs.getDouble('bathymetry_overlay_opacity') ?? 0.7).clamp(0.0, 1.0);

    final favoritesJson = prefs.getString('favorite_ports');
    if (favoritesJson != null) {
      try {
        final List<dynamic> decoded =
            jsonDecode(favoritesJson) as List<dynamic>;
        favoritePorts = decoded
            .map(
              (e) => FishingPort(
                key: (e['key'] ?? e['name'] ?? '') as String,
                name: (e['name'] ?? '') as String,
                weatherUrl: (e['url'] ?? '') as String,
              ),
            )
            .where((p) => p.name.isNotEmpty && p.weatherUrl.isNotEmpty)
            .toList();
      } catch (_) {
        favoritePorts = [];
      }
    } else {
      // Premier lancement : pas de favoris enregistrés -> défaut Palavas-les-Flots.
      final p = PortService.instance.getPortByKey('palavas_les_flots');
      favoritePorts = [?p];
      await prefs.setString(
        'favorite_ports',
        jsonEncode(
          favoritePorts
              .map(
                (port) => {'key': port.key, 'name': port.name, 'url': port.url},
              )
              .toList(),
        ),
      );
    }
  }

  static Future<void> saveSelectedPort(String? portKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (portKey != null) {
      await prefs.setString('selected_port', portKey);
    } else {
      await prefs.remove('selected_port');
    }
    selectedPortKey = portKey;
  }

  static Future<void> saveSpeedUnit(SpeedUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('speed_unit', unit.index);
    speedUnit = unit;
  }

  static Future<void> saveWaypointsVisibility(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('waypoints_visible', visible);
    waypointsVisible = visible;
  }

  static Future<void> saveWaypointMapDisplayOptions({
    required bool showNames,
    required bool showDates,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_waypoint_names_on_map', showNames);
    await prefs.setBool('show_waypoint_date_on_map', showDates);
    showWaypointNamesOnMap = showNames;
    showWaypointDateOnMap = showDates;
  }

  static Future<void> saveDistanceUnit(DistanceUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('distance_unit', unit.index);
    distanceUnit = unit;
  }

  static Future<void> saveMapType(MapType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('map_type', type.index);
    mapType = type;
  }

  static Future<void> saveWaypointLabelFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = size.clamp(10.0, 20.0);
    await prefs.setDouble('waypoint_label_font_size', clamped);
    waypointLabelFontSize = clamped;
  }

  static Future<void> saveWaypointCategoryVisibility({
    required bool showFishing,
    required bool showMushrooms,
    required bool showOther,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_fishing_waypoints_on_map', showFishing);
    await prefs.setBool('show_mushroom_waypoints_on_map', showMushrooms);
    await prefs.setBool('show_other_waypoints_on_map', showOther);
    showFishingWaypointsOnMap = showFishing;
    showMushroomWaypointsOnMap = showMushrooms;
    showOtherWaypointsOnMap = showOther;
  }

  static Future<void> saveEnergySavingMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('energy_saving_mode', enabled);
    energySavingMode = enabled;
    await GpsController.instance.applyEnergySavingMode();
  }

  static Future<void> saveBathymetryOverlayEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bathymetry_overlay_enabled', enabled);
    bathymetryOverlayEnabled = enabled;
  }

  static Future<void> saveBathymetryOverlayOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = opacity.clamp(0.0, 1.0);
    await prefs.setDouble('bathymetry_overlay_opacity', clamped);
    bathymetryOverlayOpacity = clamped;
  }

  static Future<void> saveSpeedOnMap(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_speed_on_map', show);
    showSpeedOnMap = show;
  }

  static Future<void> saveFavoritePorts(List<FishingPort> portsList) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = portsList
        .map((p) => {'key': p.key, 'name': p.name, 'url': p.url})
        .toList();
    await prefs.setString('favorite_ports', jsonEncode(payload));
    favoritePorts = List<FishingPort>.from(portsList);
  }

  static Future<void> saveProximityAlarmEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('proximity_alarm_enabled', enabled);
    proximityAlarmEnabled = enabled;
  }

  static T getEnumFromIndex<T>(List<T> values, int? index, T defaultValue) {
    if (index == null || index < 0 || index >= values.length) {
      return defaultValue;
    }
    return values[index];
  }

  /// Clamps each zone to its allowed range and enforces X > Y > Z.
  static void _applyProximityDistances(double x, double y, double z) {
    var nx = x.clamp(10.0, 1000.0);
    var ny = y.clamp(5.0, 500.0);
    var nz = z.clamp(1.0, 100.0);

    if (ny >= nx) {
      ny = (nx - 1).clamp(5.0, 500.0);
    }
    if (nz >= ny) {
      nz = (ny - 1).clamp(1.0, 100.0);
    }

    if (nx <= ny || ny <= nz) {
      nx = 100.0;
      ny = 20.0;
      nz = 5.0;
    }

    proximityDistanceX = nx;
    proximityDistanceY = ny;
    proximityDistanceZ = nz;
  }

  static Future<void> saveProximityDistances({
    required double x,
    required double y,
    required double z,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _applyProximityDistances(x, y, z);
    await prefs.setDouble('proximity_distance_x', proximityDistanceX);
    await prefs.setDouble('proximity_distance_y', proximityDistanceY);
    await prefs.setDouble('proximity_distance_z', proximityDistanceZ);
  }

  static String getWeatherUrl() {
    // D'abord chercher dans les ports favoris personnalisés
    if (selectedPortKey != null) {
      final favoritePort = favoritePorts.cast<FishingPort?>().firstWhere(
        (port) => port?.key == selectedPortKey,
        orElse: () => null,
      );
      if (favoritePort != null) {
        return favoritePort.url;
      }

      // Sinon chercher via PortService (inclut _frenchPorts + overrides)
      final portFromService = PortService.instance.getPortByKey(
        selectedPortKey!,
      );
      if (portFromService != null) {
        return portFromService.url;
      }
    }

    return defaultWeatherUrl;
  }

  static String getMapTileUrl() {
    switch (mapType) {
      case MapType.standard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapType.relief:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case MapType.hiking:
        return 'https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png?apikey=$thunderforestApiKey';
      case MapType.marine:
        // Empilement multi-échelles via [MarineMapService] — pas d'URL unique.
        throw StateError(
          'La carte marine utilise MarineMapService.getLayers(), pas getMapTileUrl().',
        );
    }
  }

  /// Centre par défaut si le GPS n'est pas disponible (côte pour la carte marine).
  static LatLng getDefaultMapCenter() {
    if (mapType == MapType.marine) {
      return const LatLng(43.5283, 3.5283); // Palavas-les-Flots
    }
    return const LatLng(45.5017, -73.5673);
  }

  /// Zoom natif min (RasterMarine 1M dès le niveau 3).
  static int getMapMinNativeZoom() {
    if (mapType == MapType.marine) return 3;
    return 0;
  }

  /// Zoom natif max côté serveur SHOM (RasterMarine — tuiles jusqu'au niveau 18).
  static int getMapMaxNativeZoom() {
    if (mapType == MapType.marine) return 18;
    return 19;
  }

  static double getMapMinZoom() {
    if (mapType == MapType.marine) return 5.0;
    return 5;
  }

  static double getMapMaxZoom() {
    if (mapType == MapType.marine) return 20.0;
    return 18;
  }

  /// La carte marine utilise le WMTS SHOM clevisu empilé par échelle.
  static bool get marineMapUsesShomWmts => mapType == MapType.marine;
}
