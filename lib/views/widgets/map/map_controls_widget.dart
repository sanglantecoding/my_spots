import 'package:flutter/material.dart';

/// Map control buttons (recenter, toggle waypoints, add waypoint)
class MapControlsWidget extends StatelessWidget {
  final VoidCallback onRecenter;
  final VoidCallback onToggleWaypoints;
  final VoidCallback onAddWaypoint;
  final bool waypointsVisible;

  const MapControlsWidget({
    super.key,
    required this.onRecenter,
    required this.onToggleWaypoints,
    required this.onAddWaypoint,
    required this.waypointsVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FloatingActionButton(
          onPressed: onRecenter,
          backgroundColor: const Color(0xFF1E3A5F).withValues(alpha: 0.80),
          heroTag: 'recenter',
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          onPressed: onToggleWaypoints,
          backgroundColor: const Color(0xFF1E3A5F).withValues(alpha: 0.80),
          heroTag: 'toggle_waypoints',
          child: Icon(
            waypointsVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          onPressed: onAddWaypoint,
          backgroundColor: Colors.green.shade700.withValues(alpha: 0.80),
          heroTag: 'add_waypoint',
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ],
    );
  }
}
