import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Gestionnaire centralisé des ressources pour éviter les fuites mémoire
class ResourceManager {
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  final List<AudioPlayer> _audioPlayers = [];
  final List<VoidCallback> _disposeCallbacks = [];

  /// Ajoute un StreamSubscription à gérer
  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Ajoute un Timer à gérer
  void addTimer(Timer timer) {
    _timers.add(timer);
  }

  /// Ajoute un AudioPlayer à gérer
  void addAudioPlayer(AudioPlayer player) {
    _audioPlayers.add(player);
  }

  /// Ajoute un callback de dispose personnalisé
  void addDisposeCallback(VoidCallback callback) {
    _disposeCallbacks.add(callback);
  }

  /// Annule un timer spécifique
  void cancelTimer(Timer? timer) {
    if (timer != null) {
      timer.cancel();
      _timers.remove(timer);
    }
  }

  /// Annule un abonnement spécifique
  void cancelSubscription(StreamSubscription? subscription) {
    if (subscription != null) {
      subscription.cancel();
      _subscriptions.remove(subscription);
    }
  }

  /// Dispose un AudioPlayer spécifique
  void disposeAudioPlayer(AudioPlayer? player) {
    if (player != null) {
      player.dispose();
      _audioPlayers.remove(player);
    }
  }

  /// Libère toutes les ressources
  void disposeAll() {
    // Annuler tous les timers
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    // Annuler tous les abonnements
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Disposer tous les joueurs audio
    for (final player in _audioPlayers) {
      player.dispose();
    }
    _audioPlayers.clear();

    // Exécuter les callbacks personnalisés
    for (final callback in _disposeCallbacks) {
      try {
        callback();
      } catch (e) {
        // Ignorer les erreurs dans les callbacks
      }
    }
    _disposeCallbacks.clear();
  }

  /// Vérifie si des ressources sont actives
  bool get hasActiveResources =>
      _timers.isNotEmpty ||
      _subscriptions.isNotEmpty ||
      _audioPlayers.isNotEmpty;

  /// Obtient le nombre de ressources actives
  int get resourceCount =>
      _timers.length + _subscriptions.length + _audioPlayers.length;
}
