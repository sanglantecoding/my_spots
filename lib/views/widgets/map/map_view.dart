import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/marine_map_service.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/views/widgets/map/gps_marker_widget.dart';

/// Widget isolé contenant FlutterMap et ses couches.
///
/// Ce widget ne se rebuild QUE quand [mapType], [zoom], [offlineMode],
/// [readyZoneUuids], [visibleBounds] ou [bathymetryEnabled] changent.
/// Les changements de position GPS / vitesse / statut GPS sont gérés par
/// le parent et ne reconstruisent PAS la carte.
class MapView extends StatefulWidget {
  final MapController mapController;
  final MapType mapType;
  final double zoom;
  final bool offlineMode;
  final List<String> readyZoneUuids;
  final List<OfflineMapLayer> readyLidarLayers;
  final LatLng? currentPosition;
  final LatLng? selectedWaypointPosition;
  final LatLngBounds? visibleBounds;
  final LatLngBounds? zoneCombinedBounds;
  final bool waypointsVisible;
  final List<Waypoint> waypoints;
  final bool bathymetryEnabled;
  final double bathymetryOpacity;
  final void Function(LatLng) onLongPress;
  final void Function(Waypoint) onTap;
  final void Function(double) onZoomChanged;
  final void Function() onMapCameraChanged;
  final void Function() onPointerDown;
  final void Function(TileImage, Object, StackTrace?) onErrorTile;

