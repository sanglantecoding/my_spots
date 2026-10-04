import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Affiche le dialog avec le résultat de la mesure de distance.
Future<void> showDistanceResultDialog(
  BuildContext context,
  LatLng point1,
  LatLng point2,
  double distanceMeters,
  VoidCallback onClose,
) async {
  final distanceNauticalMiles = distanceMeters / 1852.0;
  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF0D1B2A),
      title: const Row(
        children: [
          Icon(Icons.straighten, color: Color(0xFF0D6999)),
          SizedBox(width: 8),
          Text('Distance mesurée', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Point 1: ${point1.latitude.toStringAsFixed(5)}, ${point1.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Point 2: ${point2.latitude.toStringAsFixed(5)}, ${point2.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D6999).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Distance:',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      '${distanceMeters.toStringAsFixed(1)} m',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Distance:',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      '${distanceNauticalMiles.toStringAsFixed(3)} nm',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            onClose();
          },
          child: const Text('Fermer', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
