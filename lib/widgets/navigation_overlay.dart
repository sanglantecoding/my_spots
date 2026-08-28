import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../app_settings.dart';
import '../models/waypoint.dart';
import '../services/gps_service.dart';
import '../services/alarm_service.dart';
import '../controllers/gps_controller.dart';

/// Widget de bandeau de navigation active
/// Affiche les informations de navigation en temps réel vers un waypoint ciblé
class NavigationOverlay extends StatefulWidget {
  final Waypoint targetWaypoint;
  final LatLng? currentPosition;
  final VoidCallback onStopNavigation;

  const NavigationOverlay({
    super.key,
    required this.targetWaypoint,
    required this.currentPosition,
    required this.onStopNavigation,
  });

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay> {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<AlarmEvent>? _alarmSubscription;
  LatLng? _currentPosition;
  double _currentSpeed = 0.0;
  double _distanceToTarget = 0.0;
  double _bearingToTarget = 0.0;
  String _eta = '--:--';
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    // Initialiser immédiatement avec la position fournie
    if (widget.currentPosition != null) {
      _currentPosition = widget.currentPosition;
      _updateNavigationData();
    }

    // Initialiser l'état muet depuis le service
    _isMuted = AlarmService.isMuted;

    // S'abonner au flux broadcast d'événements d'alarme
    _alarmSubscription = AlarmService.onAlarmEvent.listen((event) {
      if (!mounted) return;
      if (event.type == AlarmEventType.mutedChanged) {
        setState(() => _isMuted = event.boolPayload);
      }
    });

    _startNavigationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _alarmSubscription?.cancel();
    super.dispose();
  }

  /// Démarre le suivi GPS pour la navigation
  void _startNavigationTracking() {
    _positionSubscription = GpsController.instance.positionStream.listen((
      Position position,
    ) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _currentSpeed = position.speed;
          _updateNavigationData();
        });
      }
    });
  }

  /// Met à jour les données de navigation (distance, cap, ETA)
  void _updateNavigationData() {
    if (_currentPosition == null) return;

    // Calculer la distance vers le waypoint
    _distanceToTarget = GpsController.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.targetWaypoint.latitude,
      widget.targetWaypoint.longitude,
    );

    // Calculer le cap vers le waypoint et normaliser entre 0-360°
    _bearingToTarget = GpsController.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.targetWaypoint.latitude,
      widget.targetWaypoint.longitude,
    );
    // Normaliser le cap entre 0 et 360 degrés
    _bearingToTarget = (_bearingToTarget + 360) % 360;

    // Calculer l'ETA
    _calculateETA();
  }

  /// Calcule le temps d'arrivée estimé
  void _calculateETA() {
    // Si la vitesse est trop faible ou nulle (<= 0.5 m/s), afficher --:--
    // Geolocator.position.speed est toujours en m/s
    if (_currentSpeed <= 0.5) {
      _eta = '--:--';
      return;
    }

    // Calculer le temps en secondes en utilisant les unités SI
    // _currentSpeed est déjà en m/s (valeur native de Geolocator)
    // _distanceToTarget est en mètres
    final timeInSeconds = _distanceToTarget / _currentSpeed;

    // Convertir en heures et minutes
    if (timeInSeconds.isInfinite || timeInSeconds.isNaN || timeInSeconds <= 0) {
      _eta = '--:--';
      return;
    }

    final hours = (timeInSeconds / 3600).floor();
    final minutes = ((timeInSeconds % 3600) / 60).floor();

    if (hours > 0) {
      _eta = '${hours}h ${minutes}min';
    } else {
      _eta = '${minutes}min';
    }
  }

  /// Formate la distance selon les préférences utilisateur
  String _formatDistance(double meters) {
    return GpsService.formatDistance(meters);
  }

  /// Formate la vitesse selon les préférences utilisateur
  String _formatSpeed(double speedInMetersPerSecond) {
    if (AppSettings.speedUnit == SpeedUnit.knots) {
      final knots = speedInMetersPerSecond * 1.94384;
      return '${knots.toStringAsFixed(1)} kn';
    } else {
      final kmh = speedInMetersPerSecond * 3.6;
      return '${kmh.toStringAsFixed(1)} km/h';
    }
  }

  /// Formate le cap en degrés
  String _formatBearing(double bearing) {
    return '${bearing.toStringAsFixed(0)}°';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1929).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête avec nom du waypoint et bouton d'arrêt
          Row(
            children: [
              const Icon(Icons.navigation, color: Colors.blueAccent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Navigation vers',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      widget.targetWaypoint.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Icône audio pour couper/réactiver le son
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: _isMuted ? Colors.grey : Colors.blueAccent,
                  size: 24,
                ),
                onPressed: () {
                  AlarmService.toggleMuted();
                },
                tooltip: _isMuted ? 'Activer le son' : 'Couper le son',
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 28),
                onPressed: widget.onStopNavigation,
                tooltip: 'Arrêter la navigation',
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          // Données de navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavigationItem(
                icon: Icons.straighten,
                label: 'Distance',
                value: _formatDistance(_distanceToTarget),
              ),
              _buildNavigationItem(
                icon: Icons.explore,
                label: 'Cap',
                value: _formatBearing(_bearingToTarget),
              ),
              _buildNavigationItem(
                icon: Icons.speed,
                label: 'Vitesse',
                value: _formatSpeed(_currentSpeed),
              ),
              _buildNavigationItem(
                icon: Icons.access_time,
                label: 'ETA',
                value: _eta,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construit un élément d'information de navigation
  Widget _buildNavigationItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
