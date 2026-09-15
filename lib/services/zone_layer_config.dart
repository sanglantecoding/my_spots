import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/marine_map_service.dart';

/// Configuration des couches pour le téléchargement de zones.
class ZoneLayerConfig {
  /// Génère le nom du store FMTC pour une couche.
  static String fmtcStoreName(
    String zoneUuid,
    LayerType type, [
    String? lidarLayerId,
  ]) {
    switch (type) {
      case LayerType.marine50k:
      case LayerType.marine25k:
      case LayerType.marine10k:
        return 'marine_zone_$zoneUuid';
      case LayerType.lidarLitto3d:
        if (lidarLayerId != null) {
          return 'lidar_zone_${zoneUuid}_$lidarLayerId';
        }
        return 'lidar_zone_$zoneUuid';
    }
  }

  /// Génère l'URL de la couche pour le téléchargement.
  static String layerUrl(
    LayerType type,
    LatLngBounds? zoneBounds, [
    String? lidarLayerId,
  ]) {
    switch (type) {
      case LayerType.marine50k:
        return MarineMapService.clevisuWmtsUrl('RASTER_MARINE_50_WMTS_3857');
      case LayerType.marine25k:
        return MarineMapService.clevisuWmtsUrl('RASTER_MARINE_25_WMTS_3857');
      case LayerType.marine10k:
        return MarineMapService.clevisuWmtsUrl('RASTER_MARINE_10_WMTS_3857');
      case LayerType.lidarLitto3d:
        if (lidarLayerId != null) {
          final layer = Litto3DCatalog.findById(lidarLayerId);
          if (layer != null) {
            return MarineMapService.inspireWmtsUrl(layer.wmtsLayerName);
          }
        }
        if (zoneBounds == null) {
          return MarineMapService.inspireWmtsUrl(
            Litto3DCatalog.allLayers.first.wmtsLayerName,
          );
        }
        final candidates = LidarRegionCatalog.regionsIntersecting(zoneBounds);
        if (candidates.isEmpty) {
          return MarineMapService.inspireWmtsUrl(
            Litto3DCatalog.allLayers.first.wmtsLayerName,
          );
        }
        final firstRegion = candidates.first;
        Litto3DLayer? best;
        for (final id in firstRegion.layerIds) {
          final layer = Litto3DCatalog.findById(id);
          if (layer != null &&
              (best == null || layer.sortOrder > best.sortOrder)) {
            best = layer;
          }
        }
        return MarineMapService.inspireWmtsUrl(
          best?.wmtsLayerName ?? Litto3DCatalog.allLayers.first.wmtsLayerName,
        );
    }
  }

  /// Génère les headers HTTP pour une couche.
  static Map<String, String> layerHeaders(LayerType type) {
    final base = <String, String>{
      'User-Agent':
          '${MapTileCacheService.packageName}/1.0 (Flutter Mobile App)',
      'Accept': 'image/webp,image/png,image/*;q=0.8',
      'Referer': 'https://my-spots.local/',
    };
    if (type == LayerType.marine50k ||
        type == LayerType.marine25k ||
        type == LayerType.marine10k) {
      base['Referer'] = 'https://data.shom.fr/';
    }
    return base;
  }

  /// Génère un label lisible pour une couche.
  static String layerLabel(OfflineMapLayer layer) {
    if (layer.layerType == LayerType.lidarLitto3d &&
        layer.lidarLayerId != null) {
      return 'lidarLitto3d:${layer.lidarLayerId}';
    }
    return layer.layerType.name;
  }
}
