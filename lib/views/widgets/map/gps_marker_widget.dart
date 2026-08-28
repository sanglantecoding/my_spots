import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/controllers/gps_controller.dart';
import 'dart:async';

/// GPS position marker widget that listens directly to GpsController
/// This avoids rebuilding the entire map on GPS updates
class GpsMarkerWidget extends StatefulWidget {
  const GpsMarkerWidget({super.key});

  @override
  State<GpsMarkerWidget> createState() => _GpsMarkerWidgetState();
}

class _GpsMarkerWidgetState extends State<GpsMarkerWidget> {
  LatLng? _currentPosition;
  double _currentHeading = 0.0;
  StreamSubscription? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    // Get initial values
    _currentPosition = GpsController.instance.currentPosition != null
        ? LatLng(
            GpsController.instance.latitude!,
            GpsController.instance.longitude!,
          )
        : null;
    _currentHeading = GpsController.instance.heading ?? 0.0;

    // Listen to position updates
    _positionSubscription = GpsController.instance.positionStream.listen(
      (position) {
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            _currentHeading = position.heading;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return const SizedBox.shrink();
    }

    return Transform.rotate(
      angle: _currentHeading * (3.14159 / 180),
      child: const Icon(
        Icons.navigation,
        color: Colors.blue,
        size: 40,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 4),
        ],
      ),
    );
  }
}
