import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Draw mode selection for the zone editor overlay.
enum ZoneDrawMode { rectangle, polygon }

/// Interactive overlay displayed on the map during zone-adjustment mode.
///
/// When [drawMode] is [ZoneDrawMode.rectangle] (default):
/// - Drag the rectangle body to translate the whole selection.
/// - Resize via 8 handles (corners + edge midpoints).
/// - FAB confirmation button pinned to the bottom of the screen.
/// Returns [LatLngBounds] via [onConfirm].
///
/// When [drawMode] is [ZoneDrawMode.polygon]:
/// - Long press the map to propose a new vertex.
/// - A confirmation dialog asks "Ajouter ce point ?" with Ajouter/Annuler.
/// - Confirmed points are drawn and connected to the previous one.
/// - At least 3 vertices are required to confirm.
/// - Auto-closes the polygon by connecting last to first.
/// Returns [List<LatLng>] via [onConfirm].
class ZoneEditorOverlay extends StatefulWidget {
  /// The current draw mode.
  final ZoneDrawMode drawMode;

  /// Called when the user confirms the bounds.
  ///
  /// - Rectangle mode: receives a [LatLngBounds].
  /// - Polygon mode: receives a [List<LatLng>] of vertices in order.
  final void Function(dynamic bounds) onConfirm;

  /// Called when the user cancels the adjustment.
  final VoidCallback onCancel;

  /// Called when a point is proposed in polygon mode.
  /// Returns true if the point should be added, false otherwise.
  final Future<bool?> Function(LatLng)? onPointProposed;

  /// Optional controller from the underlying [FlutterMap]. When provided,
  /// bounds-to-LatLng conversions use the real map camera instead of an
  /// unattached default [MapController].
  final MapController? mapController;

  const ZoneEditorOverlay({
    super.key,
    required this.drawMode,
    required this.onConfirm,
    required this.onCancel,
    this.mapController,
    this.onPointProposed,
  });

  @override
  State<ZoneEditorOverlay> createState() => ZoneEditorOverlayState();
}

class ZoneEditorOverlayState extends State<ZoneEditorOverlay> {
  late final MapController _mapController =
      widget.mapController ?? MapController();

  int _cameraGeneration = 0;
  StreamSubscription<MapEvent>? _cameraSubscription;

  // ── Rectangle mode state ──
  double _left = 0;
  double _top = 0;
  double _right = 0;
  double _bottom = 0;

  // ── Polygon mode state ──
  /// Definitive LatLng coordinates (source of truth).
  final List<LatLng> _polygonLatLngPoints = [];

  /// Provisional point shown while awaiting user confirmation.
  LatLng? _provisionalLatLng;

  Size _mapSize = Size.zero;
  bool _layoutInitialized = false;
  static const double _initialWidth = 280;
  static const double _initialHeight = 220;
  static const double _minSize = 60;
  static const double _handleSize = 28;

  _Handle? _activeHandle;

  /// While awaiting confirmation of the provisional point, this flag
  /// blocks further long-presses so the user cannot stack confirmations.
  bool _awaitingConfirmation = false;

  bool get _isPolygonMode => widget.drawMode == ZoneDrawMode.polygon;

  @override
  void initState() {
    super.initState();
    if (_isPolygonMode) {
      _startCameraListener();
    }
  }

  void _startCameraListener() {
    _cameraSubscription = _mapController.mapEventStream.listen((event) {
      if (mounted) {
        setState(() {
          _cameraGeneration++;
        });
      }
    });
  }

  @override
  void dispose() {
    _cameraSubscription?.cancel();
    super.dispose();
  }

