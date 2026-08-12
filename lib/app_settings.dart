import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum SpeedUnit { knots, kmh }

enum DistanceUnit { metric, nautical }

enum MapType { standard, relief, hiking, marine }

class FishingPort {
  final String name;
  final String url;

  const FishingPort({required this.name, required this.url});
}

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

  // Superposition relief sous-marin / LiDAR (Géoplateforme + SHOM)
  static bool bathymetryOverlayEnabled = false;
  static double bathymetryOverlayOpacity = 0.7;

  static const Map<String, FishingPort> ports = {
    'palavas': FishingPort(
      name: 'Palavas-les-Flots',
      url: 'https://meteofrance.com/meteo-marine/palavas-les-flots/570277',
    ),
    'sete': FishingPort(
      name: 'Sète',
      url: 'https://meteofrance.com/meteo-marine/sete/570202',
    ),
    'carnon': FishingPort(
      name: 'Carnon',
      url: 'https://meteofrance.com/meteo-marine/carnon/570211',
    ),
    'cap_agde': FishingPort(
      name: 'Cap d\'Agde',
      url: 'https://meteofrance.com/meteo-marine/cap-d-agde/570229',
    ),
    'grau_du_roi': FishingPort(
      name: 'Le Grau-du-Roi / Port-Camargue',
      url: 'https://meteofrance.com/meteo-marine/le-grau-du-roi/570268',
    ),
  };

  static const String defaultWeatherUrl =
      'https://meteofrance.com/meteo-marine';

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    selectedPortKey = prefs.getString('selected_port');

    final speedUnitIndex =
        prefs.getInt('speed_unit') ?? 1; // km/h par défaut (index 1)
    speedUnit = SpeedUnit.values[speedUnitIndex];

    waypointsVisible = prefs.getBool('waypoints_visible') ?? true;

    showWaypointNamesOnMap =
        prefs.getBool('show_waypoint_names_on_map') ?? true;

    showWaypointDateOnMap = prefs.getBool('show_waypoint_date_on_map') ?? false;

    final distanceUnitIndex =
        prefs.getInt('distance_unit') ?? 0; // metric par défaut (index 0)
    distanceUnit = DistanceUnit.values[distanceUnitIndex];

    final mapTypeIndex = prefs.getInt('map_type') ?? 0;
    mapType = MapType.values[mapTypeIndex];

    waypointLabelFontSize =
        prefs.getDouble('waypoint_label_font_size') ?? 15.0; // 15 par défaut
    waypointLabelFontSize = waypointLabelFontSize.clamp(10.0, 20.0);

    showSpeedOnMap =
        prefs.getBool('show_speed_on_map') ?? false; // false par défaut

    proximityAlarmEnabled = prefs.getBool('proximity_alarm_enabled') ?? false;
    proximityDistanceX = (prefs.getDouble('proximity_distance_x') ?? 100.0)
        .clamp(10.0, 1000.0);
    proximityDistanceY = (prefs.getDouble('proximity_distance_y') ?? 20.0)
        .clamp(5.0, 500.0);
    proximityDistanceZ = (prefs.getDouble('proximity_distance_z') ?? 5.0).clamp(
      1.0,
      100.0,
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
                name: (e['name'] ?? '') as String,
                url: (e['url'] ?? '') as String,
              ),
            )
            .where((p) => p.name.isNotEmpty && p.url.isNotEmpty)
            .toList();
      } catch (_) {
        favoritePorts = [];
      }
    } else {
      favoritePorts = [];
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
        .map((p) => {'name': p.name, 'url': p.url})
        .toList();
    await prefs.setString('favorite_ports', jsonEncode(payload));
    favoritePorts = List<FishingPort>.from(portsList);
  }

  static List<FishingPort> getEffectiveFavoritePorts() {
    if (favoritePorts.isNotEmpty) {
      return favoritePorts;
    }
    return ports.values.toList();
  }

  static Future<void> saveProximityAlarmEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('proximity_alarm_enabled', enabled);
    proximityAlarmEnabled = enabled;
  }

  static Future<void> saveProximityDistances({
    required double x,
    required double y,
    required double z,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final xClamp = x.clamp(10.0, 1000.0);
    final yClamp = y.clamp(5.0, 500.0);
    final zClamp = z.clamp(1.0, 100.0);
    await prefs.setDouble('proximity_distance_x', xClamp);
    await prefs.setDouble('proximity_distance_y', yClamp);
    await prefs.setDouble('proximity_distance_z', zClamp);
    proximityDistanceX = xClamp;
    proximityDistanceY = yClamp;
    proximityDistanceZ = zClamp;
  }

  static String getWeatherUrl() {
    if (selectedPortKey != null && ports.containsKey(selectedPortKey)) {
      return ports[selectedPortKey]!.url;
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
        return 'https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png?apikey=5f93b838b4134d6a8bd223c62408d2df';
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

  /// Zoom natif min (RasterMarine : 1:1 000 000 dès le niveau 5).
  static int getMapMinNativeZoom() {
    if (mapType == MapType.marine) return 5;
    return 0;
  }

  /// Zoom natif max côté serveur SHOM (RasterMarine — tuiles jusqu'au niveau 18).
  static int getMapMaxNativeZoom() {
    if (mapType == MapType.marine) return 18;
    return 19;
  }

  static double getMapMinZoom() {
    if (mapType == MapType.marine) return 0;
    return 5;
  }

  static double getMapMaxZoom() {
    if (mapType == MapType.marine) return 22;
    return 18;
  }

  /// La carte marine utilise le WMTS SHOM clevisu empilé par échelle.
  static bool get marineMapUsesShomWmts => mapType == MapType.marine;
}
