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
class MapView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: currentPosition ?? AppSettings.getDefaultMapCenter(),
        initialZoom: zoom,
        minZoom: offlineMode ? 8.0 : AppSettings.getMapMinZoom(),
        maxZoom: AppSettings.getMapMaxZoom(),
        onPositionChanged: (position, hasGesture) {
          if ((position.zoom - zoom).abs() > 0.001) {
            onZoomChanged(position.zoom);
          }
        },
        onMapEvent: (event) {
          if (event is MapEventMove ||
              event is MapEventRotate ||
              event is MapEventNonRotatedSizeChange) {
            onMapCameraChanged();
          }
        },
        onPointerDown: (event, point) {
          onPointerDown();
        },
        onLongPress: (tapPosition, latLng) {
          onLongPress(latLng);
        },
      ),
      children: [
        // ⚠️ Les couches doivent être des enfants DIRECTS de FlutterMap
        // (pas de Column wrapper) :
        ..._buildTileLayers(),
        if (currentPosition != null && selectedWaypointPosition != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [currentPosition!, selectedWaypointPosition!],
                color: Colors.white70.withValues(alpha: 0.8),
                strokeWidth: 2,
                pattern: const StrokePattern.dotted(spacingFactor: 1.8),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            // Position GPS actuelle (en premier, donc en arrière-plan)
            if (currentPosition != null)
              Marker(
                point: currentPosition!,
                width: 80,
                height: 80,
                alignment: Alignment.center,
                child: const GpsMarkerWidget(),
              ),
            // Waypoints de l'utilisateur (en dernier, donc au premier plan)
            if (waypointsVisible)
              ...waypoints.where(_shouldShowWaypoint).map(_buildWaypointMarker),
          ],
        ),
      ],
    );
  }

  // ─── Couches de tuiles ────────────────────────────────────────────────────

  List<Widget> _buildTileLayers() {
    if (mapType == MapType.marine) {
      return offlineMode ? _offlineMarineLayers() : _onlineMarineLayers();
    }
    return [_standardTileLayer()];
  }

  List<Widget> _offlineMarineLayers() => [
    ...MarineMapService.getOfflineMarineTileLayers(zoom, readyZoneUuids),
    if (bathymetryEnabled)
      ...MarineMapService.getOfflineLidarLayers(
        visibleBounds ?? zoneCombinedBounds,
        readyLidarLayers,
        readyZoneUuids,
        opacity: bathymetryOpacity,
      ),
  ];

  List<Widget> _onlineMarineLayers() => [
    ...MarineMapService.getActiveMarineTileLayers(
      zoom,
      zoneUuids: readyZoneUuids,
    ),
    if (bathymetryEnabled)
      ...MarineMapService.getActiveLidarLayers(
        visibleBounds,
        zoneUuids: readyZoneUuids,
        opacity: bathymetryOpacity,
      ),
  ];

  Widget _standardTileLayer() => TileLayer(
    key: ValueKey('basemap_$mapType'),
    urlTemplate: AppSettings.getMapTileUrl(),
    userAgentPackageName: MapTileCacheService.packageName,
    minZoom: AppSettings.getMapMinZoom(),
    minNativeZoom: AppSettings.getMapMinNativeZoom(),
    maxNativeZoom: AppSettings.getMapMaxNativeZoom(),
    maxZoom: AppSettings.getMapMaxZoom(),
    tileProvider: MapTileCacheService.getTileProviderForMapType(mapType),
    errorTileCallback: onErrorTile,
  );

  // ─── Waypoints ────────────────────────────────────────────────────────────

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

  Marker _buildWaypointMarker(Waypoint waypoint) {
    final showName = AppSettings.showWaypointNamesOnMap;
    final showDate = AppSettings.showWaypointDateOnMap;
    final hasLabel = showName || showDate;
    final fontSize = AppSettings.waypointLabelFontSize;
    final dateStr =
        '${waypoint.createdAt.day.toString().padLeft(2, '0')}/${waypoint.createdAt.month.toString().padLeft(2, '0')}/${waypoint.createdAt.year}';
    final iconSize = hasLabel ? (24 + fontSize).roundToDouble() : 40.0;
    final markerWidth = hasLabel ? (140 + fontSize * 3) : 80.0;
    final markerHeight = hasLabel ? (65 + fontSize * 2.5) : 80.0;

    return Marker(
      key: ValueKey(
        'wp_${waypoint.latitude}_${waypoint.longitude}_${waypoint.createdAt.millisecondsSinceEpoch}',
      ),
      point: LatLng(waypoint.latitude, waypoint.longitude),
      width: markerWidth,
      height: markerHeight,
      alignment: Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(waypoint),
        child: hasLabel
            ? _buildLabelMarker(waypoint, dateStr, fontSize, iconSize)
            : _buildIconMarker(waypoint, iconSize),
      ),
    );
  }

  Widget _buildLabelMarker(
    Waypoint waypoint,
    String dateStr,
    double fontSize,
    double iconSize,
  ) {
    final showName = AppSettings.showWaypointNamesOnMap;
    final showDate = AppSettings.showWaypointDateOnMap;

    return Align(
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDE7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showName)
                  Text(
                    waypoint.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (showName && showDate) const SizedBox(height: 2),
                if (showDate)
                  Text(
                    dateStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: fontSize * 0.85,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Opacity(
            opacity: 0.65,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showName)
                  Text(
                    waypoint.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 2),
                if (showDate)
                  Text(
                    dateStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: fontSize * 0.85,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Icon(
                  _getWaypointCategoryIcon(waypoint),
                  color: waypoint.color,
                  size: iconSize,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconMarker(Waypoint waypoint, double iconSize) {
    return Opacity(
      opacity: 0.65,
      child: Align(
        alignment: Alignment.center,
        child: Icon(
          _getWaypointCategoryIcon(waypoint),
          color: waypoint.color,
          size: iconSize,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
    );
  }

  IconData _getWaypointCategoryIcon(Waypoint waypoint) {
    switch (waypoint.category) {
      case WaypointCategory.mushrooms:
        return Icons.park;
      case WaypointCategory.fishing:
        return Icons.anchor;
      case WaypointCategory.other:
        if (waypoint.name.toLowerCase().contains('voiture')) {
          return Icons.directions_car;
        } else {
          return Icons.location_on;
        }
    }
  }
}
