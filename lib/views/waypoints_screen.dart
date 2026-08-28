import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/waypoint_export_screen.dart';
import 'package:my_spots/services/waypoint_sort_service.dart';
import 'package:my_spots/services/gps_service.dart';
import 'package:my_spots/widgets/waypoint_accuracy_indicator.dart';
import 'package:my_spots/views/dialogs/waypoint_editor_sheet.dart';
import 'package:my_spots/views/map_screen.dart';
import 'package:my_spots/controllers/gps_controller.dart';
import 'dart:async';

class WaypointsScreen extends StatefulWidget {
  const WaypointsScreen({super.key});

  @override
  State<WaypointsScreen> createState() => _WaypointsScreenState();
}

class _WaypointsScreenState extends State<WaypointsScreen> {
  final TextEditingController _editNameController = TextEditingController();
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _editNameController.dispose();
    super.dispose();
  }

  /// Démarre le suivi GPS pour le tri par distance
  void _startLocationTracking() async {
    try {
      final position = await GpsController.instance.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }

      _positionSubscription = GpsController.instance.positionStream.listen((
        Position position,
      ) {
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
          });
        }
      });
    } catch (e) {
      // Erreur silencieuse si GPS indisponible
    }
  }

  String _formatDate(DateTime date) {
    return 'Créé le ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Obtient la couleur selon la distance
  Color _getDistanceColor(LatLng? currentPosition, Waypoint waypoint) {
    if (currentPosition == null) return Colors.grey;

    final distance = GpsService.calculateDistance(currentPosition, waypoint);
    if (distance < 100) return Colors.green;
    if (distance < 500) return Colors.amber;
    if (distance < 1000) return Colors.orange;
    return Colors.red;
  }

  /// Rafraîchit manuellement le tri
  void _refreshSort() {
    _startLocationTracking();
    setState(() {});
  }

  Future<void> _editWaypoint(int index) async {
    final waypoint = WaypointStore.waypoints[index];

    final outcome = await showWaypointEditorSheet(
      context: context,
      title: 'MODIFIER WAYPOINT',
      icon: Icons.edit_location,
      position: LatLng(waypoint.latitude, waypoint.longitude),
      initialName: waypoint.name,
      initialCategory: waypoint.category,
      initialColorHex: waypoint.colorHex,
      initialDate: waypoint.createdAt,
      isEditing: true,
    );

    if (outcome == null) return;

    if (outcome.deleted) {
      setState(() {
        WaypointStore.waypoints.removeAt(index);
      });
      await WaypointStore.save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Waypoint "${waypoint.name}" supprimé'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (outcome.waypoint == null) return;

    setState(() {
      WaypointStore.waypoints[index] = outcome.waypoint!;
    });
    await WaypointStore.save();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Waypoint "${outcome.waypoint!.name}" modifié'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _viewOnMap(Waypoint waypoint) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapScreen(centerOn: waypoint)),
    );
  }

  Future<void> _deleteWaypoint(Waypoint waypoint) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 12),
            Text('SUPPRIMER', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Supprimer le waypoint "${waypoint.name}" ?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    // Trouver l'index du waypoint et le supprimer
    final index = WaypointStore.waypoints.indexOf(waypoint);
    if (index != -1) {
      setState(() {
        WaypointStore.waypoints.removeAt(index);
      });
      await WaypointStore.save();
    }

    // Afficher un message de confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waypoint supprimé'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tri par distance si position disponible, sinon alphabétique
    final sortedWaypoints = WaypointSortService.sortWaypointsByDistance(
      WaypointStore.waypoints,
      _currentPosition,
    );

    final bool hasWaypoints = sortedWaypoints.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('WAYPOINTS (${sortedWaypoints.length})'),
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _refreshSort,
            tooltip: 'Rafraîchir le tri',
          ),
          IconButton(
            icon: const Icon(Icons.import_export, color: Colors.white70),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WaypointExportScreen(),
                ),
              );

              // Si des waypoints ont été importés, rafraîchir l'interface
              if (result == true && mounted) {
                setState(() {});
              }
            },
            tooltip: 'Exporter/Importer des waypoints',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1929), Color(0xFF1A2F42)],
          ),
        ),
        child: hasWaypoints
            ? ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: sortedWaypoints.length,
                itemBuilder: (context, index) {
                  final waypoint = sortedWaypoints[index];
                  final originalIndex = WaypointStore.waypoints.indexOf(
                    waypoint,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: () => _editWaypoint(originalIndex),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: waypoint.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              waypoint.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Indicateur de précision GPS
                          WaypointAccuracyIndicator(
                            waypoint: waypoint,
                            size: 16,
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          // Distance si position disponible
                          if (_currentPosition != null)
                            Text(
                              WaypointSortService.getFormattedDistance(
                                _currentPosition,
                                waypoint,
                              ),
                              style: TextStyle(
                                color: _getDistanceColor(
                                  _currentPosition,
                                  waypoint,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(waypoint.createdAt),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lat: ${waypoint.latitude.toStringAsFixed(6)}°',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            'Lon: ${waypoint.longitude.toStringAsFixed(6)}°',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.map,
                              color: Colors.blueAccent,
                              size: 24,
                            ),
                            onPressed: () => _viewOnMap(waypoint),
                            tooltip: 'Voir sur la carte',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 24,
                            ),
                            onPressed: () => _deleteWaypoint(waypoint),
                            tooltip: 'Supprimer le waypoint',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.anchor, size: 120, color: Colors.white30),
                    const SizedBox(height: 24),
                    const Text(
                      'AUCUN WAYPOINT',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Allez sur la CARTE et appuyez sur +',
                      style: TextStyle(fontSize: 16, color: Colors.white38),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
