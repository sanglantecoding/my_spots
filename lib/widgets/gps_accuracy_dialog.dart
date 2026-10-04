import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../controllers/gps_controller.dart';
import '../services/gps_service.dart';

/// Dialogue affichant les données GPS RÉELLES à l'instant T.
///
/// Remplace SatelliteStatusDialog / SatelliteBottomSheet :
/// plus aucun satellite estimé, uniquement précision / vitesse /
/// altitude / cap issus du flux [GpsController].
class GpsAccuracyDialog extends StatefulWidget {
  const GpsAccuracyDialog({super.key});

  @override
  State<GpsAccuracyDialog> createState() => _GpsAccuracyDialogState();
}

class _GpsAccuracyDialogState extends State<GpsAccuracyDialog> {
  StreamSubscription<Position>? _sub;

  @override
  void initState() {
    super.initState();
    // Rafraîchit le dialog à chaque fix GPS tant qu'il est ouvert.
    _sub = GpsController.instance.positionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gps = GpsController.instance;
    final accuracy = gps.currentAccuracy;
    final hasFix = accuracy > 0;
    final status = hasFix ? GpsService.getGpsStatus(accuracy) : null;
    final color = status != null
        ? GpsService.getGpsStatusColor(status)
        : Colors.grey;

    return AlertDialog(
      backgroundColor: const Color(0xFF1A2F42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.gps_fixed, color: color),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'PRÉCISION GPS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(
            'Précision',
            hasFix ? '${accuracy.toStringAsFixed(1)} m' : '--',
            color,
          ),
          _row(
            'Statut',
            status != null
                ? GpsService.getGpsDetailedStatusText(status)
                : 'GPS: --',
            color,
          ),
          _row(
            'Vitesse',
            '${gps.currentSpeedKnots.toStringAsFixed(1)} nd',
            Colors.white70,
          ),
          _row(
            'Altitude',
            gps.altitude != null
                ? '${gps.altitude!.toStringAsFixed(0)} m'
                : '--',
            Colors.white70,
          ),
          _row(
            'Cap',
            gps.heading != null ? '${gps.heading!.toStringAsFixed(0)}°' : '--',
            Colors.white70,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
