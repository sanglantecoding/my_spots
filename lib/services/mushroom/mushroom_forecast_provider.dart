import 'package:flutter/foundation.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_service.dart';
import 'package:my_spots/services/mushroom/mushroom_services.dart';
import 'package:my_spots/services/mushroom/boletus_edulis_model.dart';
import 'package:my_spots/services/mushroom/lru_cache.dart';

/// Point d'accès unique aux prévisions de champignons.
///
/// Cache borné (500 entrées, TTL 1 h) + déduplication des requêtes
/// simultanées pour une même clé. Les erreurs ne sont jamais mises en cache.
class MushroomForecastProvider {
  MushroomForecastProvider._();

  static const int _maxCacheSize = 500;
  static const Duration _cacheTtl = Duration(hours: 1);

  static final BoundedLruCache<String, MushroomForecast> _forecastCache =
      BoundedLruCache<String, MushroomForecast>(
        maxSize: _maxCacheSize,
        ttl: _cacheTtl,
      );

  static final MushroomForecastService _service = _createService();

  /// Requêtes réseau en cours, indexées par clé de requête.
  /// Permet de partager le même [Future] entre appelants simultanés.
  static final Map<String, Future<dynamic>> _inFlight =
      <String, Future<dynamic>>{};

  static String _cacheKey(double latitude, double longitude, DateTime date) =>
      '${latitude.toStringAsPrecision(12)}:'
      '${longitude.toStringAsPrecision(12)}:'
      '${date.year}-${date.month}-${date.day}';

  static String _rangeRequestKey(
    double latitude,
    double longitude,
    DateTime startDate,
  ) =>
      'range:'
      '${latitude.toStringAsPrecision(12)}:'
      '${longitude.toStringAsPrecision(12)}:'
      '${startDate.year}-${startDate.month}-${startDate.day}';

  static String _singleRequestKey(
    double latitude,
    double longitude,
    DateTime date,
  ) =>
      'single:'
      '${latitude.toStringAsPrecision(12)}:'
      '${longitude.toStringAsPrecision(12)}:'
      '${date.year}-${date.month}-${date.day}';

  static MushroomForecastService _createService() {
    final services = MushroomServices.instance;
    final service = MushroomForecastService(
      weatherService: services.weatherService,
      terrainService: services.terrainService,
      forestService: services.ignBdForetService,
    );
    service.registerEngine(BoletusEdulisModel());
    return service;
  }

  /// Calcule les prévisions J+0..J+7 et met en cache chaque jour.
  ///
  /// Les appels simultanés pour les mêmes paramètres partagent le même
  /// [Future] (pas de double requête réseau). Les erreurs ne sont pas
  /// mises en cache.
  static Future<List<MushroomForecast>> forecastBoletusRange({
    required double latitude,
    required double longitude,
    required DateTime startDate,
  }) async {
    if (AppSettings.offlineModeEnabled) {
      throw StateError('Prévisions champignons indisponibles hors-ligne.');
    }

    final requestKey = _rangeRequestKey(latitude, longitude, startDate);
    final existing = _inFlight[requestKey];
    if (existing != null) {
      return existing as Future<List<MushroomForecast>>;
    }

    final future = _service
        .calculateForecastRange(
          lat: latitude,
          lng: longitude,
          species: MushroomSpecies.boletusEdulis,
          startDate: startDate,
          days: 7,
        )
        .then<List<MushroomForecast>>((forecasts) {
          for (final forecast in forecasts) {
            _forecastCache.put(
              _cacheKey(latitude, longitude, forecast.date),
              forecast,
            );
          }
          return forecasts;
        });

    _inFlight[requestKey] = future;
    return future.whenComplete(() {
      // Supprime la clé même en cas d'erreur : ne bloque pas les retry.
      if (identical(_inFlight[requestKey], future)) {
        _inFlight.remove(requestKey);
      }
    });
  }

  /// Réutilise d'abord une prévision déjà calculée, puis calcule en ligne.
  ///
  /// En mode hors-ligne, l'absence de cache renvoie null sans appel réseau.
  /// Les erreurs ne sont jamais mises en cache.
  static Future<MushroomForecast?> forecastForObservation({
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async {
    final key = _cacheKey(latitude, longitude, date);
    final cached = _forecastCache.get(key);
    if (cached != null) return cached;
    if (AppSettings.offlineModeEnabled) return null;

    final requestKey = _singleRequestKey(latitude, longitude, date);
    final existing = _inFlight[requestKey];
    if (existing != null) {
      return await (existing as Future<MushroomForecast?>);
    }

    final future = _service.calculateForecast(
      lat: latitude,
      lng: longitude,
      species: MushroomSpecies.boletusEdulis,
      targetDate: date,
    );

    _inFlight[requestKey] = future;
    try {
      final forecast = await future;
      // Ne met en cache que les prévisions valides (non nulles).
      _forecastCache.put(key, forecast);
      return forecast;
    } catch (_) {
      // En cas d'erreur : rien n'est mis en cache, la clé inFlight est
      // retirée dans le finally, un prochain appel pourra retenter.
      rethrow;
    } finally {
      if (identical(_inFlight[requestKey], future)) {
        _inFlight.remove(requestKey);
      }
    }
  }

  // ──── Hooks de test ────

  /// Vide le cache et les requêtes en cours (tests uniquement).
  @visibleForTesting
  static void resetForTesting() {
    _forecastCache.clear();
    _inFlight.clear();
  }

  /// Taille courante du cache (tests uniquement).
  @visibleForTesting
  static int get cacheSize => _forecastCache.length;

  /// Injecte une entrée avec un timestamp arbitraire (tests d'expiration).
  @visibleForTesting
  static void debugPutForTesting(
    double latitude,
    double longitude,
    DateTime date,
    MushroomForecast forecast,
    DateTime timestamp,
  ) {
    _forecastCache.debugPutWithTimestamp(
      _cacheKey(latitude, longitude, date),
      forecast,
      timestamp,
    );
  }
}
