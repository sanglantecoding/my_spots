import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../app_settings.dart';
import '../models/waypoint.dart';
import '../controllers/gps_controller.dart';

/// Type d'événement émis par [AlarmService].
enum AlarmEventType {
  /// L'état d'affichage de l'icône haut-parleur a changé. Payload: [bool].
  speakerIconChanged,

  /// Un bip d'alarme a été déclenché (au rythme de la zone).
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

  factory AlarmEvent.alarmTriggered() =>
      AlarmEvent._(AlarmEventType.alarmTriggered);

  factory AlarmEvent.mutedChanged(bool muted) =>
      AlarmEvent._(AlarmEventType.mutedChanged, muted);

  factory AlarmEvent.monitoringStarted(Waypoint target) =>
      AlarmEvent._(AlarmEventType.monitoringStarted, target);

  factory AlarmEvent.monitoringStopped() =>
      AlarmEvent._(AlarmEventType.monitoringStopped);

  bool get boolPayload => payload as bool;
  Waypoint get waypointPayload => payload as Waypoint;
}

/// Service centralisé pour la gestion des alarmes de proximité.
///
/// Gère les zones X, Y, Z avec différentes fréquences de bip.
class AlarmService {
  static Timer? _proximityTimer;
  static AudioPlayer? _proximityPlayer;
  static Waypoint? _targetWaypoint;
  static LatLng? _currentPosition;
  static String? _lastProximityZone;
  static bool _showSpeakerIcon = false;
  static bool _isMuted = false;
  static bool _isNavigationActive = false;
  static bool _isProcessingAlarm = false;
  static bool _isPlayingAudio = false;

  // ✅ NOUVEAU : indique si le player a déjà été démarré.
  // Évite de stopper un player jamais démarré (bruit MediaPlayer inutile).
  static bool _isPlayerStarted = false;
  static bool _isInitialized = false;

  static final StreamController<AlarmEvent> _alarmEventController =
      StreamController<AlarmEvent>.broadcast();

  /// Flux broadcast d'événements d'alarme. Multi-abonnements autorisés.
  static Stream<AlarmEvent> get onAlarmEvent => _alarmEventController.stream;

