import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_spots/controllers/gps_controller.dart';
import 'package:my_spots/models/fishing_port.dart';
import 'package:my_spots/services/port_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

enum SpeedUnit { knots, kmh }

enum DistanceUnit { metric, nautical }

enum MapType { marine, standard, relief, hiking }

class AppSettings {
  static final ValueNotifier<bool> offlineModeNotifier = ValueNotifier<bool>(
    false,
  );
  static SpeedUnit speedUnit = SpeedUnit.kmh; // km/h par défaut
  static String? selectedPortKey;
  static bool waypointsVisible = true;
  static bool showWaypointNamesOnMap = true;
  static bool showWaypointDateOnMap = false;
  static DistanceUnit distanceUnit = DistanceUnit.metric;
  static double waypointLabelFontSize = 15.0; // 15 par défaut
  static MapType mapType = MapType.marine;
  static bool showSpeedOnMap = false; // false par défaut
  static bool offlineModeEnabled = false;

  /// Valeur écrite dans SharedPreferences quand l'utilisateur choisit
  /// explicitement « Aucun (météo générale) ».
  ///
  /// 🛡️ CORRECTION : permet à [loadSettings] de distinguer
  /// « premier lancement » (clé absente → défaut Palavas) de
  /// « choix explicite aucun » (clé présente avec cette sentinelle → null).
  /// Sans elle, saveSelectedPort(null) faisait remove() et le défaut
  /// revenait à chaque redémarrage.
  static const String _noPortStoredValue = '__none__';
  static const String _offlineModeKey = 'offline_mode_enabled';

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

  // ─── Clé API Thunderforest (Randonnée) ───────────────────────────────
  // Stockée en SharedPreferences pour ne plus dépendre du .env build-time.
  // Le getter retourne la clé persistée, ou (en fallback) celle du .env si
  // l'utilisateur n'a encore rien saisi — compatibilité ascendante.
  static String _thunderforestApiKey = '';
  static String get thunderforestApiKey => _thunderforestApiKey;

  static bool get hasThunderforestApiKey => _thunderforestApiKey.isNotEmpty;

  static Future<void> saveThunderforestApiKey(String key) async {
    final trimmed = key.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove('thunderforest_api_key');
      _thunderforestApiKey = '';
    } else {
      await prefs.setString('thunderforest_api_key', trimmed);
      _thunderforestApiKey = trimmed;
    }
  }

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

    // 🛡️ CORRECTION : on ne confond plus « clé absente » (premier lancement)
    // et « clé présente valant la sentinelle » (choix explicite "Aucun").
    if (prefs.containsKey('selected_port')) {
      final stored = prefs.getString('selected_port');
      selectedPortKey = (stored == null || stored == _noPortStoredValue)
          ? null
          : stored;
    } else {
      // Premier lancement : pas de port actif enregistré -> défaut Palavas-les-Flots.
      selectedPortKey = 'palavas_les_flots';
      await prefs.setString('selected_port', 'palavas_les_flots');
    }

    offlineModeEnabled = prefs.getBool(_offlineModeKey) ?? false;
    offlineModeNotifier.value = offlineModeEnabled;

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
      MapType.marine,
    );

    waypointLabelFontSize =
        (prefs.getDouble('waypoint_label_font_size') ?? 15.0)
            .clamp(10.0, 20.0)
            .toDouble();

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
        (prefs.getDouble('bathymetry_overlay_opacity') ?? 0.7)
            .clamp(0.0, 1.0)
            .toDouble();

    _thunderforestApiKey = prefs.getString('thunderforest_api_key') ?? '';

    final favoritesJson = prefs.getString('favorite_ports');
    if (favoritesJson != null) {
      try {
        final List<dynamic> decoded =
            jsonDecode(favoritesJson) as List<dynamic>;
        favoritePorts = decoded
            .whereType<Map<String, dynamic>>()
            .where(
              (e) =>
                  e.containsKey('name') &&
                  (e.containsKey('weatherUrl') || e.containsKey('url')),
            )
            .map(FishingPort.fromMap)
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

  /// Persiste le port sélectionné, ou le choix explicite « Aucun » ([portKey] null).
  ///
  /// 🛡️ CORRECTION : n'efface PLUS la clé SharedPreferences. Un `null` écrit
  /// la sentinelle [_noPortStoredValue], sinon le prochain boot interprétait
  /// l'absence de clé comme un premier lancement et réimposait Palavas.
  static Future<void> saveSelectedPort(String? portKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_port', portKey ?? _noPortStoredValue);
    selectedPortKey = portKey;
  }

  static Future<void> saveSpeedUnit(SpeedUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('speed_unit', unit.index);
    speedUnit = unit;
  }

  static Future<void> saveOfflineMode(bool value) async {
    offlineModeEnabled = value;
    offlineModeNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineModeKey, value);
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
    final clamped = size.clamp(10.0, 20.0).toDouble();
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
    final clamped = opacity.clamp(0.0, 1.0).toDouble();
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
    final payload = portsList.map((p) => p.toMap()).toList();
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
    var nx = x.clamp(10.0, 1000.0).toDouble();
    var ny = y.clamp(5.0, 500.0).toDouble();
    var nz = z.clamp(1.0, 100.0).toDouble();

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
      case MapType.marine:
        // Empilement multi-échelles via [MarineMapService] — pas d'URL unique.
        throw StateError(
          'La carte marine utilise MarineMapService.getLayers(), pas getMapTileUrl().',
        );
      case MapType.standard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapType.relief:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case MapType.hiking:
        return 'https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png?apikey=$thunderforestApiKey';
    }
  }

  /// Centre par défaut si le GPS n'est pas disponible (côte pour la carte marine).
  static LatLng getDefaultMapCenter() {
    if (mapType == MapType.marine) {
      return const LatLng(43.392975, 3.700844); // Palavas-les-Flots
    }
    return const LatLng(43.500763, 3.711130);
  }

  /// Zoom natif min (RasterMarine 1M dès le niveau 3).
  static int getMapMinNativeZoom() {
    if (mapType == MapType.marine) return 3;
    return 0;
  }

  /// Zoom natif max côté serveur, par type de carte.
  /// (OSM standard ≈ 19, OpenTopoMap ≈ 17, Thunderforest ≈ 22)
  static int getMapMaxNativeZoom() {
    switch (mapType) {
      case MapType.marine:
        return 18;
      case MapType.standard:
        return 19; // OSM standard : natif jusqu'à 19
      case MapType.relief:
        return 17; // OpenTopoMap : natif jusqu'à 17
      case MapType.hiking:
        return 22; // Thunderforest Outdoors : natif jusqu'à 22
    }
  }

  static double getMapMinZoom() {
    if (mapType == MapType.marine) return 5.0;
    return 5;
  }

  /// Zoom max de la caméra, par type de carte.
  /// Au-delà du zoom natif, flutter_map fait de l'overzoom (tuiles étirées).
  static double getMapMaxZoom() {
    switch (mapType) {
      case MapType.marine:
        return 20.0;
      case MapType.standard:
        return 22.0; // 19 natif + 3 niveau d'overzoom
      case MapType.relief:
        return 22.0; // 17 natif + 5 niveaux d'overzoom
      case MapType.hiking:
        return 22.0; // natif Thunderforest
    }
  }

  /// La carte marine utilise le WMTS SHOM clevisu empilé par échelle.
  static bool get marineMapUsesShomWmts => mapType == MapType.marine;
}
