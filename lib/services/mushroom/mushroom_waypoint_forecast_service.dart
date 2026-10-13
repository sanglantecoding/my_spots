import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_engine.dart';
import 'package:my_spots/services/mushroom/mushroom_viewport_forecast_service.dart';

/// Service pour calculer les prévisions de champignons pour les waypoints
/// avec un cache de 3 heures.
class MushroomWaypointForecastService {
  MushroomWaypointForecastService({
    required MushroomViewportBatchSource source,
    required MushroomForecastEngine engine,
  }) : _source = source,
       _engine = engine;

  final MushroomViewportBatchSource _source;
  final MushroomForecastEngine _engine;

  // Cache: clé = hash des waypoints, valeur = (timestamp, résultats)
  final Map<
    String,
    ({DateTime timestamp, Map<String, List<MushroomForecast>> forecasts})
  >
  _cache = {};

  static const Duration _cacheDuration = Duration(hours: 3);
  static const int _maxWaypoints = 50;

  /// Calcule les prévisions pour une liste de waypoints.
  /// Retourne null si hors-ligne sans cache, ou si > 50 waypoints.
  /// La clé de la Map est l'identifiant du waypoint (id si existe, sinon 'lat,lng').
  Future<Map<String, List<MushroomForecast>>?> calculateForWaypoints(
    List<Waypoint> waypoints, {
    void Function(String)? onStage,
    void Function(String)? onWarning,
  }) async {
    if (waypoints.isEmpty) return {};
    if (waypoints.length > _maxWaypoints) return null;

    // Générer une clé de cache basée sur les waypoints (triés par clé)
    final cacheKey = _generateCacheKey(waypoints);

    // Vérifier le cache
    final cached = _cache[cacheKey];
    if (cached != null) {
      final age = DateTime.now().difference(cached.timestamp);
      if (age < _cacheDuration) {
        return cached.forecasts;
      } else {
        _cache.remove(cacheKey);
      }
    }

    // Convertir les waypoints en LatLng avec leurs clés
    final pointsWithKeys = waypoints.map((wp) {
      final key = _waypointKey(wp);
      return (key: key, point: LatLng(wp.latitude, wp.longitude));
    }).toList();

    // Calculer via calculateForPoints
    final service = MushroomViewportForecastService(
      source: _source,
      engine: _engine,
    );

    try {
      final points = pointsWithKeys.map((e) => e.point).toList();
      final forecasts = await service.calculateForPoints(
        points,
        onStage,
        onWarning,
      );

      // Construire la Map avec les clés de waypoints
      final result = <String, List<MushroomForecast>>{};
      for (int i = 0; i < pointsWithKeys.length && i < forecasts.length; i++) {
        result[pointsWithKeys[i].key] = forecasts[i];
      }

      // Mettre en cache
      _cache[cacheKey] = (timestamp: DateTime.now(), forecasts: result);

      return result;
    } catch (e) {
      // En cas d'erreur (hors-ligne), retourner null
      return null;
    }
  }

  /// Invalide le cache pour une liste de waypoints.
  void invalidateCache(List<Waypoint> waypoints) {
    final cacheKey = _generateCacheKey(waypoints);
    _cache.remove(cacheKey);
  }

  /// Vide tout le cache.
  void clearCache() {
    _cache.clear();
  }

  /// Génère une clé de cache unique pour une liste de waypoints.
  /// Utilise les clés de waypoints triées pour être indépendant de l'ordre.
  String _generateCacheKey(List<Waypoint> waypoints) {
    final keys = waypoints.map(_waypointKey).toList()..sort();
    return keys.join('|');
  }

  /// Génère une clé unique pour un waypoint.
  /// Utilise l'identifiant s'il existe, sinon 'lat,lng'.
  String _waypointKey(Waypoint waypoint) {
    return '${waypoint.latitude},${waypoint.longitude}';
  }

  /// Retourne le nombre de waypoints sans données (indice null ou habitat exclu).
  static int countWithoutData(Map<String, List<MushroomForecast>> forecasts) {
    return forecasts.values.where((dayForecasts) {
      return dayForecasts.every(
        (f) => f.index == 0 || f.habitat == HabitatStatus.excluded,
      );
    }).length;
  }
}
