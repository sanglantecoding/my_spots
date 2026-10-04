import 'package:flutter/material.dart';
import '../models/waypoint.dart';
import '../services/gps_service.dart'; // ← remplace gps_status_utils.dart

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
    final label =
        waypoint.gpsStatus ??
        GpsService.getGpsStatusLabel(waypoint.creationAccuracy);
    return Icon(
      GpsService.getGpsStatusIcon(label),
      size: size,
      color: GpsService.getColorForStatusLabel(label),
    );
  }
}