  const MapView({
    super.key,
    required this.mapController,
    required this.mapType,
    required this.zoom,
    required this.offlineMode,
    required this.readyZoneUuids,
    required this.readyLidarLayers,
    required this.currentPosition,
    required this.selectedWaypointPosition,
    required this.visibleBounds,
    required this.zoneCombinedBounds,
    required this.waypointsVisible,
    required this.waypoints,
    required this.bathymetryEnabled,
    required this.bathymetryOpacity,
    required this.onLongPress,
    required this.onTap,
    required this.onZoomChanged,
    required this.onMapCameraChanged,
    required this.onPointerDown,
    required this.onErrorTile,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  bool _tilesReady = false;

  @override
  void initState() {
    super.initState();
    // Différer le chargement des tuiles jusqu'à ce que la carte soit visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _tilesReady = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter:
            widget.currentPosition ?? AppSettings.getDefaultMapCenter(),
        initialZoom: widget.zoom,
        minZoom: widget.offlineMode ? 8.0 : AppSettings.getMapMinZoom(),
        maxZoom: AppSettings.getMapMaxZoom(),
        onPositionChanged: (position, hasGesture) {
          if ((position.zoom - widget.zoom).abs() > 0.001) {
            widget.onZoomChanged(position.zoom);
          }
        },
        onMapEvent: (event) {
          if (event is MapEventMove ||
              event is MapEventRotate ||
              event is MapEventNonRotatedSizeChange) {
            widget.onMapCameraChanged();
          }
        },
        onPointerDown: (event, point) {
          widget.onPointerDown();
        },
        onLongPress: (tapPosition, latLng) {
          widget.onLongPress(latLng);
        },
      ),
      children: [
        // ⚠️  Les couches doivent être des enfants DIRECTS de FlutterMap
        // (pas de Column wrapper) :
        if (_tilesReady) ..._buildTileLayers(),
        if (widget.currentPosition != null &&
            widget.selectedWaypointPosition != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  widget.currentPosition!,
                  widget.selectedWaypointPosition!,
                ],
                color: Colors.white70.withValues(alpha: 0.8),
                strokeWidth: 2,
                pattern: const StrokePattern.dotted(spacingFactor: 1.8),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            // Position GPS actuelle (en premier, donc en arrière-plan)
            if (widget.currentPosition != null)
              Marker(
                point: widget.currentPosition!,
                width: 80,
                height: 80,
                alignment: Alignment.center,
                child: const GpsMarkerWidget(),
              ),
            // Waypoints de l'utilisateur (en dernier, donc au premier plan)
            if (widget.waypointsVisible)
              ...widget.waypoints
                  .where(_shouldShowWaypoint)
                  .map(_buildWaypointMarker),
          ],
        ),
      ],
    );
  }

  // ─── Couches de tuiles ────────────────────────────────────────────────
  List<Widget> _buildTileLayers() {
    if (widget.mapType == MapType.marine) {
      return widget.offlineMode
          ? _offlineMarineLayers()
          : _onlineMarineLayers();
    }
    return [_standardTileLayer()];
  }

  List<Widget> _offlineMarineLayers() {
    return [
      ...MarineMapService.getOfflineMarineTileLayers(
        widget.zoom,
        widget.readyZoneUuids,
      ),
      if (widget.bathymetryEnabled)
        ...MarineMapService.getOfflineLidarLayers(
          widget.visibleBounds ?? widget.zoneCombinedBounds,
          widget.readyLidarLayers,
          widget.readyZoneUuids,
          opacity: widget.bathymetryOpacity,
        ),
    ];
  }

  List<Widget> _onlineMarineLayers() => [
    ...MarineMapService.getActiveMarineTileLayers(
      widget.zoom,
      zoneUuids: widget.readyZoneUuids,
    ),
    if (widget.bathymetryEnabled)
      ...MarineMapService.getActiveLidarLayers(
        widget.visibleBounds,
        zoneUuids: widget.readyZoneUuids,
        opacity: widget.bathymetryOpacity,
      ),
  ];

  Widget _standardTileLayer() => TileLayer(
    key: ValueKey('basemap_${widget.mapType}'),
    urlTemplate: AppSettings.getMapTileUrl(),
    userAgentPackageName: MapTileCacheService.packageName,
    minZoom: AppSettings.getMapMinZoom(),
    minNativeZoom: AppSettings.getMapMinNativeZoom(),
    maxNativeZoom: AppSettings.getMapMaxNativeZoom(),
    maxZoom: AppSettings.getMapMaxZoom(),
    tileProvider: MapTileCacheService.getTileProviderForMapType(widget.mapType),
    errorTileCallback: widget.onErrorTile,
  );

  // ─── Waypoints ────────────────────────────────────────────────────────
  bool _shouldShowWaypoint(Waypoint waypoint) {
    if (waypoint.category == WaypointCategory.fishing &&
        !AppSettings.showFishingWaypointsOnMap) {
      return false;
    }
    if (waypoint.category == WaypointCategory.mushrooms &&
        !AppSettings.showMushroomWaypointsOnMap) {
      return false;
    }
    if (waypoint.category == WaypointCategory.other &&
        !AppSettings.showOtherWaypointsOnMap) {
      return false;
    }
    return true;
  }

  /// Icône de catégorie du waypoint (affichée DANS le rond).
  IconData _getWaypointCategoryIcon(Waypoint waypoint) {
    switch (waypoint.category) {
      case WaypointCategory.mushrooms:
        return Icons.park;
      case WaypointCategory.fishing:
        return Icons.anchor;
      case WaypointCategory.other:
        return waypoint.name.toLowerCase().contains('voiture')
            ? Icons.directions_car
            : Icons.location_on;
    }
  }

  /// Marqueur de waypoint : rond coloré centré PILE sur le point GPS,
  /// avec l'icône de catégorie à l'intérieur et un libellé flottant
  /// au-dessus (qui ne décale pas le point).
  Marker _buildWaypointMarker(Waypoint waypoint) {
    final showName = AppSettings.showWaypointNamesOnMap;
    final showDate = AppSettings.showWaypointDateOnMap;
    final hasLabel = showName || showDate;
    final fontSize = AppSettings.waypointLabelFontSize;
    final dateStr =
        '${waypoint.createdAt.day.toString().padLeft(2, '0')}/${waypoint.createdAt.month.toString().padLeft(2, '0')}/${waypoint.createdAt.year}';

    // 👇 Réglages de taille : modifie ici si tu veux plus grand/plus petit.
    const double circleSize = 30.0; // diamètre du rond
    const double iconSize = 16.0; // taille de l'icône dans le rond

    return Marker(
      key: ValueKey(
        'wp_${waypoint.latitude}_${waypoint.longitude}_${waypoint.createdAt.millisecondsSinceEpoch}',
      ),
      point: LatLng(waypoint.latitude, waypoint.longitude),
      width: circleSize,
      height: circleSize,
      // 👈 LE CENTRE du rond = le point GPS exact.
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none, // laisse le libellé déborder au-dessus
        alignment: Alignment.center,
        children: [
          // Le rond coloré avec l'icône de catégorie au centre.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onTap(waypoint),
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: waypoint.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                _getWaypointCategoryIcon(waypoint),
                size: iconSize,
                color: Colors.black87,
              ),
            ),
          ),
          // Libellé (nom / date) flottant AU-DESSUS du rond.
          if (hasLabel)
            Positioned(
              bottom: circleSize + 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onTap(waypoint),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showName)
                        Text(
                          waypoint.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (showDate)
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: fontSize - 3,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
