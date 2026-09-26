import 'package:flutter/material.dart';

/// GPS position marker widget - reçoit le heading depuis le parent
/// Le parent (MapView) gère déjà l'abonnement au flux GPS via StreamBuilder
class GpsMarkerWidget extends StatelessWidget {
  final double heading;

  const GpsMarkerWidget({super.key, required this.heading});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * (3.14159 / 180),
      child: const Icon(
        Icons.navigation,
        color: Colors.blue,
        size: 40,
        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    );
  }
}
