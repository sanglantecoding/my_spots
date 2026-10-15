import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_engine.dart';
import 'package:my_spots/services/mushroom/mushroom_viewport_forecast_service.dart';
import 'package:my_spots/services/mushroom/lru_cache.dart';

/// Service pour calculer les prévisions de champignons pour les waypoints
/// avec un cache borné (50 entrées, TTL 3 h) et déduplication des requêtes
/// simultanées.
///
/// Les erreurs et les résultats `null` ne sont jamais mis en cache.
/// Le comportement hors-ligne est préservé : en mode offline, sans cache,
/// la méthode retourne `null` sans appel réseau.
class MushroomWaypointForecastService {
  MushroomWaypointForecastService({
    required MushroomViewportBatchSource source,
    required MushroomForecastEngine engine,
  }) : _source = source,
       _engine = engine;

  final MushroomViewportBatchSource _source;
  final MushroomForecastEngine _engine;
  MushroomViewportCancellationToken? _activeCalculation;

  /// Annule le calcul en cours.
  void cancelActive() {
    _activeCalculation?.cancel();
    _activeCalculation = null;
  }

  static const int _maxCacheSize = 50;
  static const Duration _cacheDuration = Duration(hours: 3);
  static const int _maxWaypoints = 50;

  final BoundedLruCache<String, Map<String, List<MushroomForecast>>> _cache =
      BoundedLruCache<String, Map<String, List<MushroomForecast>>>(
        maxSize: _maxCacheSize,
        ttl: _cacheDuration,
      );

  /// Requêtes en cours, indexées par clé de cache (hash des waypoints).
  final Map<String, Future<Map<String, List<MushroomForecast>>?>> _inFlight =
      <String, Future<Map<String, List<MushroomForecast>>?>>{};

  /// Calcule les prévisions pour une liste de waypoints.
  ///
  /// - Retourne `null` si hors-ligne sans cache, ou si > 50 waypoints.
  /// - Les appels simultanés pour la même liste partagent le même [Future].
  /// - Les erreurs et résultats `null` ne sont jamais mis en cache.
  /// - La clé de la Map retournée est l'identifiant du waypoint
  ///   (`lat,lng`).
  Future<Map<String, List<MushroomForecast>>?> calculateForWaypoints(
    List<Waypoint> waypoints, {
    void Function(String)? onStage,
    void Function(String)? onWarning,
  }) async {
    _activeCalculation?.cancel();
    final cancellation = MushroomViewportCancellationToken();
    _activeCalculation = cancellation;

    if (waypoints.isEmpty) return {};
    if (waypoints.length > _maxWaypoints) return null;

    final cacheKey = _generateCacheKey(waypoints);

    final cached = _cache.get(cacheKey);
    if (cached != null) {
      return cached;
    }

    if (AppSettings.offlineModeEnabled) return null;

    // Skip in-flight deduplication when callbacks are provided
    // so each caller receives their own onStage/onWarning
    final existing = (onStage == null && onWarning == null)
        ? _inFlight[cacheKey]
        : null;
    if (existing != null) {
      return await existing;
    }

    var degraded = false;
    void warn(String message) {
      degraded = true;
      onWarning?.call(message);
    }

    final future = _compute(waypoints, onStage, warn, cancellation);
    _inFlight[cacheKey] = future;
    try {
      final result = await future;
      if (cancellation.isCancelled) return null;
      if (result != null && !degraded) {
        _cache.put(cacheKey, result);
      }
      return result;
    } catch (_) {
      // En cas d'erreur : rien n'est mis en cache.
      return null;
    } finally {
      // Retire la clé inFlight même en cas d'erreur.
      if (identical(_inFlight[cacheKey], future)) {
        _inFlight.remove(cacheKey);
      }
    }
  }

  Future<Map<String, List<MushroomForecast>>?> _compute(
    List<Waypoint> waypoints,
    void Function(String)? onStage,
    void Function(String)? onWarning,
    MushroomViewportCancellationToken cancellation,
  ) async {
    final pointsWithKeys = waypoints.map((wp) {
      final key = _waypointKey(wp);
      return (key: key, point: LatLng(wp.latitude, wp.longitude));
    }).toList();

    final service = MushroomViewportForecastService(
      source: _source,
      engine: _engine,
    );

    final points = pointsWithKeys.map((e) => e.point).toList();
    final forecasts = await service.calculateForPoints(
      points,
      onStage,
      onWarning,
    );

    if (cancellation.isCancelled) return null;

    final result = <String, List<MushroomForecast>>{};
    for (int i = 0; i < pointsWithKeys.length && i < forecasts.length; i++) {
      result[pointsWithKeys[i].key] = forecasts[i];
    }
    return result;
  }

  /// Vide tout le cache.
  void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  /// Génère une clé de cache unique pour une liste de waypoints.
  /// Utilise les clés de waypoints triées pour être indépendant de l'ordre.
  String _generateCacheKey(List<Waypoint> waypoints) {
    final now = DateTime.now();
    final day = '${now.year}-${now.month}-${now.day}';
    final keys = waypoints.map(_waypointKey).toList()..sort();
    return '$day#${keys.join('|')}';
  }

  /// Génère une clé unique pour un waypoint.
  String _waypointKey(Waypoint waypoint) {
    return '${waypoint.latitude},${waypoint.longitude}';
  }

  /// Retourne le nombre de waypoints sans données (terrain ou weather null).
  static int countWithoutData(Map<String, List<MushroomForecast>> forecasts) {
    return forecasts.values.where((dayForecasts) {
      return dayForecasts.every(
        (f) =>
            f.dataSources['terrain'] == null ||
            f.dataSources['weather'] == null,
      );
    }).length;
  }

  // ──── Hooks de test ────

  /// Vide le cache et les requêtes en cours (tests uniquement).
  @visibleForTesting
  void resetCacheForTesting() {
    _cache.clear();
    _inFlight.clear();
  }

  /// Taille courante du cache (tests uniquement).
  @visibleForTesting
  int get cacheSize => _cache.length;
}
