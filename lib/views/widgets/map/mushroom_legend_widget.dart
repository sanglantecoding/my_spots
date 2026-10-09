import 'package:flutter/material.dart';
import 'package:my_spots/views/widgets/map/mushroom_color_utils.dart';

class MushroomLegendWidget extends StatefulWidget {
  const MushroomLegendWidget({super.key});

  @override
  State<MushroomLegendWidget> createState() => _MushroomLegendWidgetState();
}

class _MushroomLegendWidgetState extends State<MushroomLegendWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final stops = legendGradientStops();
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.palette, color: Colors.white70, size: 14),
                  const SizedBox(width: 5),
                  const Text(
                    'Légende',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white60,
                    size: 18,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                const Text(
                  'Indice de favorabilité',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 10,
                  width: 160,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: LinearGradient(colors: stops),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const SizedBox(
                  width: 160,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0',
                        style: TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                      Text(
                        '50',
                        style: TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                      Text(
                        '100',
                        style: TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _LegendRow(
                  color: Colors.grey.withValues(alpha: 0.35),
                  label: 'Habitat exclu',
                  hatch: true,
                ),
                const SizedBox(height: 3),
                _LegendRow(
                  color: const Color(0xFF7CB342).withValues(alpha: 0.45),
                  label: 'Habitat non vérifié',
                  attenuated: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    this.hatch = false,
    this.attenuated = false,
  });

  final Color color;
  final String label;
  final bool hatch;
  final bool attenuated;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 12,
          child: CustomPaint(
            painter: _LegendSwatchPainter(color: color, hatch: hatch),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          attenuated ? '$label (atténué)' : label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _LegendSwatchPainter extends CustomPainter {
  _LegendSwatchPainter({required this.color, required this.hatch});

  final Color color;
  final bool hatch;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    if (hatch) {
      final paint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 1;
      for (var i = -size.height; i < size.width + size.height; i += 3) {
        canvas.drawLine(
          Offset(i, 0),
          Offset(i - size.height, size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LegendSwatchPainter oldDelegate) =>
      color != oldDelegate.color || hatch != oldDelegate.hatch;
}
