import 'package:flutter/material.dart';
import 'package:my_spots/app_settings.dart';

/// Widget de contrôle LiDAR/Bathymétrie pour la carte marine.
class BathymetryControlsWidget extends StatelessWidget {
  const BathymetryControlsWidget({super.key});

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
            InkWell(
              onTap: () async {
                final enabled = !AppSettings.bathymetryOverlayEnabled;
                await AppSettings.saveBathymetryOverlayEnabled(enabled);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: AppSettings.bathymetryOverlayEnabled,
                      onChanged: (value) async {
                        if (value == null) return;
                        await AppSettings.saveBathymetryOverlayEnabled(value);
                      },
                      activeColor: Colors.blueAccent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.terrain, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'LiDAR / Bathy',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (AppSettings.bathymetryOverlayEnabled) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: 150,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: AppSettings.bathymetryOverlayOpacity,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label:
                        '${(AppSettings.bathymetryOverlayOpacity * 100).round()}%',
                    onChanged: (value) async {
                      await AppSettings.saveBathymetryOverlayOpacity(value);
                    },
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
