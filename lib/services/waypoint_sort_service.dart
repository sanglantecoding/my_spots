import 'package:latlong2/latlong.dart';
import '../models/waypoint.dart';
import 'gps_service.dart';

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
      final distanceA = GpsService.distanceToWaypoint(currentPosition, a);
      final distanceB = GpsService.distanceToWaypoint(currentPosition, b);
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

    final distance = GpsService.distanceToWaypoint(currentPosition, waypoint);
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
}
