import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

/// Service centralisé pour la gestion audio et des alarmes de proximité
class AudioService {
  late final AudioPlayer _player;
  Timer? _proximityTimer;
  String? _lastProximityZone;

  /// Initialise le service audio
  Future<void> initialize() async {
    _player = AudioPlayer();
    await _player.setVolume(1.0);
    await _player.setReleaseMode(ReleaseMode.stop);
    
    // Pré-charger le son pour éviter les délais
    try {
      await _player.setSource(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      // Silencieux en cas d'erreur
    }
  }

  /// Démarre l'alarme de proximité avec la période spécifiée
  void startProximityAlarm({
    required Duration period,
    required VoidCallback onTimerTick,
  }) {
    // Annuler l'ancien timer s'il existe
    _proximityTimer?.cancel();
    
    _proximityTimer = Timer.periodic(period, (timer) {
      onTimerTick();
    });
  }

  /// Joue un bip avec retour haptique
  Future<void> playBeep() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/beep.mp3'));
      HapticFeedback.vibrate(); // Retour physique cohérent
    } catch (e) {
      // Silencieux en cas d'erreur
    }
  }

  /// Arrête l'alarme de proximité
  void stopProximityAlarm() {
    _proximityTimer?.cancel();
    _proximityTimer = null;
    _player.stop();
    _lastProximityZone = null;
  }

  /// Met à jour la zone de proximité (évite les changements inutiles)
  bool updateProximityZone(String newZone) {
    if (_lastProximityZone != newZone) {
      _lastProximityZone = newZone;
      return true; // La zone a changé
    }
    return false; // Même zone, pas de changement
  }

  /// Obtient la période d'alarme selon la zone de proximité
  static Duration getProximityPeriod(String zone) {
    switch (zone) {
      case 'Z':
        return const Duration(milliseconds: 500); // Bip continu
      case 'Y':
        return const Duration(milliseconds: 1000); // Bip-bip
      case 'X':
        return const Duration(seconds: 4); // Bip lent
      default:
        return const Duration(seconds: 4);
    }
  }

  /// Libère les ressources audio
  void dispose() {
    _proximityTimer?.cancel();
    _player.dispose();
  }
}