  void _initRectOnLayout(Size mapSize) {
    if (_layoutInitialized && _mapSize == mapSize) return;
    final Size newSize = Size(
      mapSize.width.isFinite && mapSize.width > 0
          ? mapSize.width
          : _mapSize.width,
      mapSize.height.isFinite && mapSize.height > 0
          ? mapSize.height
          : _mapSize.height,
    );
    if (newSize.width <= 0 || newSize.height <= 0) return;
    if (!_layoutInitialized) {
      _mapSize = newSize;
      final cx = newSize.width / 2;
      final cy = newSize.height / 2;
      setState(() {
        _left = cx - _initialWidth / 2;
        _top = cy - _initialHeight / 2;
        _right = cx + _initialWidth / 2;
        _bottom = cy + _initialHeight / 2;
        _layoutInitialized = true;
      });
    } else {
      _mapSize = newSize;
    }
  }

  /// Public method called by the parent (via GlobalKey) when a long press
  /// event is received from FlutterMap. Shows a provisional point and asks
  /// for user confirmation before adding it to the definitive list.
  Future<void> proposePoint(LatLng latLng) async {
    if (!_isPolygonMode) return;
    if (_awaitingConfirmation) return;

    setState(() {
      _provisionalLatLng = latLng;
      _awaitingConfirmation = true;
    });

    // Use parent callback if provided, otherwise use internal dialog
    final confirmed = widget.onPointProposed != null
        ? await widget.onPointProposed!(latLng)
        : await _showConfirmationDialog(latLng);

    if (!mounted) return;

    setState(() {
      _provisionalLatLng = null;
      _awaitingConfirmation = false;
    });

    if (confirmed == true) {
      setState(() {
        _polygonLatLngPoints.add(latLng);
      });
    }
  }

  /// Shows the "Ajouter ce point ?" confirmation dialog.
  Future<bool?> _showConfirmationDialog(LatLng point) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_location_alt, color: Color(0xFF0D6999)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ajouter ce point ?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Point à l\'emplacement :\n'
          'Lat ${point.latitude.toStringAsFixed(5)}  Lon ${point.longitude.toStringAsFixed(5)}',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Ajouter',
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  LatLng _pixelToLatLng(double px, double py) {
    return _mapController.camera.screenOffsetToLatLng(Offset(px, py));
  }

  LatLngBounds get _bounds => LatLngBounds(
    _pixelToLatLng(_left, _bottom),
    _pixelToLatLng(_right, _top),
  );

  void _moveRect(double dx, double dy) {
    setState(() {
      final double width = _right - _left;
      final double height = _bottom - _top;
      double newLeft = (_left + dx)
          .clamp(0.0, _mapSize.width - width)
          .toDouble();
      double newTop = (_top + dy)
          .clamp(0.0, _mapSize.height - height)
          .toDouble();
      _left = newLeft;
      _top = newTop;
      _right = newLeft + width;
      _bottom = newTop + height;
    });
  }

  Offset? _handleCenter(_Handle handle) {
    switch (handle) {
      case _Handle.topLeft:
        return Offset(_left, _top);
      case _Handle.topRight:
        return Offset(_right, _top);
      case _Handle.bottomLeft:
        return Offset(_left, _bottom);
      case _Handle.bottomRight:
        return Offset(_right, _bottom);
      case _Handle.middleLeft:
        return Offset(_left, (_top + _bottom) / 2);
      case _Handle.middleRight:
        return Offset(_right, (_top + _bottom) / 2);
      case _Handle.middleTop:
        return Offset((_left + _right) / 2, _top);
      case _Handle.middleBottom:
        return Offset((_left + _right) / 2, _bottom);
      case _Handle.drag:
        return null;
    }
  }

