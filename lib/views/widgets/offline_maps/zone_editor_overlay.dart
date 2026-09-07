import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Interactive rectangle-selection overlay displayed on the map
/// during zone-adjustment mode.
///
/// Features:
/// - Drag the rectangle body to translate the whole selection.
/// - Resize via 8 handles (corners + edge midpoints).
/// - FAB confirmation button pinned to the bottom of the screen.
/// Returns [LatLngBounds] via [onConfirm] when the button is tapped.
class ZoneEditorOverlay extends StatefulWidget {
  /// Center point for the initial rectangle.
  final LatLng centerPoint;

  /// Called when the user confirms the bounds.
  final void Function(LatLngBounds bounds) onConfirm;

  /// Called when the user cancels the adjustment.
  final VoidCallback onCancel;

  /// Optional controller from the underlying [FlutterMap]. When provided,
  /// bounds-to-LatLng conversions use the real map camera instead of an
  /// unattached default [MapController] (which would return garbage for the
  /// current visible region and break [onConfirm]).
  final MapController? mapController;

  const ZoneEditorOverlay({
    super.key,
    required this.centerPoint,
    required this.onConfirm,
    required this.onCancel,
    this.mapController,
  });

  @override
  State<ZoneEditorOverlay> createState() => _ZoneEditorOverlayState();
}

class _ZoneEditorOverlayState extends State<ZoneEditorOverlay> {
  /// Fallback controller used only if the host does not inject one.
  /// NOTE: an unattached MapController has a default (0,0) camera, so any
  /// `screenOffsetToLatLng` would return bogus coordinates. Hosts MUST pass
  /// the same controller used by the [FlutterMap] in the background.
  late final MapController _mapController = widget.mapController ?? MapController();

  /// Pixel coordinates of the selection rectangle.
  double _left = 0;
  double _top = 0;
  double _right = 0;
  double _bottom = 0;

  Size _mapSize = Size.zero;
  bool _layoutInitialized = false;
  static const double _initialWidth = 280;
  static const double _initialHeight = 220;
  static const double _minSize = 60;
  static const double _handleSize = 28;

  /// `null` → idle. A handle value → resize. `_Handle.drag` → global translate.
  _Handle? _activeHandle;

  @override
  void initState() {
    super.initState();
  }

  void _initRectOnLayout(Size mapSize) {
    if (_layoutInitialized && _mapSize == mapSize) return;
    final Size newSize = Size(
      mapSize.width.isFinite && mapSize.width > 0 ? mapSize.width : _mapSize.width,
      mapSize.height.isFinite && mapSize.height > 0 ? mapSize.height : _mapSize.height,
    );
    if (newSize.width <= 0 || newSize.height <= 0) return;

    if (!_layoutInitialized) {
      // First time: centre the rect on the available area.
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
      // Subsequent re-layouts: keep the rect edges proportional
      // (we don't shrink the available area when the FAB is visible).
      _mapSize = newSize;
    }
  }

  LatLng _pixelToLatLng(double px, double py) {
    return _mapController.camera.screenOffsetToLatLng(Offset(px, py));
  }

  LatLngBounds get _bounds => LatLngBounds(
        _pixelToLatLng(_left, _bottom),
        _pixelToLatLng(_right, _top),
      );

  /// Translates the rectangle by (dx, dy) while STRICTLY preserving its
  /// width and height. Clamping is applied only to the top-left origin so that
  /// the dimensions are never altered by a boundary collision.
  void _moveRect(double dx, double dy) {
    setState(() {
      final double width  = _right  - _left;
      final double height = _bottom - _top;

      // Clamp only the origin; dimensions stay fixed.
      double newLeft = (_left + dx).clamp(0.0, _mapSize.width  - width);
      double newTop  = (_top  + dy).clamp(0.0, _mapSize.height - height);

      _left   = newLeft;
      _top    = newTop;
      _right  = newLeft + width;
      _bottom = newTop  + height;
    });
  }

  /// Returns the pixel centre of [handle]; null for [_Handle.drag].
  Offset? _handleCenter(_Handle handle) {
    switch (handle) {
      case _Handle.topLeft:      return Offset(_left, _top);
      case _Handle.topRight:     return Offset(_right, _top);
      case _Handle.bottomLeft:   return Offset(_left, _bottom);
      case _Handle.bottomRight:  return Offset(_right, _bottom);
      case _Handle.middleLeft:   return Offset(_left, (_top + _bottom) / 2);
      case _Handle.middleRight:  return Offset(_right, (_top + _bottom) / 2);
      case _Handle.middleTop:    return Offset((_left + _right) / 2, _top);
      case _Handle.middleBottom: return Offset((_left + _right) / 2, _bottom);
      case _Handle.drag:         return null;
    }
  }

