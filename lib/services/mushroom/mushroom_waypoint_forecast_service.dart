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
    ({DateTime timestamp, List<List<MushroomForecast>> forecasts})
  >
  _cache = {};

  static const Duration _cacheDuration = Duration(hours: 3);
  static const int _maxWaypoints = 50;

  /// Calcule les prévisions pour une liste de waypoints.
  /// Retourne null si hors-ligne sans cache, ou si > 50 waypoints.
  Future<List<List<MushroomForecast>>?> calculateForWaypoints(
    List<Waypoint> waypoints,
  ) async {
    if (waypoints.isEmpty) return [];
    if (waypoints.length > _maxWaypoints) return null;

    // Générer une clé de cache basée sur les waypoints
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

    // Convertir les waypoints en LatLng
    final points = waypoints
        .map((wp) => LatLng(wp.latitude, wp.longitude))
        .toList();

    // Calculer via calculateForPoints
    final service = MushroomViewportForecastService(
      source: _source,
      engine: _engine,
    );

    try {
      final forecasts = await service.calculateForPoints(points);

      // Mettre en cache
      _cache[cacheKey] = (timestamp: DateTime.now(), forecasts: forecasts);

      return forecasts;
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
  String _generateCacheKey(List<Waypoint> waypoints) {
    final sorted = List<Waypoint>.from(waypoints)
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted.map((wp) => '${wp.latitude},${wp.longitude}').join('|');
  }

  /// Retourne le nombre de waypoints sans données (indice null ou habitat exclu).
  static int countWithoutData(List<List<MushroomForecast>> forecasts) {
    return forecasts.where((dayForecasts) {
      return dayForecasts.every(
        (f) => f.index == 0 || f.habitat == HabitatStatus.excluded,
      );
    }).length;
  }
}
