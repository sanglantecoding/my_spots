import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/waypoint.dart';
import 'gps_service.dart';
import 'dart:math';

/// Service pour le tri et la gestion des waypoints par distance
class WaypointSortService {
  /// Trie les waypoints par distance depuis la position actuelle
  static List<Waypoint> sortWaypointsByDistance(
    List<Waypoint> waypoints,
    LatLng? currentPosition,
  ) {
    if (currentPosition == null) {
      // Si pas de position, tri alphabétique par défaut
      return List<Waypoint>.from(waypoints)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    // Tri par distance croissante
    final sortedWaypoints = List<Waypoint>.from(waypoints);
    sortedWaypoints.sort((a, b) {
      final distanceA = GpsService.calculateDistance(currentPosition, a);
      final distanceB = GpsService.calculateDistance(currentPosition, b);
      return distanceA.compareTo(distanceB);
    });

    return sortedWaypoints;
  }

  /// Calcule la distance formatée pour l'affichage
  static String getFormattedDistance(
    LatLng? currentPosition,
    Waypoint waypoint,
  ) {
    if (currentPosition == null) {
      return 'Distance inconnue';
    }

    final distance = GpsService.calculateDistance(currentPosition, waypoint);
    return 'à ${_formatDistanceForDisplay(distance)}';
  }

  /// Formate la distance pour l'affichage dans les listes
  static String _formatDistanceForDisplay(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Détermine si le tri doit être rafraîchi
  static bool shouldRefreshSort(LatLng? oldPosition, LatLng? newPosition) {
    if (oldPosition == null || newPosition == null) return true;

    // Calcul de la distance entre les positions
    final distanceMoved = _calculateDistanceBetweenPositions(
      oldPosition,
      newPosition,
    );

    // Rafraîchir si l'utilisateur a bougé de plus de 100 mètres
    return distanceMoved > 100.0;
  }

  /// Calcule la distance entre deux positions LatLng
  static double _calculateDistanceBetweenPositions(LatLng pos1, LatLng pos2) {
    const double earthRadius = 6371000.0; // Rayon de la Terre en mètres
    final double dLat = _toRadians(pos2.latitude - pos1.latitude);
    final double dLon = _toRadians(pos2.longitude - pos1.longitude);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(pos1.latitude)) *
            cos(_toRadians(pos2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Convertit les degrés en radians
  static double _toRadians(double degrees) => degrees * pi / 180;

  /// Obtient une liste enrichie avec distances pour l'affichage
  static List<WaypointWithDistance> getWaypointsWithDistance(
    List<Waypoint> waypoints,
    LatLng? currentPosition,
  ) {
    final sortedWaypoints = sortWaypointsByDistance(waypoints, currentPosition);

    return sortedWaypoints.map((waypoint) {
      final distance = currentPosition != null
          ? GpsService.calculateDistance(currentPosition, waypoint)
          : null;

      return WaypointWithDistance(
        waypoint: waypoint,
        distance: distance,
        formattedDistance: distance != null
            ? 'à ${_formatDistanceForDisplay(distance)}'
            : 'Distance inconnue',
      );
    }).toList();
  }
}

/// Waypoint enrichi avec informations de distance
class WaypointWithDistance {
  final Waypoint waypoint;
  final double? distance;
  final String formattedDistance;

  WaypointWithDistance({
    required this.waypoint,
    this.distance,
    required this.formattedDistance,
  });

  /// Obtient la couleur selon la distance
  Color getDistanceColor() {
    if (distance == null) return Colors.grey;

    if (distance! < 100) return Colors.green;
    if (distance! < 500) return Colors.amber;
    if (distance! < 1000) return Colors.orange;
    return Colors.red;
  }

  /// Obtient l'icône selon la distance
  IconData getDistanceIcon() {
    if (distance == null) return Icons.help_outline;

    if (distance! < 100) return Icons.near_me;
    if (distance! < 500) return Icons.directions_walk;
    if (distance! < 1000) return Icons.directions;
    return Icons.directions_car;
  }
}