  void _resizeRect(_Handle handle, double dx, double dy) {
    setState(() {
      switch (handle) {
        case _Handle.topLeft:
          _left = (_left + dx).clamp(0.0, _right - _minSize).toDouble();
          _top = (_top + dy).clamp(0.0, _bottom - _minSize).toDouble();
          break;
        case _Handle.topRight:
          _right = (_right + dx)
              .clamp(_left + _minSize, _mapSize.width)
              .toDouble();
          _top = (_top + dy).clamp(0.0, _bottom - _minSize).toDouble();
          break;
        case _Handle.bottomLeft:
          _left = (_left + dx).clamp(0.0, _right - _minSize).toDouble();
          _bottom = (_bottom + dy)
              .clamp(_top + _minSize, _mapSize.height)
              .toDouble();
          break;
        case _Handle.bottomRight:
          _right = (_right + dx)
              .clamp(_left + _minSize, _mapSize.width)
              .toDouble();
          _bottom = (_bottom + dy)
              .clamp(_top + _minSize, _mapSize.height)
              .toDouble();
          break;
        case _Handle.middleLeft:
          _left = (_left + dx).clamp(0.0, _right - _minSize).toDouble();
          _bottom = (_bottom + dy)
              .clamp(_top + _minSize, _mapSize.height)
              .toDouble();
          break;
        case _Handle.middleRight:
          _right = (_right + dx)
              .clamp(_left + _minSize, _mapSize.width)
              .toDouble();
          _bottom = (_bottom + dy)
              .clamp(_top + _minSize, _mapSize.height)
              .toDouble();
          break;
        case _Handle.middleTop:
          _top = (_top + dy).clamp(0.0, _bottom - _minSize).toDouble();
          _left = (_left + dx).clamp(0.0, _right - _minSize).toDouble();
          break;
        case _Handle.middleBottom:
          _bottom = (_bottom + dy)
              .clamp(_top + _minSize, _mapSize.height)
              .toDouble();
          _left = (_left + dx).clamp(0.0, _right - _minSize).toDouble();
          break;
        case _Handle.drag:
          break;
      }
    });
  }

  void _confirmPolygon() {
    if (_polygonLatLngPoints.length < 3) return;
    widget.onConfirm(List<LatLng>.from(_polygonLatLngPoints));
  }

  /// Supprime le dernier point placé en mode polygon.
  void _removeLastPoint() {
    if (_polygonLatLngPoints.isNotEmpty) {
      setState(() {
        _polygonLatLngPoints.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isPolygonMode) {
            _initRectOnLayout(
              Size(constraints.maxWidth, constraints.maxHeight),
            );
          }
        });
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Layer 0: Pure drawing (no hit-test) ──
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _isPolygonMode
                      ? _PolygonPainter(
                          latLngPoints: _polygonLatLngPoints,
                          provisionalLatLng: _provisionalLatLng,
                          mapController: _mapController,
                          cameraGeneration: _cameraGeneration,
                        )
                      : _SelectionPainter(
                          left: _left,
                          top: _top,
                          right: _right,
                          bottom: _bottom,
                        ),
                ),
              ),
            ),
            if (!_isPolygonMode) ...[
              // ── Layer 1: Body drag detector (opaque inside the rect) ──
              Positioned(
                left: _left,
                top: _top,
                width: _right - _left,
                height: _bottom - _top,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _activeHandle = _Handle.drag,
                  onPanUpdate: (d) {
                    if (_activeHandle == _Handle.drag) {
                      _moveRect(d.delta.dx, d.delta.dy);
                    }
                  },
                  onPanEnd: (_) => _activeHandle = null,
                  child: const SizedBox.expand(),
                ),
              ),
              // ── Layer 2: 8 handle hit boxes (opaque) ──
              for (final h in [
                _Handle.topLeft,
                _Handle.topRight,
                _Handle.bottomLeft,
                _Handle.bottomRight,
                _Handle.middleLeft,
                _Handle.middleRight,
                _Handle.middleTop,
                _Handle.middleBottom,
              ])
                _buildHandle(h),
            ],
            // ── Layer 3: Top bar (Annuler + title) (opaque) ──
            _buildTopBar(context),
            if (_isPolygonMode)
              _buildPolygonConfirmButton()
            else
              _buildConfirmButton(),
          ],
        );
      },
    );
  }

  Widget _buildHandle(_Handle handle) {
    final center = _handleCenter(handle);
    if (center == null) return const SizedBox.shrink();
    const hs = _handleSize;
    return Positioned(
      left: center.dx - hs / 2,
      top: center.dy - hs / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _activeHandle = handle,
        onPanUpdate: (d) => _resizeRect(handle, d.delta.dx, d.delta.dy),
        onPanEnd: (_) => _activeHandle = null,
        child: SizedBox(width: hs, height: hs),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: MediaQuery.of(context).padding.top + 8,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onCancel,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Annuler',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isPolygonMode) ...[
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _polygonLatLngPoints.isNotEmpty ? _removeLastPoint : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _polygonLatLngPoints.isNotEmpty
                      ? Colors.black.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _polygonLatLngPoints.isNotEmpty
                        ? Colors.orange.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.undo,
                      color: _polygonLatLngPoints.isNotEmpty
                          ? Colors.orange
                          : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Retirer',
                      style: TextStyle(
                        color: _polygonLatLngPoints.isNotEmpty
                            ? Colors.orange
                            : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _polygonLatLngPoints.length < 3
                        ? Icons.warning
                        : Icons.check_circle,
                    color: _polygonLatLngPoints.length < 3
                        ? Colors.orange
                        : Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_polygonLatLngPoints.length}/3 pts min',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildConfirmButton() => Align(
    alignment: Alignment.bottomCenter,
    child: SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: FloatingActionButton.extended(
          heroTag: 'zoneEditorConfirm',
          backgroundColor: const Color(0xFF0D6999),
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          icon: const Icon(Icons.check, size: 22),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Text(
              'Valider et enregistrer la zone',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          onPressed: () => widget.onConfirm(_bounds),
        ),
      ),
    ),
  );

  Widget _buildPolygonConfirmButton() {
    final canConfirm = _polygonLatLngPoints.length >= 3;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: FloatingActionButton.extended(
            heroTag: 'zoneEditorConfirmPoly',
            backgroundColor: canConfirm ? const Color(0xFF0D6999) : Colors.grey,
            foregroundColor: Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            icon: const Icon(Icons.check, size: 22),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Text(
                'Terminer le tracé',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            onPressed: canConfirm ? _confirmPolygon : null,
          ),
        ),
      ),
    );
  }
}

