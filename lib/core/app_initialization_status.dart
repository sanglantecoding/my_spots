import 'package:flutter/foundation.dart';

class AppInitializationStatus extends ChangeNotifier {
  AppInitializationStatus._();
  static final AppInitializationStatus instance = AppInitializationStatus._();

  bool _criticalServicesOk = true;
  bool get criticalServicesOk => _criticalServicesOk;

  bool _waypointsLoaded = false;
  bool get waypointsLoaded => _waypointsLoaded;

  bool _settingsLoaded = false;
  bool get settingsLoaded => _settingsLoaded;

  bool _mapTileCacheReady = false;
  bool get mapTileCacheReady => _mapTileCacheReady;

  bool _satelliteReady = false;
  bool get satelliteReady => _satelliteReady;

  bool _objectBoxReady = false;
  bool get objectBoxReady => _objectBoxReady;

  final Map<String, Object> _errors = <String, Object>{};
  Map<String, Object> get errors => Map.unmodifiable(_errors);

  bool get isDegraded => !_criticalServicesOk;

  void markSettingsLoaded() {
    _settingsLoaded = true;
    _checkCriticalServices();
  }

  void markWaypointsLoaded() {
    _waypointsLoaded = true;
    _checkCriticalServices();
  }

  void markMapTileCacheReady() {
    _mapTileCacheReady = true;
    notifyListeners();
  }

  void markSatelliteReady() {
    _satelliteReady = true;
    notifyListeners();
  }

  void markObjectBoxReady() {
    _objectBoxReady = true;
    _checkCriticalServices();
  }

  void reportCriticalFailure(String service, Object error) {
    _criticalServicesOk = false;
    _errors[service] = error;
    notifyListeners();
  }

  void reportNonCriticalFailure(String service, Object error) {
    _errors[service] = error;
    notifyListeners();
  }

  /// Vérifie si tous les services critiques ont réussi.
  /// Si oui, sort du mode dégradé (même après un timeout initial).
  void _checkCriticalServices() {
    final allCriticalOk = _settingsLoaded && _waypointsLoaded;

    if (allCriticalOk && !_criticalServicesOk) {
      // Tous les services critiques ont fini par réussir : on sort du mode dégradé
      _criticalServicesOk = true;
      // Supprimer l'erreur de timeout si elle était la seule raison du mode dégradé
      _errors.remove('AppBootstrap.timeout');
      notifyListeners();
    } else if (!allCriticalOk && _criticalServicesOk) {
      // Un service critique a échoué
      _criticalServicesOk = false;
      notifyListeners();
    }
  }
}