  /// Resizes the rectangle for [handle] by (dx, dy).
  ///
  /// Each axis is clamped so that the rect never leaves the map bounds and
  /// never collapses below [_minSize] on any side. The two axes are clamped
  /// independently, which preserves the [_minSize] invariant even when the
  /// handle is a corner dragged diagonally into a corner of the screen.
  ///
  /// Every case ends with a [break] to prevent Dart's fall-through from
  /// corrupting the next case (this was a latent bug in the previous
  /// implementation).
  void _resizeRect(_Handle handle, double dx, double dy) {
    setState(() {
      switch (handle) {
        case _Handle.topLeft:
          _left  = (_left  + dx).clamp(0.0, _right  - _minSize);
          _top   = (_top   + dy).clamp(0.0, _bottom - _minSize);
          break;
        case _Handle.topRight:
          _right = (_right + dx).clamp(_left + _minSize, _mapSize.width);
          _top   = (_top   + dy).clamp(0.0, _bottom - _minSize);
          break;
        case _Handle.bottomLeft:
          _left   = (_left   + dx).clamp(0.0, _right - _minSize);
          _bottom = (_bottom + dy).clamp(_top + _minSize, _mapSize.height);
          break;
        case _Handle.bottomRight:
          _right  = (_right  + dx).clamp(_left + _minSize, _mapSize.width);
          _bottom = (_bottom + dy).clamp(_top + _minSize, _mapSize.height);
          break;
        case _Handle.middleLeft:
          _left = (_left + dx).clamp(0.0, _right - _minSize);
          break;
        case _Handle.middleRight:
          _right = (_right + dx).clamp(_left + _minSize, _mapSize.width);
          break;
        case _Handle.middleTop:
          _top = (_top + dy).clamp(0.0, _bottom - _minSize);
          break;
        case _Handle.middleBottom:
          _bottom = (_bottom + dy).clamp(_top + _minSize, _mapSize.height);
          break;
        case _Handle.drag:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initRectOnLayout(Size(constraints.maxWidth, constraints.maxHeight));
        });
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Layer 0: Pure drawing (no hit-test) ──
            //
            // The CustomPaint used to be wrapped in a bare Positioned.fill,
            // which made the whole screen opaque to hit-testing and blocked
            // gestures from reaching the underlying [FlutterMap] (a sibling
            // inside the outer Stack of MapScreen). Wrapping it in an
            // [IgnorePointer] makes the painter truly hit-test transparent,
            // so taps and pans in the empty areas of the overlay fall through
            // to the map below.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _SelectionPainter(
                  left: _left, top: _top, right: _right, bottom: _bottom,
                )),
              ),
            ),

            // ── Layer 1: Body drag detector (opaque inside the rect) ──
            Positioned(
              left: _left, top: _top,
              width: _right - _left, height: _bottom - _top,
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
              _Handle.topLeft, _Handle.topRight,
              _Handle.bottomLeft, _Handle.bottomRight,
              _Handle.middleLeft, _Handle.middleRight,
              _Handle.middleTop, _Handle.middleBottom,
            ])
              _buildHandle(h),
            // ── Layer 3: Top bar (Annuler + title) (opaque) ──
            _buildTopBar(context),

            // ── Layer 4: Confirmation FAB (opaque) ──
            _buildConfirmButton(),
          ],
        );
      },
    );
  }

  /// Builds an opaque hit box for a single resize handle.
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

  /// Top bar with cancel button (opaque).
  ///
  /// The earlier layout paired the [onCancel] button on the left with a
  /// "Ajuster la zone" badge on the right. The badge added visual noise and
  /// also occupied the top-right corner of the screen, which can shadow the
  /// "topRight" handle of the selection rectangle. We removed the badge and
  /// keep only the cancel control on the left.
  Widget _buildTopBar(BuildContext context) => Positioned(
        left: 0, right: 0,
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
                      Text('Annuler', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  /// Confirmation FAB — anchored at the bottom-center of the screen.
  ///
  /// CRITICAL: this widget is wrapped in a *plain* `Align` (not `Positioned`).
  /// `Positioned(left: 0, right: 0, bottom: 0)` would have stretched the
  /// `GestureDetector` to a full-screen-width opaque hit area, which would
  /// intercept every pointer event along the bottom strip — making the
  /// bottom handles (bottomLeft / middleBottom / bottomRight) of the
  /// selection rectangle un-tappable whenever they crossed the FAB's band.
  ///
  /// Using `Align` alone keeps the FAB at its intrinsic width; taps on
  /// background space to the left/right of the FAB pass cleanly through to
  /// the underlying [FlutterMap]. The bottom edge of the selection rectangle
  /// can therefore be dragged all the way to `_mapSize.height`.
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              icon: const Icon(Icons.check, size: 22),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Text(
                  'Valider et enregistrer la zone',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              onPressed: () => widget.onConfirm(_bounds),
            ),
          ),
        ),
      );
}

enum _Handle {
  drag,
  topLeft, topRight, bottomLeft, bottomRight,
  middleLeft, middleRight, middleTop, middleBottom,
}

class _SelectionPainter extends CustomPainter {
  final double left, top, right, bottom;
  _SelectionPainter({required this.left, required this.top, required this.right, required this.bottom});
  static const double _hs = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(left, top, right, bottom);
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0D6999).withValues(alpha: 0.12)..style = PaintingStyle.fill);
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0D6999)..style = PaintingStyle.stroke..strokeWidth = 2.5);
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
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), Paint()..color = const Color(0xFF0D6999));
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawEdge(Canvas c, double x, double y) {
    final r = Rect.fromCenter(center: Offset(x, y), width: _hs * 0.65, height: _hs * 0.65);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), Paint()..color = const Color(0xFF0D6999));
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      left != old.left || top != old.top || right != old.right || bottom != old.bottom;
}

