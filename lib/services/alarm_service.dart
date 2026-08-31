import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
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

  /// Helper: obtenir le payload [bool] pour les événements typés.
  bool get boolPayload => payload as bool;

  /// Helper: obtenir le payload [Waypoint] pour monitoringStarted.
  Waypoint get waypointPayload => payload as Waypoint;
}

/// Service centralisé pour la gestion des alarmes de proximité.
///
/// Gère les zones X, Y, Z avec différentes fréquences de bip.
///
/// Les widgets s'abonnent via [onAlarmEvent] (broadcast Stream) plutôt
/// que via [setCallbacks] afin que plusieurs abonnés puissent écouter
/// simultanément sans s'écraser mutuellement.
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
  static bool _isInitialized = false;

  static final StreamController<AlarmEvent> _alarmEventController =
      StreamController<AlarmEvent>.broadcast();

  /// Flux broadcast d'événements d'alarme. Multi-abonnements autorisés.
  /// Ce stream reste ouvert pendant toute la session et n'est fermé
  /// que lors de la destruction finale de l'application.
  static Stream<AlarmEvent> get onAlarmEvent => _alarmEventController.stream;

  /// Initialise le service d'alarme.
  ///
  /// Cette méthode est idempotente : si le service est déjà initialisé,
  /// elle ne fait rien et ne recrée pas le player.
  ///
  /// Le [StreamController] broadcast reste ouvert pendant toute la session
  /// et ne doit jamais être fermé par les appels à [dispose].
  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;

    if (_proximityPlayer != null) {
      try {
        await _proximityPlayer!.stop();
      } catch (_) {}
      try {
        await _proximityPlayer!.dispose();
      } catch (_) {}
      _proximityPlayer = null;
    }

    _proximityPlayer = AudioPlayer();
    try {
      await _proximityPlayer?.setVolume(1.0);
      await _proximityPlayer?.setReleaseMode(ReleaseMode.stop);
      // Pré-charger le son pour éviter les délais
      await _proximityPlayer?.setSource(AssetSource('sounds/beep.mp3'));
    } catch (_) {
      // Silencieux en cas d'erreur
    }
  }

  /// @deprecated Utilisez [AlarmService.onAlarmEvent] (Stream multi-abonnés)
  /// plutôt que ces callbacks à inscription unique.
  ///
  /// Conservé temporairement pour la rétrocompatibilité : s'abonne
  /// au flux et relaie les événements aux closures fournies.
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
    // Calcul synchrone de la distance et mise à jour de l'alarme
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

  /// Définit le waypoint cible pour les alarmes (méthode obsolète, utiliser startMonitoring)
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

  /// Garantit que le player est disponible et actif (non null et non disposé).
  static bool get _hasActivePlayer => _proximityPlayer != null;

  /// Stop + dispose un player en toute sécurité, sans exception.
  static Future<void> _safeStopPlayer() async {
    final p = _proximityPlayer;
    if (p == null) return;
    try {
      await p.stop();
    } catch (_) {}
  }

  /// Joue le bip en toute sécurité (guarde les erreurs natives/état).
  static Future<void> _safePlayBeep() async {
    if (_isMuted) return;
    final p = _proximityPlayer;
    if (p == null) return;
    try {
      await p.stop();
      await p.play(AssetSource('sounds/beep.mp3'));
    } catch (_) {
      // Player disposé, source indisponible, etc.
    }
  }

  /// Met à jour l'alarme de proximité selon la distance actuelle au waypoint
  /// Gère 3 zones d'alarme avec différentes fréquences de bip
  /// - Zone Z (≤5m) : bip continu toutes les 500ms
  /// - Zone Y (≤20m) : bip-bip toutes les 2s
  /// - Zone X (≤100m) : bip lent toutes les 4s
  static void _updateProximityAlarm() {
    // Verrou d'exécution pour éviter la concurrence
    if (_isProcessingAlarm) return;
    _isProcessingAlarm = true;

    try {
      // Ne déclencher l'alarme que si la navigation est explicitement active
      if (!_isNavigationActive ||
          _targetWaypoint == null ||
          _currentPosition == null ||
          !AppSettings.proximityAlarmEnabled) {
        _stopProximityAlarm();
        if (_showSpeakerIcon) {
          _showSpeakerIcon = false;
          _emit(AlarmEvent.speakerIconChanged(false));
        }
        return;
      }

      // Calcul synchrone de la distance et définition des zones de proximité
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
          _emit(AlarmEvent.speakerIconChanged(false));
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
          _emit(AlarmEvent.speakerIconChanged(true));
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
            _emit(AlarmEvent.speakerIconChanged(false));
            return;
          }

          // Synchronisation audio pour une meilleure expérience utilisateur
          // Verrou pour éviter le chevauchement audio
          if (_isPlayingAudio) return;
          _isPlayingAudio = true;

          try {
            // Ne jouer le son que si non muet et player actif
            if (_hasActivePlayer) {
              await _safePlayBeep();
            }
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
    // Utiliser GpsController.distanceBetween pour la cohérence
    return GpsController.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Indique si l'icône de haut-parleur doit être affichée
  static bool get showSpeakerIcon => _showSpeakerIcon;

  /// Indique si le son est coupé
  static bool get isMuted => _isMuted;

  /// Coupe ou réactive le son
  static void setMuted(bool muted) {
    _isMuted = muted;
    _emit(AlarmEvent.mutedChanged(muted));
  }

  /// Bascule l'état muet
  static void toggleMuted() {
    _isMuted = !_isMuted;
    _emit(AlarmEvent.mutedChanged(_isMuted));
  }

  /// Libère les ressources du service liées au monitoring.
  ///
  /// Cette méthode ne ferme PAS le [StreamController] broadcast, car celui-ci
  /// est une ressource globale nécessaire au fonctionnement continu de
  /// l'application. Fermer le stream depuis un widget enfant (comme MapScreen)
  /// empêcherait tout abonnement futur.
  ///
  /// Ressources libérées :
  /// - Timer de proximité (annulé) ;
  /// - AudioPlayer (arrêté et disposé si existant).
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
    }

    // NOTE: Le StreamController broadcast N'EST PAS fermé ici.
    // Il reste disponible pour les prochains abonnements.
    // Le stream ne sera fermé que lors de la destruction finale de l'application.
  }
}
