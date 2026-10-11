import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/mushroom/mushroom_waypoint_forecast_service.dart';
import 'package:my_spots/views/widgets/map/mushroom_color_utils.dart';

/// Panneau "Où aller ?" pour les waypoints champignons.
class MushroomWaypointPanel extends StatefulWidget {
  final MushroomWaypointForecastService forecastService;
  final Function(LatLng)? onCenterOnWaypoint;
  final Function(Waypoint)? onOpenSheet;
  final Function(int)? onDayChanged;
  final Function(List<List<MushroomForecast>>)? onForecastsLoaded;

  const MushroomWaypointPanel({
    super.key,
    required this.forecastService,
    this.onCenterOnWaypoint,
    this.onOpenSheet,
    this.onDayChanged,
    this.onForecastsLoaded,
  });

  @override
  State<MushroomWaypointPanel> createState() => _MushroomWaypointPanelState();
}

class _MushroomWaypointPanelState extends State<MushroomWaypointPanel> {
  int _selectedDay = 0; // J+0 to J+7
  List<List<MushroomForecast>>? _forecasts;
  bool _isLoading = false;
  String? _errorMessage;
  bool _sortByDistance = false;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadForecasts();
    _getCurrentPosition();
  }

  @override
  void didUpdateWidget(covariant MushroomWaypointPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if waypoint list changed (detected by cache invalidation)
    if (oldWidget.forecastService != widget.forecastService) {
      _loadForecasts();
    }
  }

  Future<void> _getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      // GPS non disponible, tri par distance désactivé
    }
  }

  Future<void> _loadForecasts() async {
    if (AppSettings.offlineModeEnabled) {
      setState(() {
        _errorMessage = 'Indisponible en mode hors-ligne (pas de cache)';
        _forecasts = null;
      });
      return;
    }

    final mushroomWaypoints = WaypointStore.waypoints
        .where((wp) => wp.category == WaypointCategory.mushrooms)
        .toList();

    if (mushroomWaypoints.isEmpty) {
      setState(() {
        _errorMessage = 'Aucun waypoint champignon enregistré';
        _forecasts = null;
      });
      return;
    }

    if (mushroomWaypoints.length > 50) {
      setState(() {
        _errorMessage = 'Trop de waypoints (max 50)';
        _forecasts = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final forecasts = await widget.forecastService.calculateForWaypoints(
        mushroomWaypoints,
      );

      if (forecasts == null) {
        setState(() {
          _errorMessage = 'Erreur de chargement (hors-ligne ou réseau)';
          _forecasts = null;
        });
      } else {
        setState(() {
          _forecasts = forecasts;
        });
        widget.onForecastsLoaded?.call(forecasts);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: ${e.toString()}';
        _forecasts = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<({Waypoint waypoint, MushroomForecast forecast, int bestDay})>
  _getSortedWaypoints() {
    if (_forecasts == null) return [];

    final mushroomWaypoints = WaypointStore.waypoints
        .where((wp) => wp.category == WaypointCategory.mushrooms)
        .toList();

    final results =
        <({Waypoint waypoint, MushroomForecast forecast, int bestDay})>[];

    for (int i = 0; i < mushroomWaypoints.length; i++) {
      final waypoint = mushroomWaypoints[i];
      final dayForecasts = _forecasts![i];

      // Trouver le meilleur jour de la semaine
      final suitableForecasts = dayForecasts
          .where((f) => f.habitat != HabitatStatus.excluded)
          .toList();

      if (suitableForecasts.isEmpty) continue;

      final bestForecast = suitableForecasts.reduce(
        (a, b) => a.index >= b.index ? a : b,
      );
      final bestDay = dayForecasts.indexOf(bestForecast);

      results.add((
        waypoint: waypoint,
        forecast: bestForecast,
        bestDay: bestDay,
      ));
    }

    // Tri
    if (_sortByDistance && _currentPosition != null) {
      results.sort((a, b) {
        final distA = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a.waypoint.latitude,
          a.waypoint.longitude,
        );
        final distB = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b.waypoint.latitude,
          b.waypoint.longitude,
        );
        return distA.compareTo(distB);
      });
    } else {
      // Tri par indice du jour sélectionné
      results.sort((a, b) => a.forecast.index.compareTo(b.forecast.index));
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1929),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Où aller ?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Toggle tri
                if (_currentPosition != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _sortByDistance = !_sortByDistance;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          _sortByDistance ? Icons.location_on : Icons.sort,
                          color: Colors.tealAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _sortByDistance ? 'Distance' : 'Indice',
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Day selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(8, (day) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(day == 0 ? 'J+0' : 'J+$day'),
                      selected: _selectedDay == day,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedDay = day;
                          });
                          widget.onDayChanged?.call(day);
                        }
                      },
                      selectedColor: Colors.tealAccent.withValues(alpha: 0.3),
                      checkmarkColor: Colors.tealAccent,
                      labelStyle: TextStyle(
                        color: _selectedDay == day
                            ? Colors.tealAccent
                            : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            )
          else if (_forecasts != null) ...[
            // Banner for waypoints without data
            if (MushroomWaypointForecastService.countWithoutData(_forecasts!) >
                0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  '${MushroomWaypointForecastService.countWithoutData(_forecasts!)} coin${MushroomWaypointForecastService.countWithoutData(_forecasts!) > 1 ? 's' : ''} sans donnée',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                  ),
                ),
              ),
            // Waypoint list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _getSortedWaypoints().length,
                itemBuilder: (context, index) {
                  final item = _getSortedWaypoints()[index];
                  return _WaypointListItem(
                    waypoint: item.waypoint,
                    forecast: item.forecast,
                    bestDay: item.bestDay,
                    onTap: () {
                      widget.onCenterOnWaypoint?.call(
                        LatLng(item.waypoint.latitude, item.waypoint.longitude),
                      );
                    },
                    onLongPress: () {
                      widget.onOpenSheet?.call(item.waypoint);
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _WaypointListItem extends StatelessWidget {
  final Waypoint waypoint;
  final MushroomForecast forecast;
  final int bestDay;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _WaypointListItem({
    required this.waypoint,
    required this.forecast,
    required this.bestDay,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = indexToGradientColor(forecast.index);
    final isExcluded = forecast.habitat == HabitatStatus.excluded;
    final displayColor = isExcluded ? Colors.grey : color;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white12.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            // Pastille colorée
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: displayColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  forecast.index.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Nom et détails
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waypoint.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Meilleur: J+$bestDay · Indice ${forecast.index}',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Distance si disponible
            // TODO: ajouter distance calculée
          ],
        ),
      ),
    );
  }
}
