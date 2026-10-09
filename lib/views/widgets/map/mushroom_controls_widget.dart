import 'package:flutter/material.dart';
import 'package:my_spots/app_settings.dart';

class MushroomControlsWidget extends StatefulWidget {
  final VoidCallback? onChanged;

  const MushroomControlsWidget({super.key, this.onChanged});

  @override
  State<MushroomControlsWidget> createState() => _MushroomControlsWidgetState();
}

class _MushroomControlsWidgetState extends State<MushroomControlsWidget> {
  Future<void> _toggle(bool? value) async {
    if (value == null) return;
    await AppSettings.saveMushroomOverlayEnabled(value);
    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call();
  }

  Future<void> _setOpacity(double value) async {
    await AppSettings.saveMushroomOverlayOpacity(value);
    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: AppSettings.mushroomOverlayEnabled,
                    onChanged: _toggle,
                    activeColor: Colors.tealAccent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.nature,
                  color: Colors.lightGreenAccent,
                  size: 16,
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _toggle(!AppSettings.mushroomOverlayEnabled),
                  child: const Text(
                    'Prévision champignons',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (AppSettings.mushroomOverlayEnabled) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: 170,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: AppSettings.mushroomOverlayOpacity,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label:
                        '${(AppSettings.mushroomOverlayOpacity * 100).round()}%',
                    onChanged: _setOpacity,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