enum _Handle {
  drag,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  middleLeft,
  middleRight,
  middleTop,
  middleBottom,
}

class _SelectionPainter extends CustomPainter {
  final double left, top, right, bottom;
  _SelectionPainter({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
  static const double _hs = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(left, top, right, bottom);
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF0D6999).withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF0D6999)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    _drawHandle(canvas, left, top);
    _drawHandle(canvas, right, top);
    _drawHandle(canvas, left, bottom);
    _drawHandle(canvas, right, bottom);
    _drawEdge(canvas, (left + right) / 2, top);
    _drawEdge(canvas, (left + right) / 2, bottom);
    _drawEdge(canvas, left, (top + bottom) / 2);
    _drawEdge(canvas, right, (top + bottom) / 2);
  }

  void _drawHandle(Canvas c, double x, double y) {
    final r = Rect.fromCenter(center: Offset(x, y), width: _hs, height: _hs);
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(4)),
      Paint()..color = const Color(0xFF0D6999),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(4)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawEdge(Canvas c, double x, double y) {
    final r = Rect.fromCenter(
      center: Offset(x, y),
      width: _hs * 0.65,
      height: _hs * 0.65,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      Paint()..color = const Color(0xFF0D6999),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      left != old.left ||
      top != old.top ||
      right != old.right ||
      bottom != old.bottom;
}

class _PolygonPainter extends CustomPainter {
  final List<LatLng> latLngPoints;
  final LatLng? provisionalLatLng;
  final MapController mapController;
  final int cameraGeneration;

  _PolygonPainter({
    required this.latLngPoints,
    this.provisionalLatLng,
    required this.mapController,
    required this.cameraGeneration,
  });

  static const double _pointRadius = 8.0;
  static const double _lineWidth = 3.0;
  static const double _dotSpacing = 12.0;
  static const double _haloRadius = 3.5;
  static const double _coreRadius = 2.0;

  /// Convert LatLng to screen offset using FlutterMap camera
  Offset _latLngToScreen(LatLng latLng) {
    return mapController.camera.latLngToScreenOffset(latLng);
  }

  /// Dessine une ligne pointillée (halo blanc + cœur bleu) entre deux points.
  /// Utilisée pour prévisualiser la fermeture du polygone.
  void _drawDottedLine(Canvas canvas, Offset from, Offset to) {
    final delta = to - from;
    final distance = delta.distance;
    if (distance < 2) return;

    final haloPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final corePaint = Paint()
      ..color = const Color(0xFF0D6999)
      ..style = PaintingStyle.fill;

    for (double t = 0; t <= distance; t += _dotSpacing) {
      final p = from + delta * (t / distance);
      canvas.drawCircle(p, _haloRadius, haloPaint);
      canvas.drawCircle(p, _coreRadius, corePaint);
    }
    // Point final pour "souder" visuellement
    canvas.drawCircle(to, _haloRadius, haloPaint);
    canvas.drawCircle(to, _coreRadius, corePaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (latLngPoints.isEmpty && provisionalLatLng == null) return;

    // Convert all LatLng points to screen coordinates
    final screenPoints = latLngPoints
        .map((latLng) => _latLngToScreen(latLng))
        .toList();
    final provisionalScreenPoint = provisionalLatLng != null
        ? _latLngToScreen(provisionalLatLng!)
        : null;

    // ── Paints ──
    final linePaint = Paint()
      ..color = const Color(0xFF0D6999)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lineWidth;

    final previewPaint = Paint()
      ..color = const Color(0xFF0D6999).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lineWidth;

    final pointPaint = Paint()
      ..color = const Color(0xFF0D6999)
      ..style = PaintingStyle.fill;

    final provisionalPointPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    final whiteStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final provisionalStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final pointStrokePaint = Paint()
      ..color = const Color(0xFF0D6999)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // ── Drawing ──

    // 1. Lignes entre points confirmés (bleu plein)
    for (int i = 0; i < screenPoints.length - 1; i++) {
      canvas.drawLine(screenPoints[i], screenPoints[i + 1], linePaint);
    }

    // 2. Ligne provisoire vers le point en attente de confirmation (bleu transparent)
    if (provisionalScreenPoint != null && screenPoints.isNotEmpty) {
      canvas.drawLine(screenPoints.last, provisionalScreenPoint, previewPaint);
    }

    // 3. Prévisualisation de la fermeture du polygone (pointillé visible)
    if (screenPoints.length >= 3) {
      _drawDottedLine(canvas, screenPoints.last, screenPoints.first);
    }

    // 4. Points confirmés (bleu avec contour blanc)
    for (int i = 0; i < screenPoints.length; i++) {
      final offset = screenPoints[i];
      // Halo bleu transparent
      canvas.drawCircle(
        offset,
        _pointRadius + 3,
        pointPaint..color = const Color(0xFF0D6999).withValues(alpha: 0.2),
      );
      // Contour blanc
      canvas.drawCircle(offset, _pointRadius + 1, whiteStrokePaint);
      // Cœur bleu
      canvas.drawCircle(offset, _pointRadius, pointPaint);
      // Contour bleu foncé
      canvas.drawCircle(offset, _pointRadius, pointStrokePaint);
    }

    // 5. Point provisoire (orange avec contour blanc)
    if (provisionalScreenPoint != null) {
      final po = provisionalScreenPoint;
      // Halo orange transparent
      canvas.drawCircle(
        po,
        _pointRadius + 3,
        provisionalPointPaint..color = Colors.orange.withValues(alpha: 0.2),
      );
      // Contour blanc
      canvas.drawCircle(po, _pointRadius + 1, provisionalStrokePaint);
      // Cœur orange
      canvas.drawCircle(po, _pointRadius, provisionalPointPaint);
      // Contour blanc
      canvas.drawCircle(po, _pointRadius, provisionalStrokePaint);
    }
  }

  @override
  bool shouldRepaint(_PolygonPainter old) {
    return latLngPoints.length != old.latLngPoints.length ||
        provisionalLatLng != old.provisionalLatLng ||
        !listEquals(latLngPoints, old.latLngPoints) ||
        cameraGeneration != old.cameraGeneration;
  }
}
