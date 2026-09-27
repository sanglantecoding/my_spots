import 'dart:developer' as developer;
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/core/app_initialization_status.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/objectbox.g.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/satellite_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';

/// Orchestrateur du démarrage de l'application.
class AppBootstrap {
  AppBootstrap._();

  static const String _logName = 'MySpots.AppBootstrap';
  static final AppInitializationStatus _status =
      AppInitializationStatus.instance;

  /// Initialise les services applicatifs dans l'ordre optimal.
  static Future<void> initialize() async {
    // 1) Paramètres de l'application (pré-requis séquentiel).
    try {
      await AppSettings.loadSettings();
      _status.markSettingsLoaded();
      developer.log('AppSettings.loadSettings OK', name: _logName);
    } catch (e, st) {
      _status.reportCriticalFailure('AppSettings', e);
      developer.log(
        'AppSettings.loadSettings a échoué',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    // 2) Services indépendants en parallèle.
    await Future.wait<void>(<Future<void>>[
      _loadWaypoints(),
      _initialiseMapTileCache(),
      _initialiseSatellite(),
      _initialiseObjectBox(),
      _initialisePackageInfo(),
    ]);
  }

  static Future<void> _loadWaypoints() async {
    try {
      await WaypointStore.load();
      _status.markWaypointsLoaded();
      developer.log('WaypointStore.load OK', name: _logName);
    } catch (e, st) {
      _status.reportCriticalFailure('WaypointStore', e);
      developer.log(
        'WaypointStore.load a échoué (mode dégradé)',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> _initialiseMapTileCache() async {
    try {
      await MapTileCacheService.initialise();
      _status.markMapTileCacheReady();
      developer.log('MapTileCacheService.initialise OK', name: _logName);
    } catch (e, st) {
      _status.reportNonCriticalFailure('MapTileCacheService', e);
      developer.log(
        'MapTileCacheService.initialise a échoué (cache hors-ligne désactivé)',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> _initialiseSatellite() async {
    try {
      await SatelliteService.initialize();
      _status.markSatelliteReady();
      developer.log('SatelliteService.initialize OK', name: _logName);
    } catch (e, st) {
      _status.reportNonCriticalFailure('SatelliteService', e);
      developer.log(
        'SatelliteService.initialize a échoué (GNSS visuel désactivé)',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> _initialiseObjectBox() async {
    try {
      final store = await openStore();
      OfflineMapRepository.initWithStore(store);
      _status.markObjectBoxReady();
      developer.log(
        'OfflineMapRepository singleton initialisé',
        name: _logName,
      );
    } catch (e, st) {
      _status.reportNonCriticalFailure('OfflineMapRepository', e);
      developer.log(
        'OfflineMapRepository.init a échoué (zones hors-ligne désactivées)',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> _initialisePackageInfo() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      TileProviderFactory.appVersion = pkg.version;
      developer.log(
        'appVersion=${pkg.version} (build=${pkg.buildNumber})',
        name: _logName,
      );
    } catch (e, st) {
      _status.reportNonCriticalFailure('PackageInfo', e);
      developer.log(
        'PackageInfo indisponible → fallback appVersion',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }
}
