import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../app_settings.dart';
import '../models/waypoint.dart';
import '../controllers/gps_controller.dart';

/// Logs de debugging alarme. Laisser à false.
const bool kVerboseAlarm = false;

/// Type d'événement émis par [AlarmService].
enum AlarmEventType {
  /// L'état d'affichage de l'icône haut-parleur a changé. Payload: [bool].
  speakerIconChanged,

  /// Un cycle d'alarme de proximité a été déclenché (zone X/Y/Z active,
  /// au rythme de la zone).
  ///
  /// SÉMANTIQUE VERROUILLÉE : cet événement signifie « le cycle d'alarme
  /// a été déclenché », PAS « un son a été joué ». La vérité audio est
  /// portée par le payload : [AlarmEvent.soundPlayed] (`true` = bip
  /// réellement produit, `false` = mode muet actif ou échec de lecture).
  alarmTriggered,

  /// L'état muet a changé. Payload: [bool].
  mutedChanged,

  /// Le monitoring a démarré sur un waypoint.
  monitoringStarted,

  /// Le monitoring a été arrêté.
  monitoringStopped,
}

/// Événement diffusé par [AlarmService] via son [Stream].
class AlarmEvent {
  final AlarmEventType type;
  final dynamic payload;

  AlarmEvent._(this.type, [this.payload]);

  factory AlarmEvent.speakerIconChanged(bool show) =>
      AlarmEvent._(AlarmEventType.speakerIconChanged, show);

  /// [soundPlayed] : `true` si un bip a réellement été produit,
  /// `false` si le mode muet est actif ou si la lecture a échoué.
  factory AlarmEvent.alarmTriggered({bool soundPlayed = false}) =>
      AlarmEvent._(AlarmEventType.alarmTriggered, soundPlayed);

  factory AlarmEvent.mutedChanged(bool muted) =>
      AlarmEvent._(AlarmEventType.mutedChanged, muted);

  factory AlarmEvent.monitoringStarted(Waypoint target) =>
      AlarmEvent._(AlarmEventType.monitoringStarted, target);

  factory AlarmEvent.monitoringStopped() =>
      AlarmEvent._(AlarmEventType.monitoringStopped);

  bool get boolPayload => payload as bool;

  /// Pour [AlarmEventType.alarmTriggered] : `true` si un son a réellement
  /// été joué, `false` si muet ou échec de lecture.
  bool get soundPlayed => payload == true;

  Waypoint get waypointPayload => payload as Waypoint;
}

enum _PlayerState { uninitialized, initializing, ready, failed }

class AlarmService {
  static Timer? _proximityTimer;
  static AudioPlayer? _proximityPlayer;
  static final AudioCache _audioCache = AudioCache(prefix: 'sounds/');
  static Waypoint? _targetWaypoint;
  static LatLng? _currentPosition;
  static String? _lastProximityZone;
  static bool _showSpeakerIcon = false;
  static bool _isMuted = false;
  static bool _isNavigationActive = false;
  static bool _isProcessingAlarm = false;
  static int _alarmGeneration = 0;

  /// Vrai si un [play] a réussi et n'a pas encore été suivi d'un [stop].
  static bool _isPlayerStarted = false;
  static _PlayerState _playerState = _PlayerState.uninitialized;

  static final StreamController<AlarmEvent> _alarmEventController =
      StreamController<AlarmEvent>.broadcast();

  /// Flux broadcast d'événements d'alarme. Multi-abonnements autorisés.
  static Stream<AlarmEvent> get onAlarmEvent => _alarmEventController.stream;

  /// Initialise le service d'alarme.
  static Future<void> initialize() async {
    if (_playerState == _PlayerState.initializing ||
        _playerState == _PlayerState.ready) {
      return;
    }

    _playerState = _PlayerState.initializing;

    if (_proximityPlayer != null) {
      try {
        await _proximityPlayer!.dispose();
      } catch (_) {}
      _proximityPlayer = null;
    }

    _isPlayerStarted = false;

    try {
      _proximityPlayer = AudioPlayer();
      await _proximityPlayer!.setVolume(1.0);
      await _proximityPlayer!.setReleaseMode(ReleaseMode.stop);

      _playerState = _PlayerState.ready;
    } catch (e) {
      if (kVerboseAlarm) {
        debugPrint('[AlarmService] init player failed: $e');
      }
      _playerState = _PlayerState.failed;
      _proximityPlayer = null;
    }
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
    _emit(AlarmEvent.monitoringStarted(target));
    _updateProximityAlarm();
  }

  /// Arrête explicitement le monitoring
  static void stopMonitoring() {
    _isNavigationActive = false;
    _targetWaypoint = null;
    _emit(AlarmEvent.monitoringStopped());
    _stopProximityAlarm();
  }

  /// Émet un événement sur le flux broadcast (safe si déjà fermé).
  static void _emit(AlarmEvent event) {
    if (!_alarmEventController.isClosed) {
      _alarmEventController.add(event);
    }
  }

