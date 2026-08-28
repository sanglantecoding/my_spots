import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_spots/app_settings.dart';

/// État du contrôleur GPS
enum GpsState {
  /// Le GPS est arrêté
  stopped,

  /// Le GPS est en cours d'initialisation
  initializing,

  /// Le GPS est actif mais l'appareil est immobile
  stationary,

  /// Le GPS est actif et l'appareil est en mouvement
  moving,

  /// Une erreur est survenue
  error,
}

/// Contrôleur GPS unifié qui encapsule un seul flux de position
///
/// Ce contrôleur singleton évite les appels multiples à Geolocator.getPositionStream()
/// qui drainent la batterie et causent des conditions de course.
class GpsController extends ChangeNotifier {
  // Singleton pattern
  GpsController._();
  static final GpsController instance = GpsController._();

  // Flux de position unique
  StreamSubscription<Position>? _positionSubscription;

  // État actuel
  Position? _currentPosition;
  double _currentSpeed = 0.0;
  double _currentAccuracy = 0.0;
  GpsState _state = GpsState.stopped;
  String? _errorMessage;

  // Seuils d'hystérésis pour éviter les changements d'état fréquents
  static const double _movingThreshold = 1.0; // m/s
  static const double _stationaryThreshold = 0.3; // m/s

  /// Réglage d'économie d'énergie actuellement appliqué au flux matériel.
  bool? _streamUsesEnergySaving;

  // Contrôleurs de flux pour les abonnés
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  final StreamController<GpsState> _stateController =
      StreamController<GpsState>.broadcast();

  /// Flux de position pour les abonnés externes
  Stream<Position> get positionStream => _positionController.stream;

  /// Flux d'état pour les abonnés externes
  Stream<GpsState> get stateStream => _stateController.stream;

  /// Position GPS actuelle
  Position? get currentPosition => _currentPosition;

  /// Vitesse actuelle en m/s
  double get currentSpeed => _currentSpeed;

  /// Vitesse actuelle en km/h
  double get currentSpeedKmh => _currentSpeed * 3.6;

  /// Vitesse actuelle en nœuds
  double get currentSpeedKnots => _currentSpeed * 1.94384;

  /// Précision GPS actuelle en mètres
  double get currentAccuracy => _currentAccuracy;

  /// État actuel du GPS
  GpsState get state => _state;

  /// Message d'erreur (si state == error)
  String? get errorMessage => _errorMessage;

  /// Latitude actuelle
  double? get latitude => _currentPosition?.latitude;

  /// Longitude actuelle
  double? get longitude => _currentPosition?.longitude;

  /// Altitude actuelle en mètres
  double? get altitude => _currentPosition?.altitude;

  /// Cap actuel en degrés (0-360)
  double? get heading => _currentPosition?.heading;

  /// Indique si le GPS est actif
  bool get isActive => _state != GpsState.stopped && _state != GpsState.error;

  /// Indique si l'appareil est en mouvement
  bool get isMoving => _state == GpsState.moving;

  /// Démarre le suivi GPS
  Future<bool> start() async {
    if (_state != GpsState.stopped) {
      // Déjà en cours d'exécution
      return true;
    }

    _setState(GpsState.initializing);

    try {
      // Vérifier si le service GPS est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setState(GpsState.error, 'GPS DÉSACTIVÉ');
        return false;
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setState(GpsState.error, 'PERMISSION REFUSÉE');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setState(GpsState.error, 'PERMISSION REFUSÉE DÉFINITIVEMENT');
        return false;
      }

      // Obtenir la position initiale
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      _updatePosition(initialPosition);

      await _subscribeToPositionStream();
      return true;
    } catch (e) {
      _setState(GpsState.error, e.toString());
      return false;
    }
  }

  /// Met à jour la position et calcule l'état avec hystérésis
  void _updatePosition(Position position) {
    _currentPosition = position;
    _currentAccuracy = position.accuracy;

    // Calculer la vitesse en m/s
    final speed = position.speed;
    _currentSpeed = speed;

    // Logique d'hystérésis pour éviter les changements d'état fréquents
    final newState = _calculateStateWithHysteresis(speed);

    if (newState != _state) {
      _setState(newState);
    } else {
      notifyListeners();
    }

    _positionController.add(position);
  }

  /// Calcule l'état avec hystérésis
  GpsState _calculateStateWithHysteresis(double speed) {
    // Si on est déjà en mouvement, on reste en mouvement tant que la vitesse
    // ne descend pas en dessous du seuil stationnaire
    if (_state == GpsState.moving) {
      if (speed < _stationaryThreshold) {
        return GpsState.stationary;
      }
      return GpsState.moving;
    }

    // Si on est stationnaire, on passe en mouvement seulement si la vitesse
    // dépasse le seuil de mouvement
    if (_state == GpsState.stationary || _state == GpsState.initializing) {
      if (speed > _movingThreshold) {
        return GpsState.moving;
      }
      return GpsState.stationary;
    }

    // Par défaut, on considère stationnaire
    return GpsState.stationary;
  }

  /// Met à jour l'état et notifie les abonnés
  void _setState(GpsState newState, [String? error]) {
    final oldState = _state;
    _state = newState;
    _errorMessage = error;

    if (oldState != newState) {
      _stateController.add(newState);
      notifyListeners();
    }
  }

  /// Reconfigure le flux GPS matériel selon [AppSettings.energySavingMode].
  ///
  /// Sans effet si le suivi n'est pas encore démarré.
  Future<void> applyEnergySavingMode() async {
    if (_positionSubscription == null) {
      return;
    }
    if (_streamUsesEnergySaving == AppSettings.energySavingMode) {
      return;
    }
    await _subscribeToPositionStream();
  }

  LocationSettings _buildLocationSettings() {
    final energySaving = AppSettings.energySavingMode;
    final distanceFilter = energySaving ? 10 : 0;
    final interval = energySaving
        ? const Duration(seconds: 10)
        : const Duration(seconds: 1);

    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        intervalDuration: interval,
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: energySaving,
        activityType: ActivityType.otherNavigation,
      );
    }

    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
  }

  Future<void> _subscribeToPositionStream() async {
    await _positionSubscription?.cancel();
    _streamUsesEnergySaving = AppSettings.energySavingMode;
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: _buildLocationSettings(),
        ).listen(
          _updatePosition,
          onError: (error) {
            _setState(GpsState.error, error.toString());
          },
        );
  }

  /// Arrête le suivi GPS
  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _streamUsesEnergySaving = null;

    _setState(GpsState.stopped);

    _currentPosition = null;
    _currentSpeed = 0.0;
    _currentAccuracy = 0.0;
  }

  /// Libère les ressources
  @override
  Future<void> dispose() async {
    await stop();
    await _positionController.close();
    await _stateController.close();
    super.dispose();
  }

  /// Obtient la position actuelle une seule fois (sans démarrer le flux)
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      _setState(GpsState.error, e.toString());
      return null;
    }
  }

  /// Calcule la distance entre deux points en mètres
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calcule le cap entre deux points en degrés
  static double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Réinitialise l'état d'erreur
  void clearError() {
    if (_state == GpsState.error) {
      _setState(GpsState.stopped);
    }
  }
}
