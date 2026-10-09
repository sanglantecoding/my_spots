import 'package:flutter/material.dart';

class MushroomDateSlider extends StatelessWidget {
  const MushroomDateSlider({
    super.key,
    required this.currentIndex,
    required this.dates,
    required this.bestDayLabel,
    required this.onChanged,
  });

  final int currentIndex;
  final List<DateTime> dates;
  final String bestDayLabel;
  final ValueChanged<int> onChanged;

  String _formatShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month,
                  color: Colors.tealAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'J+$currentIndex · ${_formatShort(dates[currentIndex])}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    bestDayLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF80CBC4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: double.infinity,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: Colors.tealAccent.withValues(alpha: 0.8),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: Colors.tealAccent,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                  valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                ),
                child: Slider(
                  value: currentIndex.toDouble(),
                  min: 0,
                  max: 7,
                  divisions: 7,
                  label: 'J+$currentIndex',
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Météo à maille d\'environ 25 km : les écarts entre cellules viennent surtout du relief, de la forêt et de l\'habitat.',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
