import 'dart:async';

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
  final Function(Map<String, List<MushroomForecast>>)? onForecastsLoaded;

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
  Map<String, List<MushroomForecast>>? _forecasts;
  bool _isLoading = false;
  String? _errorMessage;
  bool _sortByDistance = false;
  LatLng? _currentPosition;
  String? _loadingStep;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _loadForecasts();
    _getCurrentPosition();
  }

  @override
  void dispose() {
    _isCancelled = true;
    super.dispose();
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
    if (_isCancelled) return;
    if (!mounted) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted && !_isCancelled) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      // GPS non disponible, tri par distance désactivé
    }
  }

  Future<void> _loadForecasts() async {
    if (_isCancelled) return;

    if (AppSettings.offlineModeEnabled) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Indisponible en mode hors-ligne (pas de cache)';
          _forecasts = null;
          _loadingStep = null;
        });
      }
      return;
    }

    final mushroomWaypoints = WaypointStore.waypoints
        .where((wp) => wp.category == WaypointCategory.mushrooms)
        .toList();

    if (mushroomWaypoints.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Aucun waypoint champignon enregistré';
          _forecasts = null;
          _loadingStep = null;
        });
      }
      return;
    }

    if (mushroomWaypoints.length > 50) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Trop de waypoints (max 50)';
          _forecasts = null;
          _loadingStep = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _loadingStep = 'altitude';
      });
    }

    try {
      final forecasts = await widget.forecastService
          .calculateForWaypoints(
            mushroomWaypoints,
            onStage: (step) {
              if (mounted && !_isCancelled) {
                setState(() {
                  _loadingStep = step;
                });
              }
            },
            onWarning: (message) {
              if (mounted && !_isCancelled) {
                setState(() {
                  _errorMessage = message;
                });
              }
            },
          )
          .timeout(const Duration(seconds: 90));

      if (_isCancelled) return;

      if (forecasts == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Erreur de chargement (hors-ligne ou réseau)';
            _forecasts = null;
            _loadingStep = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _forecasts = forecasts;
            _loadingStep = null;
          });
        }
        widget.onForecastsLoaded?.call(forecasts);
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _errorMessage = 'Délai dépassé (60 s)';
          _forecasts = null;
          _loadingStep = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur: ${e.toString()}';
          _forecasts = null;
          _loadingStep = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<
    ({
      Waypoint waypoint,
      MushroomForecast forecast,
      int bestDay,
      double? distance,
    })
  >
  _getSortedWaypoints() {
    if (_forecasts == null) return [];

    final mushroomWaypoints = WaypointStore.waypoints
        .where((wp) => wp.category == WaypointCategory.mushrooms)
        .toList();

    final results =
        <
          ({
            Waypoint waypoint,
            MushroomForecast forecast,
            int bestDay,
            double? distance,
          })
        >[];

    for (final waypoint in mushroomWaypoints) {
      final key = '${waypoint.latitude},${waypoint.longitude}';
      final dayForecasts = _forecasts![key];

      if (dayForecasts == null || dayForecasts.isEmpty) continue;

      // Use the selected day's forecast for sorting
      final selectedDayIndex = _selectedDay;
      if (selectedDayIndex >= dayForecasts.length) continue;

      final selectedForecast = dayForecasts[selectedDayIndex];
      if (selectedForecast.habitat == HabitatStatus.excluded) continue;

      // Find the best day of the week
      final suitableForecasts = dayForecasts
          .where((f) => f.habitat != HabitatStatus.excluded)
          .toList();

      if (suitableForecasts.isEmpty) continue;

      final bestForecast = suitableForecasts.reduce(
        (a, b) => a.index >= b.index ? a : b,
      );
      final bestDay = dayForecasts.indexOf(bestForecast);

      // Calculate distance if GPS available
      double? distance;
      if (_currentPosition != null) {
        distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          waypoint.latitude,
          waypoint.longitude,
        );
      }

      results.add((
        waypoint: waypoint,
        forecast: selectedForecast, // Use selected day's forecast for sorting
        bestDay: bestDay,
        distance: distance,
      ));
    }

    // Tri
    if (_sortByDistance && _currentPosition != null) {
      results.sort((a, b) {
        final distA = a.distance ?? double.infinity;
        final distB = b.distance ?? double.infinity;
        return distA.compareTo(distB);
      });
    } else {
      // Sort by selected day index descending (best to worst)
      results.sort((a, b) => b.forecast.index.compareTo(a.forecast.index));
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    _loadingStep != null
                        ? 'Chargement : $_loadingStep...'
                        : 'Chargement...',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadForecasts,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          else if (_forecasts != null) ...[
            // Warning banner for timed-out stages
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orangeAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                    selectedDay: _selectedDay,
                    distance: item.distance,
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
  final int selectedDay;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double? distance;

  const _WaypointListItem({
    required this.waypoint,
    required this.forecast,
    required this.bestDay,
    required this.selectedDay,
    required this.onTap,
    required this.onLongPress,
    this.distance,
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
                    'J+$bestDay (meilleur) · J+$selectedDay: ${forecast.index}',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Distance si disponible
            if (distance != null)
              Text(
                _formatDistance(distance!),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
    }
  }
}
