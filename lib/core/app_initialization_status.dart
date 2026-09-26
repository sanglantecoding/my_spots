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

  final Map<String, Object> _errors = <String, Object>{};
  Map<String, Object> get errors => Map.unmodifiable(_errors);

  bool get isDegraded => !_criticalServicesOk;

  void markSettingsLoaded() {
    _settingsLoaded = true;
    notifyListeners();
  }

  void markWaypointsLoaded() {
    _waypointsLoaded = true;
    notifyListeners();
  }

  void markMapTileCacheReady() {
    _mapTileCacheReady = true;
    notifyListeners();
  }

  void markSatelliteReady() {
    _satelliteReady = true;
    notifyListeners();
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
}
