import 'dart:developer' as developer;

import 'package:my_spots/app_settings.dart';
import 'package:my_spots/core/app_initialization_status.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/satellite_service.dart';

/// Orchestrateur du démarrage de l'application.
///
/// Stratégie :
/// 1. `AppSettings.loadSettings()` est exécuté en premier (config requise).
/// 2. Les services indépendants (`WaypointStore`, `MapTileCacheService`,
///    `SatelliteService`) sont lancés en parallèle via `Future.wait`.
/// 3. Chaque service secondaire est protégé par son propre `try/catch` :
///    un échec de `SatelliteService` ou `MapTileCacheService` n'empêche
///    pas le chargement des waypoints du pêcheur.
///
/// En cas d'échec d'un service critique (Settings ou Waypoints), un flag
/// global est posé dans [AppInitializationStatus] pour que l'UI
/// (ex. `HomePage`) puisse gérer sereinement le mode dégradé.
class AppBootstrap {
  AppBootstrap._();

  /// Tag utilisé pour les logs développeur.
  static const String _logName = 'MySpots.AppBootstrap';

  /// Initialise les services applicatifs dans l'ordre optimal.
  ///
  /// Lève uniquement si [AppSettings.loadSettings()] échoue (chemin
  /// strictement séquentiel). Tous les autres services sont isolés.
  static Future<void> initialize() async {
    // -------------------------------------------------------------------
    // 1) Paramètres de l'application (pré-requis avant tout le reste).
    // -------------------------------------------------------------------
    try {
      await AppSettings.loadSettings();
      AppInitializationStatus.settingsLoaded = true;
      developer.log('AppSettings.loadSettings OK', name: _logName);
    } catch (e, st) {
      AppInitializationStatus.criticalServicesOk = false;
      AppInitializationStatus.settingsLoaded = false;
      AppInitializationStatus.errors['AppSettings'] = e;
      developer.log(
        'AppSettings.loadSettings a échoué',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    // -------------------------------------------------------------------
    // 2) Services indépendants en parallèle.
    //    Chaque service secondaire est isolé : un échec n'annule pas
    //    le chargement des autres (notamment les waypoints du pêcheur).
    // -------------------------------------------------------------------
    await Future.wait<void>(<Future<void>>[
      _loadWaypoints(),
      _initialiseMapTileCache(),
      _initialiseSatellite(),
    ]);
  }

  /// Charge les waypoints persistés (service critique pour l'usage principal).
  static Future<void> _loadWaypoints() async {
    try {
      await WaypointStore.load();
      AppInitializationStatus.waypointsLoaded = true;
      developer.log('WaypointStore.load OK', name: _logName);
    } catch (e, st) {
      AppInitializationStatus.criticalServicesOk = false;
      AppInitializationStatus.waypointsLoaded = false;
      AppInitializationStatus.errors['WaypointStore'] = e;
      developer.log(
        'WaypointStore.load a échoué (mode dégradé)',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Initialise le cache FMTC (non-bloquant : l'app fonctionne sans cache).
  static Future<void> _initialiseMapTileCache() async {
    try {
      await MapTileCacheService.initialise();
      AppInitializationStatus.mapTileCacheReady = true;
      developer.log('MapTileCacheService.initialise OK', name: _logName);
    } catch (e, st) {
      AppInitializationStatus.mapTileCacheReady = false;
      AppInitializationStatus.errors['MapTileCacheService'] = e;
      developer.log(
        'MapTileCacheService.initialise a échoué (cache hors-ligne désactivé)',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Initialise le service satellites (non-bloquant : GPS peut démarrer plus tard).
  static Future<void> _initialiseSatellite() async {
    try {
      await SatelliteService.initialize();
      AppInitializationStatus.satelliteReady = true;
      developer.log('SatelliteService.initialize OK', name: _logName);
    } catch (e, st) {
      AppInitializationStatus.satelliteReady = false;
      AppInitializationStatus.errors['SatelliteService'] = e;
      developer.log(
        'SatelliteService.initialize a échoué (GNSS visuel désactivé)',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }
}
