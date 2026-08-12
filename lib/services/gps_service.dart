import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../app_settings.dart';
import '../models/waypoint.dart';

/// Service centralisé pour la gestion GPS et les calculs de distance
class GpsService {
  // Stream subscription pour le flux GPS adaptatif
  static StreamSubscription<Position>? _adaptivePositionSubscription;

  // Variables pour le suivi de la vitesse et l'adaptation
  static double _currentSpeed = 0.0;
  static bool _isStationary = true;
  static const double _stationaryThreshold =
      0.5; // 0.5 m/s (~1.8 km/h ou ~1 nœud)

  // Callback pour notifier main.dart des changements de position
  static Function(Position)? _onPositionUpdate;

  /// Calcule la distance en mètres entre deux points géographiques
  /// Formule de Haversine pour calcul précis
  static double calculateDistance(LatLng from, Waypoint to) {
    const R = 6371000.0; // Rayon de la Terre en mètres
    final dLat = _toRad(to.latitude - from.latitude);
    final dLon = _toRad(to.longitude - from.longitude);
    final a =
        pow(sin(dLat / 2), 2) +
        cos(_toRad(from.latitude)) *
            cos(_toRad(to.latitude)) *
            pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Convertit les degrés en radians
  static double _toRad(double deg) => deg * pi / 180;

  /// Formate la distance selon les préférences utilisateur
  static String formatDistance(double meters) {
    if (AppSettings.distanceUnit == DistanceUnit.nautical) {
      final nm = meters / 1852;
      return '${nm.toStringAsFixed(2)} nm';
    }

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Formate la distance spécifique au type de waypoint
  static String formatDistanceForWaypoint(double meters, Waypoint waypoint) {
    // Champignons : toujours en mètres/kilomètres
    if (waypoint.category == WaypointCategory.mushrooms) {
      if (meters < 1000) {
        return '${meters.toStringAsFixed(0)} m';
      }
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    // Pêche et autres : respecte le choix utilisateur
    return formatDistance(meters);
  }

  /// Détermine le statut GPS selon la précision
  /// Seuils unifiés pour toute l'application :
  /// - 0-8m : Vert (Excellent)
  /// - 8-15m : Jaune/Ambre (Correct)
  /// - 15-30m : Orange (Moyen)
  /// - >30m : Rouge (Faible)
  static GpsStatus getGpsStatus(double accuracy) {
    if (accuracy < 8) {
      return GpsStatus.excellent;
    } else if (accuracy < 15) {
      return GpsStatus.good;
    } else if (accuracy < 30) {
      return GpsStatus.medium;
    } else {
      return GpsStatus.poor;
    }
  }

  /// Obtient la couleur correspondant au statut GPS
  static Color getGpsStatusColor(GpsStatus status) {
    switch (status) {
      case GpsStatus.excellent:
        return Colors.green;
      case GpsStatus.good:
        return Colors.amber;
      case GpsStatus.medium:
        return Colors.orange;
      case GpsStatus.poor:
        return Colors.red;
    }
  }

  /// Obtient le texte du statut GPS pour l'affichage principal
  static String getGpsStatusText(GpsStatus status) {
    switch (status) {
      case GpsStatus.excellent:
        return 'SIGNAL EXCELLENT';
      case GpsStatus.good:
        return 'SIGNAL OK';
      case GpsStatus.medium:
        return 'RECHERCHE SATELLITES...';
      case GpsStatus.poor:
        return 'SIGNAL FAIBLE';
    }
  }

  /// Obtient le texte du statut GPS détaillé (pour les indicateurs techniques)
  static String getGpsDetailedStatusText(GpsStatus status) {
    switch (status) {
      case GpsStatus.excellent:
        return 'GPS EXCELLENT';
      case GpsStatus.good:
        return 'GPS CORRECT';
      case GpsStatus.medium:
        return 'GPS MOYEN';
      case GpsStatus.poor:
        return 'GPS FAIBLE';
    }
  }

  /// Fonction unifiée pour obtenir la couleur directement depuis la précision
  static Color getAccuracyColor(double? accuracy) {
    if (accuracy == null) {
      return Colors.grey;
    }
    final status = getGpsStatus(accuracy);
    return getGpsStatusColor(status);
  }

  /// Fonction unifiée pour obtenir le texte directement depuis la précision
  static String getAccuracyStatusText(double? accuracy) {
    if (accuracy == null) {
      return 'GPS: --';
    }
    final status = getGpsStatus(accuracy);
    return getGpsStatusText(status);
  }

  /// Fonction unifiée pour obtenir le texte technique depuis la précision
  static String getAccuracyDetailedText(double? accuracy) {
    if (accuracy == null) {
      return 'GPS: --';
    }
    final status = getGpsStatus(accuracy);
    return getGpsDetailedStatusText(status);
  }

  /// Crée les paramètres de localisation selon le mode économie d'énergie
  static LocationSettings getLocationSettings() {
    return LocationSettings(
      accuracy: AppSettings.energySavingMode
          ? LocationAccuracy.low
          : LocationAccuracy.high,
      distanceFilter: AppSettings.energySavingMode ? 15 : 0,
    );
  }

  /// Démarre le flux GPS adaptatif avec gestion automatique selon la vitesse
  ///
  /// Ce système adapte automatiquement la fréquence des mises à jour GPS
  /// en fonction de la vitesse de l'utilisateur :
  /// - Mode Stationnaire (Vitesse < 0.5 m/s) : économie de batterie
  /// - Mode Mobile (Vitesse >= 0.5 m/s) : haute précision continue
  static Future<void> startAdaptiveGpsTracking({
    required Function(Position) onPositionUpdate,
    Function(String)? onError,
  }) async {
    _onPositionUpdate = onPositionUpdate;

    try {
      // Vérifier si le service GPS est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError?.call('GPS DÉSACTIVÉ');
        return;
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          onError?.call('PERMISSION REFUSÉE');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        onError?.call('PERMISSION REFUSÉE');
        return;
      }

      // Obtenir la position initiale
      Position initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentSpeed = initialPosition.speed;
      _isStationary = _currentSpeed < _stationaryThreshold;

      // Notifier de la position initiale
      _onPositionUpdate?.call(initialPosition);

      // Démarrer le flux adaptatif
      _adaptivePositionSubscription =
          Geolocator.getPositionStream(
            locationSettings: _getAdaptiveLocationSettings(),
          ).listen(
            (Position position) {
              _updateSpeedAndAdapt(position);
              _onPositionUpdate?.call(position);
            },
            onError: (error) {
              onError?.call('ERREUR GPS: $error');
            },
          );
    } catch (e) {
      onError?.call('ERREUR GPS: $e');
    }
  }

  /// Arrête le flux GPS adaptatif
  static void stopAdaptiveGpsTracking() {
    _adaptivePositionSubscription?.cancel();
    _adaptivePositionSubscription = null;
    _onPositionUpdate = null;
  }

  /// Met à jour la vitesse et adapte les paramètres GPS si nécessaire
  static void _updateSpeedAndAdapt(Position position) {
    _currentSpeed = position.speed;
    final newIsStationary = _currentSpeed < _stationaryThreshold;

    // Si le mode change, redémarrer le flux avec les nouveaux paramètres
    if (newIsStationary != _isStationary) {
      _isStationary = newIsStationary;
      _restartStreamWithAdaptiveSettings();
    }
  }

  /// Redémarre le flux GPS avec les paramètres adaptés
  static void _restartStreamWithAdaptiveSettings() {
    _adaptivePositionSubscription?.cancel();

    _adaptivePositionSubscription =
        Geolocator.getPositionStream(
          locationSettings: _getAdaptiveLocationSettings(),
        ).listen((Position position) {
          _updateSpeedAndAdapt(position);
          _onPositionUpdate?.call(position);
        });
  }

  /// Obtient les paramètres de localisation adaptés selon la vitesse actuelle
  static LocationSettings _getAdaptiveLocationSettings() {
    if (_isStationary) {
      // Mode Stationnaire : économie de batterie
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Mise à jour tous les 10 mètres
      );
    } else {
      // Mode Mobile : haute précision continue
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // Mise à jour continue
      );
    }
  }

  /// Obtient la vitesse actuelle en m/s
  static double get currentSpeed => _currentSpeed;

  /// Indique si l'utilisateur est actuellement en mode stationnaire
  static bool get isStationary => _isStationary;

  /// Obtient le mode GPS actuel sous forme de texte
  static String getGpsModeText() {
    return _isStationary
        ? 'MODE ÉCO (STATIONNAIRE)'
        : 'MODE HAUTE PRÉCISION (MOBILE)';
  }
}

/// Énumération des statuts GPS possibles
enum GpsStatus { excellent, good, medium, poor }
