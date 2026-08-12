import 'package:flutter/material.dart';
import '../models/waypoint.dart';
import '../utils/gps_status_utils.dart';

/// Widget indicateur de précision GPS pour les waypoints
class WaypointAccuracyIndicator extends StatelessWidget {
  final Waypoint waypoint;
  final double? size;

  const WaypointAccuracyIndicator({
    super.key,
    required this.waypoint,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    // Priorité au statut GPS enregistré, sinon calcul depuis la précision
    final status =
        waypoint.gpsStatus ??
        GpsStatusUtils.getGpsStatusLabel(waypoint.creationAccuracy);
    final color = GpsStatusUtils.getGpsStatusColor(status);
    final icon = GpsStatusUtils.getGpsStatusIcon(status);

    return Icon(icon, size: size, color: color);
  }

  /// Obtient la description textuelle du statut GPS
  static String getAccuracyDescription(String? status) {
    return GpsStatusUtils.getGpsStatusDescription(status);
  }

  /// Obtient la couleur du statut GPS
  static Color getAccuracyColor(String? status) {
    return GpsStatusUtils.getGpsStatusColor(status);
  }
}
