import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../app_settings.dart';
import '../models/waypoint.dart';

/// Service utilitaire pour les calculs GPS et le formatage
///
/// Ce service ne contient que des fonctions pures pour:
/// - Calculs de distance
/// - Formatage d'affichage
/// - Détermination du statut GPS
///
/// Le suivi GPS actif est géré par GpsController
class GpsService {
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
}

/// Énumération des statuts GPS possibles
enum GpsStatus { excellent, good, medium, poor }