  /// Stoppe le player en toute sécurité.
  static void _safeStopPlayer() {
    final p = _proximityPlayer;
    if (p == null || !_isPlayerStarted) return;
    _isPlayerStarted = false;
    p.stop().catchError((Object _) {});
  }

  /// Arrête l'alarme de proximité et nettoie les ressources associées.
  static void _stopProximityAlarm() {
    _proximityTimer?.cancel();
    _proximityTimer = null;
    _lastProximityZone = null;
    _alarmGeneration++;
    if (_showSpeakerIcon) {
      _showSpeakerIcon = false;
      _emit(AlarmEvent.speakerIconChanged(false));
    }
    _safeStopPlayer();
  }

  /// Met à jour l'alarme de proximité selon la distance actuelle au waypoint
  static void _updateProximityAlarm() {
    if (_isProcessingAlarm) return;
    _isProcessingAlarm = true;
    try {
      if (!_isNavigationActive ||
          _targetWaypoint == null ||
          _currentPosition == null ||
          !AppSettings.proximityAlarmEnabled) {
        _stopProximityAlarm();
        return;
      }

      final d = _distanceInMeters(_currentPosition!, _targetWaypoint!);
      final x = AppSettings.proximityDistanceX;
      final y = AppSettings.proximityDistanceY;
      final z = AppSettings.proximityDistanceZ;

      if (d > x) {
        _stopProximityAlarm();
        return;
      }

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

      if (_lastProximityZone != zone) {
        _lastProximityZone = zone;
        if (!_showSpeakerIcon) {
          _showSpeakerIcon = true;
          _emit(AlarmEvent.speakerIconChanged(true));
        }
        _proximityTimer?.cancel();
        _proximityTimer = Timer(period, () => _scheduleNextBeep(period));
      }
    } finally {
      _isProcessingAlarm = false;
    }
  }

  static void _scheduleNextBeep(Duration period) {
    if (_targetWaypoint == null ||
        _currentPosition == null ||
        !AppSettings.proximityAlarmEnabled) {
      _stopProximityAlarm();
      return;
    }
    final dist = _distanceInMeters(_currentPosition!, _targetWaypoint!);
    final x = AppSettings.proximityDistanceX;
    if (dist > x) {
      _stopProximityAlarm();
      _showSpeakerIcon = false;
      _emit(AlarmEvent.speakerIconChanged(false));
      return;
    }

    _isPlayerStarted = true;
    final generation = _alarmGeneration;

    _safePlayBeep()
        .then((soundPlayed) {
          _emit(AlarmEvent.alarmTriggered(soundPlayed: soundPlayed));
        })
        .whenComplete(() {
          _isPlayerStarted = false;
          if (generation != _alarmGeneration) {
            if (kVerboseAlarm) {
              debugPrint(
                '[AlarmService] whenComplete: generation mismatch '
                '($generation != $_alarmGeneration) → skipping reschedule',
              );
            }
            return;
          }
          _proximityTimer = Timer(period, () => _scheduleNextBeep(period));
        });
  }

  /// Joue le bip en toute sécurité.
  static Future<bool> _safePlayBeep() async {
    if (_isMuted) return false;
    if (_playerState != _PlayerState.ready) {
      await initialize();
      if (_playerState != _PlayerState.ready) return false;
    }

    try {
      final p = _proximityPlayer!;
      _isPlayerStarted = true;
      final source = await _audioCache.load('beep.mp3');
      await p.play(DeviceFileSource(source.path));

      return true;
    } catch (e) {
      if (kVerboseAlarm) {
        debugPrint('[AlarmService] beep échoué: $e → reset du player');
      }
      _isPlayerStarted = false;

      // En cas d'échec, on force une réinitialisation au prochain bip
      _playerState = _PlayerState.failed;
      try {
        await _proximityPlayer?.dispose();
      } catch (_) {}
      _proximityPlayer = null;

      return false;
    }
  }

  /// Calcule la distance en mètres entre deux points GPS
  static double _distanceInMeters(LatLng from, Waypoint to) {
    return GpsController.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  static bool get showSpeakerIcon => _showSpeakerIcon;

  static bool get isMuted => _isMuted;

  static void setMuted(bool muted) {
    _isMuted = muted;
    _emit(AlarmEvent.mutedChanged(muted));
  }

  static void toggleMuted() {
    _isMuted = !_isMuted;
    _emit(AlarmEvent.mutedChanged(_isMuted));
  }

  /// Libère les ressources du service liées au monitoring.
  static Future<void> dispose() async {
    _stopProximityAlarm();
    final p = _proximityPlayer;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
      try {
        await p.dispose();
      } catch (_) {}
      _proximityPlayer = null;
    }
    _isPlayerStarted = false;
    _playerState = _PlayerState.uninitialized;
  }
}
