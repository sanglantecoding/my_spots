import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/gps_service.dart';
import 'package:my_spots/views/dialogs/waypoint_editor_sheet.dart';

/// Panel showing details of the selected waypoint with action buttons
class SelectedWaypointPanel extends StatelessWidget {
  final Waypoint waypoint;
  final LatLng? currentPosition;
  final VoidCallback onCenterOnTarget;
  final Future<void> Function(WaypointEditorOutcome?) onEditWaypoint;
  final VoidCallback onStartNavigation;
  final VoidCallback onClose;

  const SelectedWaypointPanel({
    super.key,
    required this.waypoint,
    required this.currentPosition,
    required this.onCenterOnTarget,
    required this.onEditWaypoint,
    required this.onStartNavigation,
    required this.onClose,
  });

  String _formatDistanceForWaypoint(double meters, Waypoint waypoint) {
    // Champignons : toujours en mètres/kilomètres
    if (waypoint.category == WaypointCategory.mushrooms) {
      if (meters < 1000) {
        return '${meters.round()} m';
      }
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    // Pêche et autres : respecte le choix utilisateur
    return GpsService.formatDistance(meters);
  }

  IconData _getWaypointCategoryIcon(Waypoint waypoint) {
    switch (waypoint.category) {
      case WaypointCategory.mushrooms:
        return Icons.park;
      case WaypointCategory.fishing:
        return Icons.anchor;
      case WaypointCategory.other:
        if (waypoint.name.toLowerCase().contains('voiture')) {
          return Icons.directions_car;
        } else {
          return Icons.location_on;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7).withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: waypoint.color.withValues(alpha: 0.7),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne 1 : Nom du waypoint
          Text(
            waypoint.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 0),
          // Ligne 2 : Distance et boutons d'action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Distance à gauche
              Text(
                currentPosition != null
                    ? _formatDistanceForWaypoint(
                        GpsService.calculateDistance(
                          currentPosition!,
                          waypoint,
                        ),
                        waypoint,
                      )
                    : '—',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                  letterSpacing: 0.5,
                ),
              ),
              // Boutons d'action à droite
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.center_focus_strong,
                      color: Colors.black87,
                      size: 20,
                    ),
                    onPressed: onCenterOnTarget,
                    tooltip: 'Centrer carte',
                    iconSize: 20,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.black87,
                      size: 20,
                    ),
                    onPressed: () async {
                      final outcome = await showWaypointEditorSheet(
                        context: context,
                        title: 'Modifier le waypoint',
                        icon: _getWaypointCategoryIcon(waypoint),
                        position: LatLng(waypoint.latitude, waypoint.longitude),
                        initialName: waypoint.name,
                        initialCategory: waypoint.category,
                        initialColorHex:
                            '#${waypoint.color.toARGB32().toRadixString(16).substring(2)}',
                        initialDate: waypoint.createdAt,
                        isEditing: true,
                      );
                      onEditWaypoint(outcome);
                    },
                    tooltip: 'Éditer',
                    iconSize: 20,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.navigation,
                      color: Colors.blue,
                      size: 20,
                    ),
                    onPressed: onStartNavigation,
                    tooltip: 'Y aller',
                    iconSize: 20,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.black54,
                      size: 20,
                    ),
                    onPressed: onClose,
                    tooltip: 'Annuler la cible',
                    iconSize: 20,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
