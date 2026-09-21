import 'package:flutter/material.dart';

/// Colonne de boutons d'action flottants sur la carte.
///
/// Le bouton « zones hors-ligne » a été retiré : l'accès aux zones se fait
/// depuis la page d'accueil (« ZONES HORS-LIGNE »). Les 3 boutons restants
/// sont passés en format compact (~2/3 de la taille d'un FAB classique).
class MapControlsWidget extends StatelessWidget {
  const MapControlsWidget({
    super.key,
    required this.onRecenter,
    required this.onToggleWaypoints,
    required this.onAddWaypoint,
    required this.waypointsVisible,
  });

  final VoidCallback onRecenter;
  final VoidCallback onToggleWaypoints;
  final VoidCallback onAddWaypoint;
  final bool waypointsVisible;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'recenter',
          backgroundColor: const Color(0xFF1E3A5F).withValues(alpha: 0.80),
          onPressed: onRecenter,
          tooltip: 'Recentrer sur ma position',
          child: const Icon(Icons.my_location, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 4),
        FloatingActionButton.small(
          heroTag: 'toggle_waypoints',
          backgroundColor: const Color(0xFF1E3A5F).withValues(alpha: 0.80),
          onPressed: onToggleWaypoints,
          tooltip: waypointsVisible
              ? 'Masquer les waypoints'
              : 'Afficher les waypoints',
          child: Icon(
            waypointsVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(height: 4),
        FloatingActionButton.small(
          heroTag: 'add_waypoint',
          backgroundColor: Colors.green.shade700.withValues(alpha: 0.80),
          onPressed: onAddWaypoint,
          tooltip: 'Ajouter un waypoint',
          child: const Icon(Icons.add, color: Colors.white, size: 18),
        ),
      ],
    );
  }
}
