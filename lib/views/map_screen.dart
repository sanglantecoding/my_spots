import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/controllers/gps_controller.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';
import 'package:my_spots/services/alarm_service.dart';
import 'package:my_spots/services/zone_download/zone_download.dart';
import 'package:my_spots/settings_page.dart';
import 'package:my_spots/views/dialogs/distance_result_dialog.dart';
import 'package:my_spots/views/dialogs/offline_mode_blocking_dialog.dart';
import 'package:my_spots/views/dialogs/waypoint_editor_sheet.dart';
import 'package:my_spots/views/helpers/offline_zones_loader.dart';
import 'package:my_spots/views/offline_maps_screen.dart';
import 'package:my_spots/views/widgets/map/bathymetry_controls_widget.dart';
import 'package:my_spots/views/widgets/map/distance_measurement_overlay.dart';
import 'package:my_spots/views/widgets/map/map_context_menu.dart';
import 'package:my_spots/views/widgets/map/map_controls_widget.dart';
import 'package:my_spots/views/widgets/map/map_view.dart';
import 'package:my_spots/views/widgets/map/mushroom_forecast_sheet.dart';
import 'package:my_spots/views/widgets/map/selected_waypoint_panel.dart';
import 'package:my_spots/views/widgets/offline_maps/new_zone_sheet.dart';
import 'package:my_spots/views/widgets/offline_maps/zone_editor_overlay.dart';
import 'package:my_spots/widgets/navigation_overlay.dart';
import 'package:my_spots/widgets/gps_accuracy_dialog.dart';

/// Ouvre la prévision uniquement avec une carte terrestre.
Future<void> showMushroomForecastIfAllowed(
  BuildContext context,
  LatLng point,
) async {
  if (AppSettings.mapType == MapType.marine) return;
  await showMushroomForecastSheet(context, point);
}

class MapScreen extends StatefulWidget {
  final Waypoint? centerOn;

  /// When `true`, the screen automatically opens the
  /// "Tracer une zone hors-ligne" flow as soon as the map is ready and a
  /// position (GPS or default map center) is available. Used by
  /// [OfflineMapsScreen] to deep-link from the "Créer une zone" button.
  final bool triggerZoneCreation;

  /// Instance partagée du service de téléchargement (venue de
  /// [OfflineMapsScreen]) ou `null` → singleton.
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
  double _currentZoom = 15.0;
  int? _lastMarineLayerThreshold; // 🛡️ Track le dernier seuil de couche
  bool _isLoading = true;
  bool _isFollowingUser = false;
  bool _isMeasuringDistance = false;
  LatLng? _measurementPoint1;
  Timer? _mapCameraUpdateDebounce;
  final TextEditingController _waypointNameController = TextEditingController();
  Waypoint? _selectedWaypoint;
  Waypoint? _navigationTarget; // Waypoint ciblé pour la navigation active
  LatLngBounds? _mapVisibleBounds;
  StreamSubscription? _positionSubscription;
  StreamSubscription<AlarmEvent>? _alarmSubscription;
  List<String> _readyZoneUuids = const [];
  final Map<String, List<OfflineMapLayer>> _readyLidarLayersByZone =
      <String, List<OfflineMapLayer>>{};

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

  /// Key for accessing the zone editor overlay state.
  final GlobalKey _zoneEditorKey = GlobalKey<ZoneEditorOverlayState>();

  /// 🛡️ P1 PERF : dernière position connue, lue À LA DEMANDE via le
  /// singleton. Plus aucun champ _currentPosition maintenu par setState :
  /// un tick GPS ne doit JAMAIS reconstruire MapScreen (donc MapView /
  /// TileLayers). Les UI haute fréquence (vitesse, panneau, icône) sont
  /// des widgets feuilles auto-abonnés en bas de fichier.
  LatLng? _gpsLatLng() {
    final p = GpsController.instance.currentPosition;
    return p == null ? null : LatLng(p.latitude, p.longitude);
  }

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
    showDistanceResultDialog(context, point1, point2, distanceMeters, () {
      setState(() {
        _measurementPoint1 = null;
      });
    });
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

