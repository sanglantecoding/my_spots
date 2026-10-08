import 'package:flutter/material.dart';
import 'package:my_spots/app_settings.dart';

/// Widget de contrôle LiDAR/Bathymétrie pour la carte marine.
class BathymetryControlsWidget extends StatefulWidget {
  /// Notifie le parent (MapScreen) après chaque mutation afin que
  /// MapView reçoive les nouvelles valeurs bathymetryEnabled/Opacity.
  final VoidCallback? onChanged;

  const BathymetryControlsWidget({super.key, this.onChanged});

  @override
  State<BathymetryControlsWidget> createState() =>
      _BathymetryControlsWidgetState();
}

class _BathymetryControlsWidgetState extends State<BathymetryControlsWidget> {
  Future<void> _toggle(bool? value) async {
    if (value == null) return;
    // 1) Attendre la mutation COMPLÈTE du static (await interne SharedPreferences).
    await AppSettings.saveBathymetryOverlayEnabled(value);
    if (!mounted) return;
    // 2) Rebuild local : case à cocher + apparition du slider.
    setState(() {});
    // 3) Propager au parent : rebuild MapView → couches LiDAR ajoutées/retirées.
    widget.onChanged?.call();
  }

  Future<void> _setOpacity(double value) async {
    await AppSettings.saveBathymetryOverlayOpacity(value);
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
                    value: AppSettings.bathymetryOverlayEnabled,
                    onChanged:
                        _toggle, // ⚠️ UN seul gestionnaire, pas d'InkWell autour
                    activeColor: Colors.blueAccent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.terrain, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _toggle(!AppSettings.bathymetryOverlayEnabled),
                  child: const Text(
                    'LiDAR / Bathy',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
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
