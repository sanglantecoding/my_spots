import 'package:flutter/material.dart';

/// Map control buttons (recenter, offline zones, toggle waypoints, add waypoint)
class MapControlsWidget extends StatelessWidget {
  final VoidCallback onRecenter;
  final VoidCallback onToggleWaypoints;
  final VoidCallback onAddWaypoint;
  final VoidCallback onOpenOfflineZones;
  final bool waypointsVisible;
  final int offlineZoneCount;

  const MapControlsWidget({
    super.key,
    required this.onRecenter,
    required this.onToggleWaypoints,
    required this.onAddWaypoint,
    required this.onOpenOfflineZones,
    required this.waypointsVisible,
    this.offlineZoneCount = 0,
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
          onPressed: onOpenOfflineZones,
          backgroundColor: const Color(0xFF0D6999).withValues(alpha: 0.85),
          heroTag: 'open_offline_zones',
          tooltip: offlineZoneCount > 0
              ? '$offlineZoneCount zone(s) hors-ligne'
              : 'Nouvelle zone hors-ligne',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.cloud_download_outlined, color: Colors.white),
              if (offlineZoneCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade400,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0D1B2A), width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      offlineZoneCount.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0D1B2A),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
