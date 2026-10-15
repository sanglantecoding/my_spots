import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/mushroom/mushroom_waypoint_forecast_service.dart';
import 'package:my_spots/views/widgets/map/mushroom_waypoint_panel.dart';
import 'package:my_spots/views/widgets/map/mushroom_palette_button.dart';

class MushroomControlsWidget extends StatefulWidget {
  final VoidCallback? onChanged;
  final VoidCallback? onStyleChanged;
  final MushroomWaypointForecastService? forecastService;
  final Function(LatLng)? onCenterOnWaypoint;
  final Function(Waypoint)? onOpenSheet;
  final Function(int)? onDayChanged;
  final Function(Map<String, List<MushroomForecast>>)? onForecastsLoaded;
  final LatLng? currentPosition;
  final int selectedDay;

  const MushroomControlsWidget({
    super.key,
    this.onChanged,
    this.onStyleChanged,
    this.forecastService,
    this.onCenterOnWaypoint,
    this.onOpenSheet,
    this.onDayChanged,
    this.onForecastsLoaded,
    this.currentPosition,
    this.selectedDay = 0,
  });

  @override
  State<MushroomControlsWidget> createState() => _MushroomControlsWidgetState();
}

class _MushroomControlsWidgetState extends State<MushroomControlsWidget> {
  Widget _paletteChip(String label, MushroomPalette palette) {
    return MushroomPaletteButton(
      palette: palette,
      label: label,
      onTap: () => _setPalette(palette),
    );
  }

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
    (widget.onStyleChanged ?? widget.onChanged)?.call();
  }

  Future<void> _setPalette(MushroomPalette palette) async {
    await AppSettings.saveMushroomPalette(palette);
    if (!mounted) return;
    setState(() {});
    (widget.onStyleChanged ?? widget.onChanged)?.call();
  }

  void _showWaypointPanel(BuildContext context) {
    if (widget.forecastService == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Où aller ?'),
          content: const Text('Service de prévision non disponible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MushroomWaypointPanel(
        forecastService: widget.forecastService!,
        onCenterOnWaypoint: widget.onCenterOnWaypoint,
        onOpenSheet: widget.onOpenSheet,
        onDayChanged: widget.onDayChanged,
        onForecastsLoaded: widget.onForecastsLoaded,
        currentPosition: widget.currentPosition,
        selectedDay: widget.selectedDay,
      ),
    );
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
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _showWaypointPanel(context),
                  child: const Icon(
                    Icons.explore,
                    color: Colors.tealAccent,
                    size: 20,
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
                    label: 'Transparence',
                    onChanged: _setOpacity,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Palette : ',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  _paletteChip('Classique', MushroomPalette.classic),
                  const SizedBox(width: 4),
                  _paletteChip('Contrastée', MushroomPalette.contrasted),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
