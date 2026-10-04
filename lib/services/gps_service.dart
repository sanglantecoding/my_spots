import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../app_settings.dart';
import '../models/waypoint.dart';

/// Service utilitaire pour les calculs GPS et le formatage
class GpsService {
  static double distanceBetween(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final halfDLat = sin(dLat / 2);
    final halfDLon = sin(dLon / 2);
    final aVal =
        halfDLat * halfDLat +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * halfDLon * halfDLon;
    return R * 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
  }

  /// Distance entre deux coordonnées passées séparément (lat/lng).
  static double distanceBetweenCoords(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return distanceBetween(LatLng(lat1, lng1), LatLng(lat2, lng2));
  }

  /// Distance entre une position et un waypoint.
  static double distanceToWaypoint(LatLng from, Waypoint to) {
    return distanceBetween(from, LatLng(to.latitude, to.longitude));
  }

  /// Cap initial en degrés (0–360) du point 1 vers le point 2.
  static double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final lat1 = _toRad(startLatitude);
    final lat2 = _toRad(endLatitude);
    final dLon = _toRad(endLongitude - startLongitude);
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
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

  // ─── Statut GPS (source unique de vérité) ────────────────────────────────

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

  /// Couleur correspondant au statut GPS
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

  /// Texte du statut GPS pour l'affichage principal
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

  /// Texte du statut GPS détaillé (pour les indicateurs techniques)
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

  static String statusToLabel(GpsStatus status) => switch (status) {
    GpsStatus.excellent => 'Vert',
    GpsStatus.good => 'Jaune',
    GpsStatus.medium => 'Orange',
    GpsStatus.poor => 'Rouge',
  };

  static String getGpsStatusLabel(double? accuracy) =>
      accuracy == null ? 'Inconnu' : statusToLabel(getGpsStatus(accuracy));

  static GpsStatus? statusFromLabel(String? label) => switch (label) {
    'Vert' => GpsStatus.excellent,
    'Jaune' => GpsStatus.good,
    'Orange' => GpsStatus.medium,
    'Rouge' => GpsStatus.poor,
    _ => null,
  };

  /// Couleur depuis un libellé persisté ('Inconnu' → gris clair).
  static Color getColorForStatusLabel(String? label) {
    final status = statusFromLabel(label);
    if (status == null) return Colors.grey.shade300;
    return getGpsStatusColor(status);
  }

  /// Icône depuis un libellé persisté ('Inconnu' → point d'interrogation).
  static IconData getGpsStatusIcon(String? label) {
    final status = statusFromLabel(label);
    if (status == null) return Icons.help_outline;
    return switch (status) {
      GpsStatus.excellent || GpsStatus.good => Icons.gps_fixed,
      GpsStatus.medium => Icons.location_searching,
      GpsStatus.poor => Icons.gps_off,
    };
  }

  /// Description longue depuis un libellé persisté.
  static String getGpsStatusDescription(String? label) {
    final status = statusFromLabel(label);
    if (status == null) {
      return 'Signal inconnu (import sans métadonnées)';
    }
    return switch (status) {
      GpsStatus.excellent => 'Précision excellente',
      GpsStatus.good => 'Précision bonne',
      GpsStatus.medium => 'Précision moyenne',
      GpsStatus.poor => 'Précision faible',
    };
  }
}

/// Énumération des statuts GPS possibles
enum GpsStatus { excellent, good, medium, poor }
