import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/controllers/gps_controller.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';
import 'package:my_spots/services/alarm_service.dart';
import 'package:my_spots/services/gps_service.dart';
import 'package:my_spots/services/zone_download/zone_download.dart';
import 'package:my_spots/settings_page.dart';
import 'package:my_spots/views/dialogs/waypoint_editor_sheet.dart';
import 'package:my_spots/views/offline_maps_screen.dart';
import 'package:my_spots/views/widgets/map/distance_measurement_overlay.dart';
import 'package:my_spots/views/widgets/map/map_controls_widget.dart';
import 'package:my_spots/views/widgets/map/map_view.dart';
import 'package:my_spots/views/widgets/map/selected_waypoint_panel.dart';
import 'package:my_spots/views/widgets/offline_maps/new_zone_sheet.dart';
import 'package:my_spots/views/widgets/offline_maps/zone_editor_overlay.dart';
import 'package:my_spots/widgets/navigation_overlay.dart';
import 'package:my_spots/widgets/satellite_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  final Waypoint? centerOn;

  /// When `true`, the screen automatically opens the
  /// "Tracer une zone hors-ligne" flow as soon as the map is ready and a
  /// position (GPS or default map center) is available. Used by
  /// [OfflineMapsScreen] to deep-link from the "Créer une zone" button.
  final bool triggerZoneCreation;

  /// Initial value for the temporary ONLINE / HORS-LIGNE switch owned by
  /// [HomePage]. Not persisted. The in-screen state can still be toggled
  /// at runtime; this is just the initial value pushed in.
  final ZoneDownloadService? zoneService;

  const MapScreen({
    super.key,
    this.centerOn,
    this.triggerZoneCreation = false,
    this.zoneService,
  });

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
  bool _isMeasuringDistance = false;
  LatLng? _measurementPoint1;
  Timer? _mapCameraUpdateDebounce;
  final TextEditingController _waypointNameController = TextEditingController();
  Waypoint? _selectedWaypoint;
  Waypoint? _navigationTarget; // Waypoint ciblé pour la navigation active
  String gpsStatus = 'INITIALISATION...';
  Color gpsStatusColor = Colors.orange;
  LatLngBounds? _mapVisibleBounds;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription<AlarmEvent>? _alarmSubscription;
  List<String> _readyZoneUuids = const [];
  final List<OfflineMapLayer> _readyLidarLayers = [];

  /// Cached combined bounds of all downloaded zones, computed from
  /// the OfflineMapRepository so that LiDAR layers can still be
  /// determined when _mapVisibleBounds is null (e.g., first render
  /// or when the user has not yet moved the map).
  LatLngBounds? _zoneCombinedBounds;

  /// When true, the map shows the interactive zone-editor overlay
  /// instead of the normal navigation view.
  bool _zoneEditMode = false;

  /// Configuration (name + layers) collected from NewZoneSheet before
  /// entering _zoneEditMode.
  ZoneConfig? _pendingZoneConfig;

  /// Démarre le mode de mesure de distance
  void _startDistanceMeasurement(LatLng initialPoint) {
    setState(() {
      _isMeasuringDistance = true;
      _measurementPoint1 = initialPoint;
    });
  }

  /// Termine la mesure et affiche le résultat
  void _finishDistanceMeasurement(
    LatLng point1,
    LatLng point2,
    double distanceMeters,
  ) {
    setState(() {
      _isMeasuringDistance = false;
      _measurementPoint1 = point1;
    });

    // Afficher le popup avec le résultat
    _showDistanceResultPopup(point1, point2, distanceMeters);
  }

  /// Affiche le popup avec le résultat de la mesure
  void _showDistanceResultPopup(
    LatLng point1,
    LatLng point2,
    double distanceMeters,
  ) {
    final distanceNauticalMiles = distanceMeters / 1852.0;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        title: const Row(
          children: [
            Icon(Icons.straighten, color: Color(0xFF0D6999)),
            SizedBox(width: 8),
            Text('Distance mesurée', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Point 1: ${point1.latitude.toStringAsFixed(5)}, ${point1.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Point 2: ${point2.latitude.toStringAsFixed(5)}, ${point2.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D6999).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Distance:',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        '${distanceMeters.toStringAsFixed(1)} m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Distance:',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        '${distanceNauticalMiles.toStringAsFixed(3)} nm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {
                _measurementPoint1 = null;
              });
            },
            child: const Text('Fermer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onMapCameraChanged() {
    // Évite les rebuilds trop fréquents
    if (_mapCameraUpdateDebounce?.isActive ?? false) return;

    _mapCameraUpdateDebounce = Timer(const Duration(milliseconds: 150), () {
      final bounds = _mapController.camera.visibleBounds;
      if (_mapVisibleBounds != null &&
          _mapVisibleBounds!.isOverlapping(bounds) &&
          _boundsNearlyEqual(_mapVisibleBounds!, bounds)) {
        return;
      }
      setState(() => _mapVisibleBounds = bounds);
    });
  }

  /// Indicateur de diagnostic TEMPORAIRE : affiche le niveau de zoom courant.
  Widget _buildZoomIndicator() {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'ZOOM : ${_currentZoom.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  bool _boundsNearlyEqual(LatLngBounds a, LatLngBounds b) {
    const epsilon = 0.002;
    return (a.north - b.north).abs() < epsilon &&
        (a.south - b.south).abs() < epsilon &&
        (a.east - b.east).abs() < epsilon &&
        (a.west - b.west).abs() < epsilon;
  }

  void _logMapTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    // Simple logging for tile errors - can be enhanced if needed.
    debugPrint('Tile error: $tile - $error');
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
    _loadOfflineZones();

    if (widget.centerOn != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _mapController.move(
          LatLng(widget.centerOn!.latitude, widget.centerOn!.longitude),
          16.0,
        );
      });
    }

    // Auto-start the zone-creation flow when the screen is opened from
    // OfflineMapsScreen 'Créer une zone' button. We schedule the trigger
    // Auto-start: after the first frame, open the name sheet immediately.
    if (widget.triggerZoneCreation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final center = _currentPosition ?? AppSettings.getDefaultMapCenter();
        _openNewOfflineZoneWithCenter(center);
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _alarmSubscription?.cancel();
    _waypointNameController.dispose();
    _mapCameraUpdateDebounce?.cancel();
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

  /// Loads ready/partial offline zone UUIDs from ObjectBox and computes the
  /// combined bounds of all downloaded zones so that LiDAR layers can be
  /// determined even before the map camera has fired its first event.
  void _loadOfflineZones() {
    final repo = OfflineMapRepository.instance;
    if (repo == null) return;
    final maps = repo.findReadyOrPartialMaps();
    final lidarLayers = <MapEntry<String, OfflineMapLayer>>[];
    for (final map in maps) {
      debugPrint(
        '[ZoneBounds] uuid=${map.uuid} '
        'northLat=${map.northLat} southLat=${map.southLat} '
        'westLng=${map.westLng} eastLng=${map.eastLng}',
      );
      final layers = repo.findLayersForMap(map);
      for (final layer in layers) {
        if (layer.layerType == LayerType.lidarLitto3d) {
          lidarLayers.add(MapEntry(map.uuid, layer));
        }
      }
    }
    setState(() {
      _readyZoneUuids = maps.map((m) => m.uuid).toList();
      _readyLidarLayers.clear();
      _readyLidarLayers.addAll(lidarLayers.map((e) => e.value).toList());
      if (maps.isEmpty) {
        _zoneCombinedBounds = null;
      } else {
        _zoneCombinedBounds = LatLngBounds(
          LatLng(
            maps.map((m) => m.southLat).reduce((a, b) => a < b ? a : b),
            maps.map((m) => m.westLng).reduce((a, b) => a < b ? a : b),
          ),
          LatLng(
            maps.map((m) => m.northLat).reduce((a, b) => a > b ? a : b),
            maps.map((m) => m.eastLng).reduce((a, b) => a > b ? a : b),
          ),
        );
      }
    });
  }

  /// Shows the context menu (BottomSheet) at the long-pressed map point.
  void _showMapContextMenu(LatLng point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.add_location_alt,
                color: Color(0xFF0D6999),
              ),
              title: const Text(
                "Ajouter un waypoint ici",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                "Lat ${point.latitude.toStringAsFixed(5)}  Lon ${point.longitude.toStringAsFixed(5)}",
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _addWaypointAt(point);
              },
            ),
            ListTile(
              leading: const Icon(Icons.crop_free, color: Color(0xFF0D6999)),
              title: const Text(
                "Tracer une zone hors-ligne",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text(
                "Definir une zone de telechargement",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _openNewOfflineZone(point);
              },
            ),
            ListTile(
              leading: const Icon(Icons.straighten, color: Color(0xFF0D6999)),
              title: const Text(
                "Mesurer une distance",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text(
                "Placer deux points pour mesurer",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _startDistanceMeasurement(point);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Opens the waypoint editor pre-filled with the given map position.
  Future<void> _addWaypointAt(LatLng position) async {
    final int waypointNumber = WaypointStore.waypoints.length + 1;
    final defaultName = "WPT $waypointNumber";

    final outcome = await showWaypointEditorSheet(
      context: context,
      title: "Nouveau waypoint",
      icon: Icons.add_location_alt,
      position: position,
      initialName: defaultName,
      initialCategory: WaypointCategory.fishing,
      initialColorHex: "FFFFEB3B",
      initialDate: DateTime.now(),
      isEditing: false,
    );

    if (outcome == null) return;
    if (outcome.deleted) return;
    if (outcome.waypoint != null) {
      WaypointStore.waypoints.add(outcome.waypoint!);
      await WaypointStore.save();
      setState(() {});
    }
  }

  /// Opens the zone-name sheet, then enters zone-adjustment mode
  /// centred on [centerPoint]. Used both for long-press and for the
  /// [OfflineMapsScreen] entry point.
  void _openNewOfflineZone(LatLng centerPoint) async {
    final config = await showNewZoneSheet(context);
    if (config == null) return;
    if (!mounted) return;

    setState(() {
      _zoneEditMode = true;
      _pendingZoneConfig = config;
    });
    _mapController.move(centerPoint, _currentZoom);
  }

  /// Variant used by the post-frame callback: opens the sheet immediately
  /// with [center] as the initial map position after confirmation.
  void _openNewOfflineZoneWithCenter(LatLng center) {
    _openNewOfflineZone(center);
  }

  /// Saves the zone after the user has adjusted the rectangle.
  Future<void> _onZoneBoundsConfirmed(LatLngBounds bounds) async {
    final config = _pendingZoneConfig;
    if (config == null) {
      _exitZoneEditMode();
      return;
    }

    final repo = OfflineMapRepository.instance;
    if (repo == null) {
      _exitZoneEditMode();
      return;
    }

    // 2) Create and persist the OfflineMap.
    final uuid = DateTime.now().millisecondsSinceEpoch.toString();
    final map = OfflineMap.create(
      uuid: uuid,
      name: config.name,
      northLat: bounds.north,
      southLat: bounds.south,
      westLng: bounds.west,
      eastLng: bounds.east,
    );
    repo.save(map);

    // 3) Create layers and trigger download.
    final layers = ZoneConfig.defaultLayersForBounds(
      bounds,
    ); // ← Retourne déjà des OfflineMapLayer
    for (final layer in layers) {
      repo.saveLayer(map, layer);
    }

    // Use the passed ZoneDownloadService instance if available, otherwise create a new one
    final zoneService = widget.zoneService ?? ZoneDownloadService.instance;
    zoneService.downloadZone(map: map, layers: layers, zoneBounds: bounds);

    // 4) Exit edit mode and refresh.
    _exitZoneEditMode();
    _loadOfflineZones();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Zone \"${config.name}\" creee - telechargement en cours",
        ),
        backgroundColor: const Color(0xFF0D6999),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _exitZoneEditMode() {
    setState(() {
      _zoneEditMode = false;
      _pendingZoneConfig = null;
    });
  }

  /// Zoom ranges aligned with `MarineMapService.getActiveMarineTileLayers`:
  ///   - 50K  : displayed at z >= 11
  ///   - 25K  : displayed at z >= 12 (before tile zoom rounds to 13 at ~12.5)
  ///   - 10K  : displayed at z >= 14 (before tile zoom rounds to 15 at ~14.5)
  /// Download `maxZoom` is clamped to 17 by `FmtcLayerDownloader`; this is
  /// compatible with the 10K layer which only needs z=15..17 to cover the
  /// full on-screen use case (the display layer extends to z=22 via
  /// `maxNativeZoom=19` + display `maxZoom: 22.0`).
  ///
  /// For LiDAR ombrage / Litto3D, [LidarRegionCatalog] returns layers
  /// covering the visible bounds, so a download range of 10..16 covers
  /// the typical coastal usage (Litto3D is natively available from z6).
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
                // Fond sombre : visible uniquement dans les trous transparents résiduels
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF0A1929)),
                ),
                MapView(
                  mapController: _mapController,
                  mapType: AppSettings.mapType,
                  zoom: _currentZoom,
                  offlineMode: AppSettings.offlineModeEnabled,
                  readyZoneUuids: _readyZoneUuids,
                  readyLidarLayers: _readyLidarLayers,
                  currentPosition: _currentPosition,
                  selectedWaypointPosition: _selectedWaypoint == null
                      ? null
                      : LatLng(
                          _selectedWaypoint!.latitude,
                          _selectedWaypoint!.longitude,
                        ),
                  visibleBounds: _mapVisibleBounds,
                  zoneCombinedBounds: _zoneCombinedBounds,
                  waypointsVisible: AppSettings.waypointsVisible,
                  waypoints: WaypointStore.waypoints,
                  bathymetryEnabled: AppSettings.bathymetryOverlayEnabled,
                  bathymetryOpacity: AppSettings.bathymetryOverlayOpacity,
                  onLongPress: (latLng) {
                    if (_zoneEditMode) return;
                    _showMapContextMenu(latLng);
                  },
                  onTap: (wp) => setState(() => _selectedWaypoint = wp),
                  onZoomChanged: (z) => setState(() => _currentZoom = z),
                  onMapCameraChanged: _onMapCameraChanged,
                  onPointerDown: () {
                    if (_isFollowingUser) {
                      setState(() => _isFollowingUser = false);
                    }
                  },
                  onErrorTile: _logMapTileError,
                ),
                // Zone-adjustment overlay (active when long-pressing
                // "Tracer une zone hors-ligne").
                if (_zoneEditMode)
                  Positioned.fill(
                    child: ZoneEditorOverlay(
                      centerPoint: _mapController.camera.center,
                      onConfirm: _onZoneBoundsConfirmed,
                      onCancel: _exitZoneEditMode,
                      // Share the same MapController with the underlying
                      // FlutterMap so that bounds-to-LatLng conversions
                      // match the user's actual viewport.
                      mapController: _mapController,
                    ),
                  ),

                if (_isMeasuringDistance && _measurementPoint1 != null)
                  Positioned.fill(
                    child: DistanceMeasurementOverlay(
                      initialPoint: _measurementPoint1!,
                      onMeasureComplete: _finishDistanceMeasurement,
                      onCancel: () {
                        setState(() {
                          _isMeasuringDistance = false;
                          _measurementPoint1 = null;
                        });
                      },
                      mapController: _mapController,
                    ),
                  ),
                // ── UI masquée pendant le tracé de zone (_zoneEditMode == true) ──
                // L'utilisateur ne voit QUE : la carte, le rectangle de sélection,
                // la barre d'annulation (top) et le bouton "Valider" (bottom).
                // Overlay de mesure de distance (actif quand on mesure une distance)
                if (!_zoneEditMode) ...[
                  // Sélecteur LiDAR / Bathymétrie (haut-gauche).
                  Positioned(
                    left: 6,
                    top: 10,
                    child: _buildBathymetryOverlayControls(),
                  ),
                  // Boutons : recentrage GPS, toggle waypoints, + waypoint,
                  // accès zones hors-ligne (haut-droite).
                  Positioned(
                    right: 6,
                    top: 10,
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
                  if (_selectedWaypoint != null && !_isMeasuringDistance)
                    Positioned(
                      left: 25,
                      right: 25,
                      bottom: 98,
                      child: SelectedWaypointPanel(
                        waypoint: _selectedWaypoint!,
                        currentPosition: _currentPosition,
                        onCenterOnTarget: _centerOnTargetAndUser,
                        onEditWaypoint: (outcome) async {
                          if (outcome != null) {
                            if (outcome.deleted) {
                              setState(() {
                                WaypointStore.waypoints.remove(
                                  _selectedWaypoint,
                                );
                                _selectedWaypoint = null;
                                _navigationTarget = null;
                              });
                              await WaypointStore.save();
                            } else if (outcome.waypoint != null) {
                              setState(() {
                                final index = WaypointStore.waypoints
                                    .indexWhere(
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
                ],
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child:
                      AppSettings.showSpeedOnMap &&
                          !_zoneEditMode &&
                          !_isMeasuringDistance
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
                // Bandeau de navigation active (masqué en mode tracé de zone)
                if (_navigationTarget != null && !_zoneEditMode)
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
                // Indicateur de diagnostic TEMPORAIRE - zoom courant (bas-droit)
                Positioned(right: 16, bottom: 16, child: _buildZoomIndicator()),
              ],
            ),
    );
  }
}
