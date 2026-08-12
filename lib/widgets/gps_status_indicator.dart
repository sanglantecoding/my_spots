import 'package:flutter/material.dart';
import '../services/gps_service.dart';

/// Widget indicateur du statut GPS avec couleur et texte (utilise la logique unifiée)
class GpsStatusIndicator extends StatelessWidget {
  final double? accuracy;
  final String? customStatus;
  final Color? customColor;

  const GpsStatusIndicator({
    super.key,
    this.accuracy,
    this.customStatus,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    String statusText;
    Color statusColor;

    if (customStatus != null && customColor != null) {
      statusText = customStatus!;
      statusColor = customColor!;
    } else if (accuracy != null) {
      // Utilisation de la logique unifiée du GpsService
      statusText = GpsService.getAccuracyStatusText(accuracy);
      statusColor = GpsService.getAccuracyColor(accuracy);
    } else {
      statusText = 'GPS: --';
      statusColor = Colors.grey;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.gps_fixed, size: 16, color: statusColor),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Widget indicateur de précision GPS compact (utilise la logique unifiée)
class GpsAccuracyIndicator extends StatelessWidget {
  final double? accuracy;

  const GpsAccuracyIndicator({super.key, this.accuracy});

  @override
  Widget build(BuildContext context) {
    if (accuracy == null) {
      return const Text(
        'GPS: --',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    // Utilisation de la logique unifiée du GpsService
    final color = GpsService.getAccuracyColor(accuracy);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.gps_fixed, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          'GPS: ${accuracy!.toStringAsFixed(1)}m',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
