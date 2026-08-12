import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:latlong2/latlong.dart';

import '../app_settings.dart';
import '../models/waypoint.dart';

/// Service centralisé pour la gestion des alarmes de proximité
/// Gère les zones X, Y, Z avec différents fréquences de bip
class AlarmService {
  static Timer? _proximityTimer;
  static AudioPlayer? _proximityPlayer;
  static Waypoint? _targetWaypoint;
  static LatLng? _currentPosition;
  static String? _lastProximityZone;
  static bool _showSpeakerIcon = false;
  static bool _isMuted = false;
  static bool _isNavigationActive = false; // Indicateur de navigation active

  // Callbacks pour notifier l'UI
  static Function(bool)? _onSpeakerIconChanged;
  static Function()? _onAlarmTriggered;
  static Function(bool)? _onMutedChanged;

  /// Initialise le service d'alarme
  static Future<void> initialize() async {
    _proximityPlayer = AudioPlayer();
    await _proximityPlayer?.setVolume(1.0);
    await _proximityPlayer?.setReleaseMode(ReleaseMode.stop);

    // Pré-charger le son pour éviter les délais
    try {
      await _proximityPlayer?.setSource(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      // Silencieux en cas d'erreur
    }
  }

  /// Définit les callbacks pour notifier l'UI
  static void setCallbacks({
    Function(bool)? onSpeakerIconChanged,
    Function()? onAlarmTriggered,
    Function(bool)? onMutedChanged,
  }) {
    _onSpeakerIconChanged = onSpeakerIconChanged;
    _onAlarmTriggered = onAlarmTriggered;
    _onMutedChanged = onMutedChanged;
  }

  /// Met à jour la position actuelle depuis le flux GPS principal
  static void updatePosition(LatLng position) {
    _currentPosition = position;
    _updateProximityAlarm();
  }

  /// Démarre explicitement le monitoring pour un waypoint de navigation
  static void startMonitoring(Waypoint target) {
    _targetWaypoint = target;
    _isNavigationActive = true;
    _updateProximityAlarm();
  }

  /// Arrête explicitement le monitoring
  static void stopMonitoring() {
    _isNavigationActive = false;
    _targetWaypoint = null;
    _stopProximityAlarm();
  }

  /// Définit le waypoint cible pour les alarmes (méthode obsolète, utiliser startMonitoring)
  static void setTargetWaypoint(Waypoint? waypoint) {
    _targetWaypoint = waypoint;
    _updateProximityAlarm();
  }

  /// Met à jour l'alarme de proximité selon la distance actuelle au waypoint
  /// Gère 3 zones d'alarme avec différentes fréquences de bip
  /// - Zone Z (≤5m) : bip continu toutes les 500ms
  /// - Zone Y (≤20m) : bip-bip toutes les 2s
  /// - Zone X (≤100m) : bip lent toutes les 4s
  static Future<void> _updateProximityAlarm() async {
    // Ne déclencher l'alarme que si la navigation est explicitement active
    if (!_isNavigationActive ||
        _targetWaypoint == null ||
        _currentPosition == null ||
        !AppSettings.proximityAlarmEnabled) {
      _stopProximityAlarm();
      if (_showSpeakerIcon) {
        _showSpeakerIcon = false;
        _onSpeakerIconChanged?.call(false);
      }
      return;
    }

    // Calcul de la distance et définition des zones de proximité
    final d = _distanceInMeters(_currentPosition!, _targetWaypoint!);
    final x =
        AppSettings.proximityDistanceX; // Zone extérieure (100m par défaut)
    final y =
        AppSettings.proximityDistanceY; // Zone intermédiaire (20m par défaut)
    final z = AppSettings.proximityDistanceZ; // Zone proche (5m par défaut)

    // Silence total si hors de la zone X (plus de 100m par défaut)
    if (d > x) {
      if (_showSpeakerIcon) {
        _showSpeakerIcon = false;
        _onSpeakerIconChanged?.call(false);
      }
      _stopProximityAlarm();
      return;
    }

    // Détermination de la zone de proximité et période de bip associée
    Duration period;
    String zone;

    if (d <= z) {
      zone = 'Z';
      period = const Duration(milliseconds: 500);
    } else if (d <= y) {
      zone = 'Y';
      period = const Duration(seconds: 2);
    } else {
      zone = 'X';
      period = const Duration(seconds: 4);
    }

    // Optimisation : ne recréer le timer que si la zone de proximité change
    if (_lastProximityZone != zone) {
      _lastProximityZone = zone;

      // Afficher l'icône de haut-parleur
      if (!_showSpeakerIcon) {
        _showSpeakerIcon = true;
        _onSpeakerIconChanged?.call(true);
      }

      // Annuler l'ancien timer avant d'en créer un nouveau
      _proximityTimer?.cancel();
      _proximityTimer = Timer.periodic(period, (timer) async {
        if (_targetWaypoint == null ||
            _currentPosition == null ||
            !AppSettings.proximityAlarmEnabled) {
          _stopProximityAlarm();
          return;
        }

        // Vérification continue de la distance à chaque tick du timer
        final dist = _distanceInMeters(_currentPosition!, _targetWaypoint!);
        if (dist > x) {
          _stopProximityAlarm();
          _showSpeakerIcon = false;
          _onSpeakerIconChanged?.call(false);
          return;
        }

        // Synchronisation audio pour une meilleure expérience utilisateur
        try {
          // Ne jouer le son que si non muet
          if (!_isMuted) {
            await _proximityPlayer?.stop();
            await _proximityPlayer?.play(AssetSource('sounds/beep.mp3'));
          }
          _onAlarmTriggered?.call();
        } catch (e) {
          // Gestion silencieuse des erreurs audio
        }
      });
    }
  }

  /// Arrête l'alarme de proximité et nettoie les ressources associées
  static void _stopProximityAlarm() {
    _proximityTimer?.cancel();
    _proximityTimer = null;
    _proximityPlayer?.stop();
    _lastProximityZone = null;
  }

  /// Calcule la distance en mètres entre deux points GPS
  static double _distanceInMeters(LatLng from, Waypoint to) {
    const R = 6371000.0;
    final dLat = _toRad(to.latitude - from.latitude);
    final dLon = _toRad(to.longitude - from.longitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(from.latitude)) *
            cos(_toRad(to.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Convertit des degrés en radians
  static double _toRad(double deg) => deg * pi / 180;

  /// Indique si l'icône de haut-parleur doit être affichée
  static bool get showSpeakerIcon => _showSpeakerIcon;

  /// Indique si le son est coupé
  static bool get isMuted => _isMuted;

  /// Coupe ou réactive le son
  static void setMuted(bool muted) {
    _isMuted = muted;
    _onMutedChanged?.call(muted);
  }

  /// Bascule l'état muet
  static void toggleMuted() {
    _isMuted = !_isMuted;
    _onMutedChanged?.call(_isMuted);
  }

  /// Libère les ressources du service
  static void dispose() {
    _proximityTimer?.cancel();
    _proximityPlayer?.dispose();
    _proximityPlayer = null;
  }
}
