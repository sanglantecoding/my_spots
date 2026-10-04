import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';

/// Résultat du chargement des zones offline.
class OfflineZonesData {
  final List<String> readyZoneUuids;
  final Map<String, List<OfflineMapLayer>> readyLidarLayersByZone;
  final LatLngBounds? zoneCombinedBounds;

  const OfflineZonesData({
    required this.readyZoneUuids,
    required this.readyLidarLayersByZone,
    required this.zoneCombinedBounds,
  });
}

/// Helper pour charger les zones offline et calculer les bounds combinés.
class OfflineZonesLoader {
  OfflineZonesLoader._();

  /// Charge les zones offline prêtes/partielles depuis ObjectBox et calcule
  /// les bounds combinés pour déterminer les couches LiDAR avant le premier
  /// événement de caméra.
  static OfflineZonesData loadOfflineZones() {
    final repo = OfflineMapRepository.instance;
    if (repo == null) {
      return const OfflineZonesData(
        readyZoneUuids: [],
        readyLidarLayersByZone: {},
        zoneCombinedBounds: null,
      );
    }

    final maps = repo.findReadyOrPartialMaps();
    final lidarByZone = <String, List<OfflineMapLayer>>{};

    for (final map in maps) {
      final layers = repo.findLayersForMap(map);
      final lidar = layers
          .where((l) => l.layerType == LayerType.lidarLitto3d)
          .toList();
      if (lidar.isNotEmpty) lidarByZone[map.uuid] = lidar;
    }

    final zoneCombinedBounds = maps.isEmpty
        ? null
        : LatLngBounds(
            LatLng(
              maps.map((m) => m.southLat).reduce((a, b) => a < b ? a : b),
              maps.map((m) => m.westLng).reduce((a, b) => a < b ? a : b),
            ),
            LatLng(
              maps.map((m) => m.northLat).reduce((a, b) => a > b ? a : b),
              maps.map((m) => m.eastLng).reduce((a, b) => a > b ? a : b),
            ),
          );

    return OfflineZonesData(
      readyZoneUuids: maps.map((m) => m.uuid).toList(),
      readyLidarLayersByZone: lidarByZone,
      zoneCombinedBounds: zoneCombinedBounds,
    );
  }
}