  /// Initialise le service d'alarme.
  ///
  /// ✅ CORRECTION : on ne précharge PLUS le son avec setSource() ici.
  /// Le préchargement déclenchait une boucle getDuration/seekTo du MediaPlayer
  /// Android qui polluait les logs. Le son est joué à la demande dans
  /// [_safePlayBeep] uniquement quand l'alarme sonne réellement.
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    if (_proximityPlayer != null) {
      try {
        await _proximityPlayer!.dispose();
      } catch (_) {}
      _proximityPlayer = null;
    }
    _proximityPlayer = AudioPlayer();
    try {
      await _proximityPlayer!.setVolume(1.0);
      await _proximityPlayer!.setReleaseMode(ReleaseMode.stop);
      // ⚠️ PAS de setSource() ici : le préchargement laissait le player
      // dans un état où le play() suivant échouait silencieusement.
    } catch (e) {
      debugPrint('[AlarmService] init player: $e');
    }
  }

  @Deprecated('Utilisez AlarmService.onAlarmEvent (Stream multi-abonnés)')
  static void setCallbacks({
    Function(bool)? onSpeakerIconChanged,
    Function()? onAlarmTriggered,
    Function(bool)? onMutedChanged,
  }) {
    onAlarmEvent.listen((event) {
      switch (event.type) {
        case AlarmEventType.speakerIconChanged:
          onSpeakerIconChanged?.call(event.boolPayload);
          break;
        case AlarmEventType.alarmTriggered:
          onAlarmTriggered?.call();
          break;
        case AlarmEventType.mutedChanged:
          onMutedChanged?.call(event.boolPayload);
          break;
        // ignore: no_default_cases
        default:
          break;
      }
    });
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

  /// Définit le waypoint cible pour les alarmes
  static void setTargetWaypoint(Waypoint? waypoint) {
    _targetWaypoint = waypoint;
    _updateProximityAlarm();
  }

  /// Émet un événement sur le flux broadcast (safe si déjà fermé).
  static void _emit(AlarmEvent event) {
    if (!_alarmEventController.isClosed) {
      _alarmEventController.add(event);
    }
  }

  /// Vrai si le player existe ET a déjà été démarré.
  static bool get _hasActivePlayer =>
      _proximityPlayer != null && _isPlayerStarted;

  /// Stoppe le player en toute sécurité.
  ///
  /// ✅ CORRECTION : on ne stoppe que si le player a réellement été démarré,
  /// pour éviter de stopper un player à l'arrêt à chaque tick GPS
  /// (ce qui déclenchait la boucle getDuration/seekTo du MediaPlayer).
  static Future<void> _safeStopPlayer() async {
    if (!_hasActivePlayer) return;
    try {
      await _proximityPlayer!.stop();
    } catch (_) {}
    _isPlayerStarted = false;
  }

  /// Joue le bip en toute sécurité, à la demande uniquement.
  static Future<void> _safePlayBeep() async {
    if (_isMuted) return;
    try {
      var p = _proximityPlayer;
      if (p == null) {
        p = _proximityPlayer = AudioPlayer();
        await p.setVolume(1.0);
        await p.setReleaseMode(ReleaseMode.stop);
      }
      // play(source) remet à zéro et joue : pas besoin de stop() avant.
      await p.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      debugPrint('[AlarmService] beep échoué: $e → recréation du player');
      try {
        await _proximityPlayer?.dispose();
      } catch (_) {}
      _proximityPlayer = null; // sera recréé au prochain bip
    }
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
        // ✅ CORRECTION : on ne stoppe que si quelque chose tourne réellement,
        // pour éviter de re-stopper un player à l'arrêt à chaque tick GPS.
        if (_proximityTimer != null || _lastProximityZone != null) {
          _stopProximityAlarm();
        }
        if (_showSpeakerIcon) {
          _showSpeakerIcon = false;
          _emit(AlarmEvent.speakerIconChanged(false));
        }
        return;
      }

      final d = _distanceInMeters(_currentPosition!, _targetWaypoint!);
      final x = AppSettings.proximityDistanceX;
      final y = AppSettings.proximityDistanceY;
      final z = AppSettings.proximityDistanceZ;

      if (d > x) {
        if (_proximityTimer != null || _lastProximityZone != null) {
          _stopProximityAlarm();
        }
        if (_showSpeakerIcon) {
          _showSpeakerIcon = false;
          _emit(AlarmEvent.speakerIconChanged(false));
        }
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
        _proximityTimer = Timer.periodic(period, (timer) async {
          if (_targetWaypoint == null ||
              _currentPosition == null ||
              !AppSettings.proximityAlarmEnabled) {
            _stopProximityAlarm();
            return;
          }
          final dist = _distanceInMeters(_currentPosition!, _targetWaypoint!);
          if (dist > x) {
            _stopProximityAlarm();
            _showSpeakerIcon = false;
            _emit(AlarmEvent.speakerIconChanged(false));
            return;
          }
          if (_isPlayingAudio) return;
          _isPlayingAudio = true;
          try {
            await _safePlayBeep();
            _emit(AlarmEvent.alarmTriggered());
          } finally {
            _isPlayingAudio = false;
          }
        });
      }
    } finally {
      _isProcessingAlarm = false;
    }
  }

  /// Arrête l'alarme de proximité et nettoie les ressources associées
  static Future<void> _stopProximityAlarm() async {
    _proximityTimer?.cancel();
    _proximityTimer = null;
    await _safeStopPlayer();
    _lastProximityZone = null;
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
    _proximityTimer?.cancel();
    _proximityTimer = null;
    final p = _proximityPlayer;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
      try {
        await p.dispose();
      } catch (_) {}
      _proximityPlayer = null;
      _isPlayerStarted = false;
    }
    // NOTE: Le StreamController broadcast N'EST PAS fermé ici.
  }
}
