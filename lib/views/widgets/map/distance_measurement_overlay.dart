import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

/// Overlay pour mesurer une distance entre deux points.
class DistanceMeasurementOverlay extends StatefulWidget {
  final LatLng initialPoint;
  final void Function(LatLng point1, LatLng point2, double distanceMeters)
  onMeasureComplete;
  final VoidCallback onCancel;
  final MapController mapController;

  const DistanceMeasurementOverlay({
    super.key,
    required this.initialPoint,
    required this.onMeasureComplete,
    required this.onCancel,
    required this.mapController,
  });

  @override
  State<DistanceMeasurementOverlay> createState() =>
      _DistanceMeasurementOverlayState();
}

class _DistanceMeasurementOverlayState
    extends State<DistanceMeasurementOverlay> {
  late LatLng _point1;
  LatLng? _point2;
  bool _isPlacingPoint2 = false;

  @override
  void initState() {
    super.initState();
    _point1 = widget.initialPoint;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Valide le point en cours (point 1 ou point 2)
  void _validateCurrentPoint() {
    if (!_isPlacingPoint2) {
      // On valide le point 1, on passe au point 2
      setState(() {
        _isPlacingPoint2 = true;
        _point2 = _point1; // Point 2 commence à la même position
      });
    } else {
      // On valide le point 2, on termine la mesure
      if (_point2 != null) {
        final distance = _calculateDistance(_point1, _point2!);
        widget.onMeasureComplete(_point1, _point2!, distance);
      }
    }
  }

  void _movePoint1(LatLng newPosition) {
    if (!_isPlacingPoint2) {
      setState(() {
        _point1 = newPosition;
      });
    }
  }

  void _movePoint2(LatLng newPosition) {
    if (_isPlacingPoint2) {
      setState(() {
        _point2 = newPosition;
      });
    }
  }

  Offset _latLngToOffset(LatLng latLng) {
    return widget.mapController.camera.latLngToScreenOffset(latLng);
  }

  LatLng _offsetToLatLng(Offset offset) {
    return widget.mapController.camera.screenOffsetToLatLng(offset);
  }

  /// Vérifie si les deux points sont à des positions différentes
  bool _pointsAreDifferent() {
    if (_point2 == null) return false;
    return (_point1.latitude - _point2!.latitude).abs() > 0.0001 ||
        (_point1.longitude - _point2!.longitude).abs() > 0.0001;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Ligne entre les deux points
        if (_point2 != null && _pointsAreDifferent())
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DistanceLinePainter(
                  point1: _point1,
                  point2: _point2!,
                  mapController: widget.mapController,
                ),
              ),
            ),
          ),

        // Marqueur du premier point (simple rond, sans bouton OK)
        _buildDraggableMarker(
          point: _point1,
          color: Colors.blue,
          onDrag: _movePoint1,
        ),

        // Marqueur du deuxième point (seulement si en mode placement)
        if (_isPlacingPoint2 && _point2 != null)
          _buildDraggableMarker(
            point: _point2!,
            color: Colors.red,
            onDrag: _movePoint2,
          ),

        // Instructions en bas
        Positioned(
          bottom: 132,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isPlacingPoint2
                        ? 'Placez le deuxième point (glissez pour ajuster)'
                        : 'Placez le premier point (glissez pour ajuster)',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bouton de validation FIXE en bas (disparaît après validation du point 2)
        if (!_isPlacingPoint2 || _point2 != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 80, // Au-dessus du bouton annuler
            child: GestureDetector(
              onTap: _validateCurrentPoint,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isPlacingPoint2
                          ? 'Valider le point 2'
                          : 'Valider le point 1',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Bouton annuler en bas à gauche
        Positioned(
          left: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: widget.onCancel,
            backgroundColor: Colors.grey,
            child: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }

  /// Construit un marqueur draggable SIMPLE (sans bouton OK attaché)
  Widget _buildDraggableMarker({
    required LatLng point,
    required Color color,
    required void Function(LatLng newPosition) onDrag,
  }) {
    return Builder(
      builder: (context) {
        final offset = _latLngToOffset(point);
        const double markerSize = 32.0;
        final double halfSize = markerSize / 2;

        return Positioned(
          left: offset.dx - halfSize,
          top: offset.dy - halfSize,
          child: GestureDetector(
            onPanUpdate: (details) {
              final currentOffset = _latLngToOffset(point);
              final newOffset = Offset(
                currentOffset.dx + details.delta.dx,
                currentOffset.dy + details.delta.dy,
              );
              onDrag(_offsetToLatLng(newOffset));
            },
            child: Container(
              width: markerSize,
              height: markerSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DistanceLinePainter extends CustomPainter {
  final LatLng point1;
  final LatLng point2;
  final MapController mapController;

  _DistanceLinePainter({
    required this.point1,
    required this.point2,
    required this.mapController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final p1 = mapController.camera.latLngToScreenOffset(point1);
    final p2 = mapController.camera.latLngToScreenOffset(point2);
    canvas.drawLine(p1, p2, paint);
  }

  @override
  bool shouldRepaint(_DistanceLinePainter oldDelegate) {
    return point1 != oldDelegate.point1 || point2 != oldDelegate.point2;
  }
}
