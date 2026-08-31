import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/settings_page.dart';
import 'package:my_spots/services/gps_service.dart';
import 'package:my_spots/services/alarm_service.dart';
import 'package:my_spots/services/marine_map_service.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/widgets/satellite_bottom_sheet.dart';
import 'package:my_spots/widgets/navigation_overlay.dart';
import 'package:my_spots/views/dialogs/waypoint_editor_sheet.dart';
import 'package:my_spots/controllers/gps_controller.dart';
import 'package:my_spots/views/widgets/map/gps_marker_widget.dart';
import 'package:my_spots/views/widgets/map/selected_waypoint_panel.dart';
import 'package:my_spots/views/widgets/map/map_controls_widget.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  final Waypoint? centerOn;

  const MapScreen({super.key, this.centerOn});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  double _currentSpeed = 0.0;
  double _currentZoom = 15.0;
  bool _isLoading = true;
  bool _isFollowingUser = false;
  final TextEditingController _waypointNameController = TextEditingController();
  Waypoint? _selectedWaypoint;
  Waypoint? _navigationTarget; // Waypoint ciblé pour la navigation active
  String gpsStatus = 'INITIALISATION...';
  Color gpsStatusColor = Colors.orange;
  LatLngBounds? _mapVisibleBounds;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription<AlarmEvent>? _alarmSubscription;

  void _onMapCameraChanged() {
    final bounds = _mapController.camera.visibleBounds;
    if (_mapVisibleBounds != null &&
        _mapVisibleBounds!.isOverlapping(bounds) &&
        _boundsNearlyEqual(_mapVisibleBounds!, bounds)) {
      return;
    }
    setState(() => _mapVisibleBounds = bounds);
  }

  bool _boundsNearlyEqual(LatLngBounds a, LatLngBounds b) {
    const epsilon = 0.002;
    return (a.north - b.north).abs() < epsilon &&
        (a.south - b.south).abs() < epsilon &&
        (a.east - b.east).abs() < epsilon &&
        (a.west - b.west).abs() < epsilon;
  }

  void _logMapTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    MapTileErrorLogger.logTileError(tile, error, stackTrace);
  }

  Widget _buildBathymetryOverlayControls() {
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
                setState(() {});
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
                        setState(() {});
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
                      setState(() {});
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

  @override
  void initState() {
    super.initState();

    // Initialiser le service d'alarme
    AlarmService.initialize();

    // S'abonner au flux broadcast d'événements d'alarme
    _alarmSubscription = AlarmService.onAlarmEvent.listen((event) {
      if (!mounted) return;
      // On rebuild sur tout changement d'état vu par MapScreen
      // (icône haut-parleur, etc.)
      setState(() {});
    });

    _startLocationTracking();

    if (widget.centerOn != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _mapController.move(
          LatLng(widget.centerOn!.latitude, widget.centerOn!.longitude),
          16.0,
        );
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _alarmSubscription?.cancel();
    _waypointNameController.dispose();
    super.dispose();
  }

  /// Démarre le suivi GPS en temps réel avec GpsController
  Future<void> _startLocationTracking() async {
    // S'abonner au flux de position de GpsController
    _positionSubscription = GpsController.instance.positionStream.listen(
      (position) {
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            _currentSpeed = position.speed;
            _isLoading = false;
            // Utilisation de la logique unifiée pour le statut GPS
            final status = GpsService.getGpsStatus(position.accuracy);
            gpsStatus = GpsService.getGpsDetailedStatusText(status);
            gpsStatusColor = GpsService.getGpsStatusColor(status);
          });
          // Mettre à jour la position pour les alarmes
          AlarmService.updatePosition(_currentPosition!);
          // Recentre automatiquement la carte si le suivi est activé
          if (_isFollowingUser && _currentPosition != null) {
            _mapController.move(_currentPosition!, 15.0);
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            gpsStatus = 'ERREUR GPS';
            gpsStatusColor = Colors.red;
            _isLoading = false;
          });
        }
      },
    );

    // S'abonner au flux d'état de GpsController
    _stateSubscription = GpsController.instance.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          switch (state) {
            case GpsState.stopped:
              gpsStatus = 'GPS ARRÊTÉ';
              gpsStatusColor = Colors.grey;
              break;
            case GpsState.initializing:
              gpsStatus = 'INITIALISATION...';
              gpsStatusColor = Colors.orange;
              break;
            case GpsState.stationary:
              gpsStatus = 'GPS ACTIF (IMMOBILE)';
              gpsStatusColor = Colors.green;
              break;
            case GpsState.moving:
              gpsStatus = 'GPS ACTIF (EN MOUVEMENT)';
              gpsStatusColor = Colors.green;
              break;
            case GpsState.error:
              gpsStatus = GpsController.instance.errorMessage ?? 'ERREUR GPS';
              gpsStatusColor = Colors.red;
              break;
          }
        });
      }
    });

    // Démarrer GpsController si pas déjà démarré
    await GpsController.instance.start();
  }

  void _recenterMap() {
    if (_currentPosition != null) {
      setState(() {
        _isFollowingUser = true;
      });
      _mapController.move(_currentPosition!, 15.0);
    }
  }

  Future<void> _showAddWaypointDialog() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position GPS non disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final frozenPosition = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    final int waypointNumber = WaypointStore.waypoints.length + 1;
    final defaultName = 'WPT $waypointNumber';

    final outcome = await showWaypointEditorSheet(
      context: context,
      title: 'NOUVEAU WAYPOINT',
      icon: Icons.anchor,
      position: frozenPosition,
      initialName: defaultName,
      initialCategory: WaypointCategory.fishing,
      initialColorHex: 'FFFFEB3B',
      initialDate: DateTime.now(),
      isEditing: false,
    );

    if (outcome?.waypoint == null) return;

    final newWaypoint = outcome!.waypoint!;
    setState(() {
      WaypointStore.waypoints.add(newWaypoint);
      _selectedWaypoint = newWaypoint; // devient la cible active
    });
    await WaypointStore.save();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Waypoint "${newWaypoint.name}" enregistré'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getFormattedSpeed() {
    if (AppSettings.speedUnit == SpeedUnit.knots) {
      double knots = _currentSpeed * 1.94384;
      return knots.toStringAsFixed(1);
    } else {
      double kmh = _currentSpeed * 3.6;
      return kmh.toStringAsFixed(1);
    }
  }

  String _getSpeedUnit() {
    return AppSettings.speedUnit == SpeedUnit.knots ? 'nds' : 'km/h';
  }

  IconData _getWaypointCategoryIcon(Waypoint waypoint) {
    switch (waypoint.category) {
      case WaypointCategory.mushrooms:
        return Icons.park; // Champignons / forêt
      case WaypointCategory.fishing:
        return Icons.anchor; // Ancre pour la pêche
      case WaypointCategory.other:
        // Vérifier si le nom contient "Voiture"
        if (waypoint.name.toLowerCase().contains('voiture')) {
          return Icons.directions_car; // Voiture
        } else {
          return Icons.location_on; // Icône standard de waypoint
        }
    }
  }

  Future<void> _centerOnTargetAndUser() async {
    if (_currentPosition == null || _selectedWaypoint == null) return;
    final bounds = LatLngBounds.fromPoints([
      _currentPosition!,
      LatLng(_selectedWaypoint!.latitude, _selectedWaypoint!.longitude),
    ]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CARTE'),
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
        leadingWidth: 100,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () {
                  Navigator.pop(context);
                },
                tooltip: 'Retour',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const SatelliteBottomSheet(),
                  );
                },
                child: Icon(
                  gpsStatus == 'GPS OK' ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: gpsStatusColor,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              setState(() {});
            },
            tooltip: 'Paramètres',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue),
                  SizedBox(height: 16),
                  Text(
                    'Chargement de la carte...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _currentPosition ?? AppSettings.getDefaultMapCenter(),
                    initialZoom: _currentZoom,
                    minZoom: AppSettings.getMapMinZoom(),
                    maxZoom: AppSettings.getMapMaxZoom(),
                    onPositionChanged: (position, hasGesture) {
                      // Met à jour _currentZoom seulement en cas de changement significatif
                      if ((position.zoom - _currentZoom).abs() > 0.1) {
                        setState(() {
                          _currentZoom = position.zoom;
                        });
                      }
                    },
                    onMapEvent: (event) {
                      if (event is MapEventMove ||
                          event is MapEventRotate ||
                          event is MapEventNonRotatedSizeChange) {
                        _onMapCameraChanged();
                      }
                    },
                    onPointerDown: (event, point) {
                      // Désactiver le suivi automatique quand l'utilisateur déplace la carte manuellement
                      if (_isFollowingUser) {
                        setState(() {
                          _isFollowingUser = false;
                        });
                      }
                    },
                  ),
                  children: [
                    if (AppSettings.mapType == MapType.marine) ...[
                      ...MarineMapService.getActiveMarineTileLayers(
                        _currentZoom,
                      ),
                      if (AppSettings.bathymetryOverlayEnabled)
                        ...MarineMapService.getActiveLidarLayers(
                          _mapVisibleBounds,
                          opacity: AppSettings.bathymetryOverlayOpacity,
                        ),
                    ] else
                      TileLayer(
                        key: ValueKey('basemap_${AppSettings.mapType}'),
                        urlTemplate: AppSettings.getMapTileUrl(),
                        userAgentPackageName: MapTileCacheService.packageName,
                        minZoom: AppSettings.getMapMinZoom(),
                        minNativeZoom: AppSettings.getMapMinNativeZoom(),
                        maxNativeZoom: AppSettings.getMapMaxNativeZoom(),
                        maxZoom: AppSettings.getMapMaxZoom(),
                        tileProvider:
                            MapTileCacheService.getTileProviderForMapType(
                              AppSettings.mapType,
                            ),
                        errorTileCallback: _logMapTileError,
                      ),
                    if (_currentPosition != null && _selectedWaypoint != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              _currentPosition!,
                              LatLng(
                                _selectedWaypoint!.latitude,
                                _selectedWaypoint!.longitude,
                              ),
                            ],
                            color: Colors.white70.withValues(alpha: 0.8),
                            strokeWidth: 2,
                            pattern: const StrokePattern.dotted(
                              spacingFactor: 1.8,
                            ),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Position GPS actuelle (en premier, donc en arrière-plan)
                        if (_currentPosition != null)
                          Marker(
                            point: _currentPosition!,
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            child: const GpsMarkerWidget(),
                          ),
                        // Waypoints de l'utilisateur (en dernier, donc au premier plan)
                        if (AppSettings.waypointsVisible)
                          ...WaypointStore.waypoints
                              .where((waypoint) {
                                if (waypoint.category ==
                                        WaypointCategory.fishing &&
                                    !AppSettings.showFishingWaypointsOnMap) {
                                  return false;
                                }
                                if (waypoint.category ==
                                        WaypointCategory.mushrooms &&
                                    !AppSettings.showMushroomWaypointsOnMap) {
                                  return false;
                                }
                                if (waypoint.category ==
                                        WaypointCategory.other &&
                                    !AppSettings.showOtherWaypointsOnMap) {
                                  return false;
                                }
                                return true;
                              })
                              .map((waypoint) {
                                final showName =
                                    AppSettings.showWaypointNamesOnMap;
                                final showDate =
                                    AppSettings.showWaypointDateOnMap;
                                final hasLabel = showName || showDate;
                                final fontSize =
                                    AppSettings.waypointLabelFontSize;
                                final dateStr =
                                    '${waypoint.createdAt.day.toString().padLeft(2, '0')}/${waypoint.createdAt.month.toString().padLeft(2, '0')}/${waypoint.createdAt.year}';
                                final iconSize = hasLabel
                                    ? (24 + fontSize).roundToDouble()
                                    : 40.0;
                                final markerWidth = hasLabel
                                    ? (140 + fontSize * 3)
                                    : 80.0;
                                final markerHeight = hasLabel
                                    ? (65 + fontSize * 2.5)
                                    : 80.0;
                                return Marker(
                                  key: ValueKey(
                                    'wp_${waypoint.latitude}_${waypoint.longitude}_${waypoint.createdAt.millisecondsSinceEpoch}',
                                  ),
                                  point: LatLng(
                                    waypoint.latitude,
                                    waypoint.longitude,
                                  ),
                                  width: markerWidth,
                                  height: markerHeight,
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(
                                        () => _selectedWaypoint = waypoint,
                                      );
                                    },
                                    child: hasLabel
                                        ? Align(
                                            alignment: Alignment.center,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 0,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFFFDE7,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.black,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (showName)
                                                        Text(
                                                          waypoint.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            color:
                                                                Colors.black87,
                                                            fontSize: fontSize,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      if (showName && showDate)
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                      if (showDate)
                                                        Text(
                                                          dateStr,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            color:
                                                                Colors.black87,
                                                            fontSize:
                                                                fontSize * 0.85,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Opacity(
                                                  opacity: 0.65,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (showName)
                                                        Text(
                                                          waypoint.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            color:
                                                                Colors.black87,
                                                            fontSize: fontSize,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      const SizedBox(height: 2),
                                                      if (showDate)
                                                        Text(
                                                          dateStr,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            color:
                                                                Colors.black87,
                                                            fontSize:
                                                                fontSize * 0.85,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      Icon(
                                                        _getWaypointCategoryIcon(
                                                          waypoint,
                                                        ),
                                                        color: waypoint.color,
                                                        size: iconSize,
                                                        shadows: const [
                                                          Shadow(
                                                            color: Colors.black,
                                                            blurRadius: 4,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Opacity(
                                            opacity: 0.65,
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: Icon(
                                                _getWaypointCategoryIcon(
                                                  waypoint,
                                                ),
                                                color: waypoint.color,
                                                size: 40,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                  ),
                                );
                              }),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: _buildBathymetryOverlayControls(),
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: MapControlsWidget(
                    onRecenter: _recenterMap,
                    onToggleWaypoints: () async {
                      setState(() {
                        AppSettings.waypointsVisible =
                            !AppSettings.waypointsVisible;
                      });
                      await AppSettings.saveWaypointsVisibility(
                        AppSettings.waypointsVisible,
                      );
                    },
                    onAddWaypoint: _showAddWaypointDialog,
                    waypointsVisible: AppSettings.waypointsVisible,
                  ),
                ),
                if (_selectedWaypoint != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 95,
                    child: SelectedWaypointPanel(
                      waypoint: _selectedWaypoint!,
                      currentPosition: _currentPosition,
                      onCenterOnTarget: _centerOnTargetAndUser,
                      onEditWaypoint: (outcome) async {
                        if (outcome != null) {
                          if (outcome.deleted) {
                            setState(() {
                              WaypointStore.waypoints.remove(_selectedWaypoint);
                              _selectedWaypoint = null;
                              _navigationTarget = null;
                            });
                            await WaypointStore.save();
                          } else if (outcome.waypoint != null) {
                            setState(() {
                              final index = WaypointStore.waypoints.indexWhere(
                                (wp) => wp == _selectedWaypoint,
                              );
                              if (index != -1) {
                                WaypointStore.waypoints[index] =
                                    outcome.waypoint!;
                                _selectedWaypoint = outcome.waypoint;
                                if (_navigationTarget == _selectedWaypoint) {
                                  _navigationTarget = outcome.waypoint;
                                }
                              }
                            });
                            await WaypointStore.save();
                          }
                        }
                      },
                      onStartNavigation: () {
                        setState(() {
                          _navigationTarget = _selectedWaypoint;
                        });
                        if (_navigationTarget != null) {
                          AlarmService.startMonitoring(_navigationTarget!);
                        }
                      },
                      onClose: () {
                        AlarmService.stopMonitoring();
                        setState(() {
                          _selectedWaypoint = null;
                          _navigationTarget = null;
                        });
                      },
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: AppSettings.showSpeedOnMap
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blueAccent.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.speed,
                                color: Colors.blueAccent,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${_getFormattedSpeed()} ${_getSpeedUnit()}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Bandeau de navigation active
                if (_navigationTarget != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: NavigationOverlay(
                      targetWaypoint: _navigationTarget!,
                      currentPosition: _currentPosition,
                      onStopNavigation: () {
                        setState(() {
                          _navigationTarget = null;
                        });
                        // Arrêter explicitement le monitoring des alarmes
                        AlarmService.stopMonitoring();
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