  /// Détermine le seuil de couche marine actuel.
  /// Retourne un entier représentant le seuil franchi.
  int _getMarineLayerThreshold(double zoom) {
    if (zoom >= 14.0) return 14;
    if (zoom >= 12.0) return 12;
    if (zoom >= 11.0) return 11;
    if (zoom >= 9.0) return 9;
    if (zoom >= 7.0) return 7;
    return 0;
  }

  bool _boundsNearlyEqual(LatLngBounds a, LatLngBounds b) {
    const epsilon = 0.002;
    return (a.north - b.north).abs() < epsilon &&
        (a.south - b.south).abs() < epsilon &&
        (a.east - b.east).abs() < epsilon &&
        (a.west - b.west).abs() < epsilon;
  }

  @override
  void initState() {
    super.initState();
    // Initialiser le service d'alarme
    unawaited(AlarmService.initialize());
    // S'abonner au flux broadcast d'événements d'alarme
    _alarmSubscription = AlarmService.onAlarmEvent.listen((event) {
      if (!mounted) return;
      // On rebuild sur tout changement d'état vu par MapScreen
      // (icône haut-parleur, etc.) — événement RARE, pas un tick GPS.
      setState(() {});
    });
    _startLocationTracking();
    _loadOfflineZones();
    if (widget.centerOn != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _mapController.move(
          LatLng(widget.centerOn!.latitude, widget.centerOn!.longitude),
          16.0,
        );
      });
    }
    // Auto-start the zone-creation flow when the screen is opened from
    // OfflineMapsScreen 'Créer une zone' button.
    if (widget.triggerZoneCreation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final center = _gpsLatLng() ?? AppSettings.getDefaultMapCenter();
        unawaited(_openNewOfflineZoneWithCenter(center));
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _alarmSubscription?.cancel();
    _waypointNameController.dispose();
    _mapCameraUpdateDebounce?.cancel();
    super.dispose();
  }

  /// Suivi GPS : EFFETS DE BORD UNIQUEMENT.
  ///
  /// 🛡️ P1 PERF : aucun setState par tick ici. Le marqueur, la polyline,
  /// la vitesse, le statut et les distances vivent dans des widgets
  /// feuilles auto-abonnés (_GpsStateIcon, _SpeedOverlay, _LivePosition,
  /// StreamBuilder interne de MapView, NavigationOverlay). MapScreen — et
  /// donc MapView / _buildTileLayers() — ne se reconstruit PLUS à 1 Hz.
  Future<void> _startLocationTracking() async {
    _positionSubscription = GpsController.instance.positionStream.listen(
      (position) {
        if (!mounted) return;
        final pos = LatLng(position.latitude, position.longitude);
        // Alarmes de proximité : besoin de la position, pas d'un rebuild.
        AlarmService.updatePosition(pos);
        // Recentrage automatique si le suivi est actif (impératif, pas UI).
        if (_isFollowingUser) _mapController.move(pos, 15.0);
        // One-shot : on quitte l'écran de chargement au premier fix.
        if (_isLoading) setState(() => _isLoading = false);
      },
      onError: (error) {
        if (mounted && _isLoading) setState(() => _isLoading = false);
      },
    );
    // Démarrer GpsController si pas déjà démarré
    final ok = await GpsController.instance.start();
    if (!ok && mounted && _isLoading) {
      setState(() => _isLoading = false);
    }
  }

  void _recenterMap() {
    final pos = _gpsLatLng();
    if (pos != null) {
      setState(() {
        _isFollowingUser = true;
      });
      _mapController.move(pos, 15.0);
    }
  }

  /// Loads ready/partial offline zone UUIDs from ObjectBox and computes the
  /// combined bounds of all downloaded zones so that LiDAR layers can be
  /// determined even before the map camera has fired its first event.
  void _loadOfflineZones() {
    if (!mounted) return;
    final data = OfflineZonesLoader.loadOfflineZones();
    setState(() {
      _readyZoneUuids = data.readyZoneUuids;
      _readyLidarLayersByZone
        ..clear()
        ..addAll(data.readyLidarLayersByZone);
      _zoneCombinedBounds = data.zoneCombinedBounds;
    });
  }

  /// Shows the context menu (BottomSheet) at the long-pressed map point.
  void _showMapContextMenu(LatLng point) {
    showMapContextMenu(
      context,
      point,
      MapContextMenuCallbacks(
        onAddWaypoint: _addWaypointAt,
        onOpenOfflineZone: _openNewOfflineZone,
        onShowOfflineModeBlockingDialog: _showOfflineModeBlockingDialog,
        onStartDistanceMeasurement: _startDistanceMeasurement,
        onShowMushroomForecast: (point) =>
            showMushroomForecastIfAllowed(context, point),
      ),
    );
  }

  /// Boîte de dialogue affichée quand l'utilisateur tente de tracer une
  /// zone hors-ligne alors que le mode hors-ligne est actif.
  Future<void> _showOfflineModeBlockingDialog(LatLng point) async {
    final switchOnline = await showOfflineModeBlockingDialog(context, point);

    if (switchOnline != true) return;
    await AppSettings.saveOfflineMode(false);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mode en ligne activé. Ouverture du tracé de zone...'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    await _openNewOfflineZone(point);
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
      if (!mounted) return;
      setState(() {});
    }
  }

  /// Opens the zone-name sheet, then enters zone-adjustment mode
  /// centred on [centerPoint].
  Future<void> _openNewOfflineZone(LatLng centerPoint) async {
    final config = await showNewZoneSheet(context);
    if (config == null) return;
    if (!mounted) return;
    setState(() {
      _zoneEditMode = true;
      _pendingZoneConfig = config;
    });
    _mapController.move(centerPoint, _currentZoom);
  }

  /// Variant used by the post-frame callback.
  Future<void> _openNewOfflineZoneWithCenter(LatLng center) =>
      _openNewOfflineZone(center);

  /// Handles long press events on the map when in polygon mode.
  void _onMapLongPress(LatLng latLng) {
    if (!_zoneEditMode || _pendingZoneConfig?.zoneType != 'Main levée') return;
    // Pass the point to the overlay to show confirmation dialog
    (_zoneEditorKey.currentState as ZoneEditorOverlayState?)?.proposePoint(
      latLng,
    );
  }

  /// Saves the zone after the user has adjusted the rectangle or polygon.
  Future<void> _onZoneBoundsConfirmed(dynamic bounds) async {
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

    // Handle polygon mode - keep polygon vertices and calculate bounding box
    List<LatLng>? polygonVertices;
    LatLngBounds finalBounds;
    if (bounds is List<LatLng>) {
      polygonVertices = bounds;

      // Calculate bounding box from polygon vertices for SHOM analysis
      final lats = bounds.map((p) => p.latitude);
      final lngs = bounds.map((p) => p.longitude);
      finalBounds = LatLngBounds(
        LatLng(
          lats.reduce((a, b) => a < b ? a : b),
          lngs.reduce((a, b) => a < b ? a : b),
        ),
        LatLng(
          lats.reduce((a, b) => a > b ? a : b),
          lngs.reduce((a, b) => a > b ? a : b),
        ),
      );
    } else {
      finalBounds = bounds as LatLngBounds;
    }

    // 1) PRÉFLIGHT SHOM (analyse de couverture) AVANT toute écriture en base.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analyse couverture SHOM...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final layers = await ZoneConfig.resolveLayersForBounds(finalBounds);

    if (layers.isEmpty) {
      _exitZoneEditMode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune couverture SHOM/LiDAR sur cette zone'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return; // Arrêt propre : rien n'a été écrit en base.
    }

    // 2) CRÉATION & PERSISTANCE (Zone + Couches) d'un bloc.
    final uuid = DateTime.now().millisecondsSinceEpoch.toString();

    // Encode polygon vertices to JSON if polygon mode
    String? polygonJson;
    if (polygonVertices != null) {
      final verticesJson = polygonVertices
          .map((latLng) => {'lat': latLng.latitude, 'lng': latLng.longitude})
          .toList();
      polygonJson = jsonEncode(verticesJson);
    }

    final map = OfflineMap.create(
      uuid: uuid,
      name: config.name,
      northLat: finalBounds.north,
      southLat: finalBounds.south,
      westLng: finalBounds.west,
      eastLng: finalBounds.east,
      polygonJson: polygonJson,
    );

    repo.save(map);
    for (final layer in layers) {
      repo.saveLayer(map, layer);
    }

    // 3) DOWNLOAD
    final zoneService = widget.zoneService ?? ZoneDownloadService.instance;
    zoneService.downloadZone(map: map, layers: layers, zoneBounds: finalBounds);
    if (!mounted) return;

    // 4) UI & CLEANUP
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

  Future<void> _showAddWaypointDialog() async {
    final frozenPosition = _gpsLatLng();
    if (frozenPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position GPS non disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
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
    if (!mounted) return;
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

  Future<void> _centerOnTargetAndUser() async {
    final pos = _gpsLatLng();
    final wp = _selectedWaypoint;
    if (pos == null || wp == null) return;
    final bounds = LatLngBounds.fromPoints([
      pos,
      LatLng(wp.latitude, wp.longitude),
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
                    builder: (context) => const GpsAccuracyDialog(),
                  );
                },
                // 🛡️ Widget feuille : se rebuild seul sur stateStream.
                child: const _GpsStateIcon(),
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
              if (!mounted) return;
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
                  readyLidarLayersByZone: _readyLidarLayersByZone,
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
                    if (_zoneEditMode) {
                      _onMapLongPress(latLng);
                      return;
                    }
                    _showMapContextMenu(latLng);
                  },
                  onTap: (wp) => setState(() => _selectedWaypoint = wp),
                  onZoomChanged: (z) {
                    // Toujours mettre à jour le zoom pour l'indicateur
                    _currentZoom = z;

                    // 🛡️ P1 PERF : Ne rebuild MapView que si on franchit un seuil de couche
                    if (AppSettings.mapType == MapType.marine) {
                      final newThreshold = _getMarineLayerThreshold(z);
                      if (newThreshold != _lastMarineLayerThreshold) {
                        _lastMarineLayerThreshold = newThreshold;
                        setState(() {}); // Rebuild pour changer les couches
                      }
                    }
                  },
                  onMapCameraChanged: _onMapCameraChanged,
                  onPointerDown: () {
                    if (_isFollowingUser) {
                      setState(() => _isFollowingUser = false);
                    }
                  },
                ),
                // Zone-adjustment overlay (active quand tracé de zone).
                if (_zoneEditMode)
                  Positioned.fill(
                    child: ZoneEditorOverlay(
                      key: _zoneEditorKey,
                      drawMode: _pendingZoneConfig?.zoneType == 'Main levée'
                          ? ZoneDrawMode.polygon
                          : ZoneDrawMode.rectangle,
                      onConfirm: _onZoneBoundsConfirmed,
                      onCancel: _exitZoneEditMode,
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
                // ── UI masquée pendant le tracé de zone ──
                if (!_zoneEditMode) ...[
                  if (AppSettings.mapType == MapType.marine)
                    Positioned(
                      left: 6,
                      top: 10,
                      child: BathymetryControlsWidget(
                        onChanged: () {
                          if (mounted) {
                            setState(
                              () {},
                            ); // rebuild MapView avec les nouvelles props
                          }
                        },
                      ),
                    ),
                  // Boutons : recentrage GPS, toggle waypoints, + waypoint.
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
                  // 🛡️ Panneau waypoint : seule sa sous-arborescence se
                  // rebuild à 1 Hz via _LivePosition, pas MapScreen/MapView.
                  if (_selectedWaypoint != null && !_isMeasuringDistance)
                    Positioned(
                      left: 25,
                      right: 25,
                      bottom: 98,
                      child: _LivePosition(
                        builder: (context, pos) => SelectedWaypointPanel(
                          waypoint: _selectedWaypoint!,
                          currentPosition: pos,
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
                                    final wasNavigationTarget =
                                        _navigationTarget == _selectedWaypoint;
                                    _selectedWaypoint = outcome.waypoint;
                                    if (wasNavigationTarget) {
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
                          onShowMushroomForecast: () =>
                              showMushroomForecastIfAllowed(
                                context,
                                LatLng(
                                  _selectedWaypoint!.latitude,
                                  _selectedWaypoint!.longitude,
                                ),
                              ),
                          onClose: () {
                            AlarmService.stopMonitoring();
                            setState(() {
                              _selectedWaypoint = null;
                              _navigationTarget = null;
                            });
                          },
                        ),
                      ),
                    ),
                ],
                // 🛡️ Bandeau vitesse : widget feuille auto-abonné (1 Hz local).
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _SpeedOverlay(
                    visible:
                        AppSettings.showSpeedOnMap &&
                        !_zoneEditMode &&
                        !_isMeasuringDistance,
                  ),
                ),
                // Bandeau de navigation active (s'auto-alimente en position).
                if (_navigationTarget != null && !_zoneEditMode)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: NavigationOverlay(
                      targetWaypoint: _navigationTarget!,
                      currentPosition: _gpsLatLng(),
                      onStopNavigation: () {
                        setState(() {
                          _navigationTarget = null;
                        });
                        AlarmService.stopMonitoring();
                      },
                    ),
                  ),
                // 🛡️ Indicateur de zoom : widget feuille auto-abonné
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _ZoomIndicator(mapController: _mapController),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets feuilles GPS haute fréquence : chacun s'abonne lui-même et ne
// rebuild QUE sa propre sous-arborescence. MapScreen / MapView / TileLayers
// ne sont plus jamais reconstruits par un tick GPS.
// ─────────────────────────────────────────────────────────────────────────────

/// Indicateur de zoom : se met à jour indépendamment sans rebuild MapScreen.
class _ZoomIndicator extends StatefulWidget {
  const _ZoomIndicator({required this.mapController});

  final MapController mapController;

  @override
  State<_ZoomIndicator> createState() => _ZoomIndicatorState();
}

class _ZoomIndicatorState extends State<_ZoomIndicator> {
  double _zoom = 15.0;
  StreamSubscription<MapEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _zoom = widget.mapController.camera.zoom;
    // Écouter les changements de caméra pour mettre à jour le zoom
    _sub = widget.mapController.mapEventStream.listen((event) {
      if (mounted) {
        setState(() {
          _zoom = widget.mapController.camera.zoom;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'ZOOM : ${_zoom.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Icône d'état GPS de l'AppBar : rebuild uniquement sur stateStream.
class _GpsStateIcon extends StatefulWidget {
  const _GpsStateIcon();

  @override
  State<_GpsStateIcon> createState() => _GpsStateIconState();
}

class _GpsStateIconState extends State<_GpsStateIcon> {
  StreamSubscription<GpsState>? _sub;
  GpsState _state = GpsController.instance.state;

  @override
  void initState() {
    super.initState();
    _sub = GpsController.instance.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    switch (_state) {
      case GpsState.stationary:
      case GpsState.moving:
        icon = Icons.gps_fixed;
        color = Colors.green;
        break;
      case GpsState.initializing:
        icon = Icons.gps_not_fixed;
        color = Colors.orange;
        break;
      case GpsState.error:
        icon = Icons.gps_off;
        color = Colors.red;
        break;
      case GpsState.stopped:
        icon = Icons.gps_not_fixed;
        color = Colors.grey;
        break;
    }
    return Icon(icon, color: color, size: 18);
  }
}

/// Bandeau de vitesse : seul widget reconstruit à chaque tick GPS.
/// (Au passage : corrige le double libellé d'unité « 12.3 kn nds ».)
class _SpeedOverlay extends StatefulWidget {
  const _SpeedOverlay({required this.visible});

  final bool visible;

  @override
  State<_SpeedOverlay> createState() => _SpeedOverlayState();
}

class _SpeedOverlayState extends State<_SpeedOverlay> {
  StreamSubscription<Position>? _sub;
  double _speed = GpsController.instance.currentSpeed;

  @override
  void initState() {
    super.initState();
    _sub = GpsController.instance.positionStream.listen((p) {
      if (mounted) setState(() => _speed = p.speed);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final knots = AppSettings.speedUnit == SpeedUnit.knots;
    final value = knots ? _speed * 1.94384 : _speed * 3.6;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          const Icon(Icons.speed, color: Colors.blueAccent, size: 28),
          const SizedBox(width: 12),
          Text(
            '${value.toStringAsFixed(1)} ${knots ? 'nds' : 'km/h'}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fournit la position vivante à un sous-arbre léger (panneau waypoint),
/// sans faire remonter le rebuild jusqu'à MapScreen / MapView.
class _LivePosition extends StatelessWidget {
  const _LivePosition({required this.builder});

  final Widget Function(BuildContext context, LatLng? position) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Position>(
      stream: GpsController.instance.positionStream,
      initialData: GpsController.instance.currentPosition,
      builder: (context, snapshot) {
        final p = snapshot.data;
        return builder(
          context,
          p == null ? null : LatLng(p.latitude, p.longitude),
        );
      },
    );
  }
}
