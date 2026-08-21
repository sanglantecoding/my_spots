import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';

/// Plages de zoom par échelle RasterMarine (clevisu SHOM).
class _MarineLayerZoomConfig {
  const _MarineLayerZoomConfig({
    required this.minZoom,
    required this.maxZoom,
    required this.minNativeZoom,
    required this.maxNativeZoom,
  });

  final double minZoom;
  final double maxZoom;
  final int minNativeZoom;
  final int maxNativeZoom;
}

class MarineMapService {
  static const String _clevisuWmtsLayerPrefix =
      'https://services.data.shom.fr/clevisu/wmts'
      '?style=normal'
      '&tilematrixset=3857'
      '&Service=WMTS&Request=GetTile&Version=1.0.0'
      '&Format=image/png'
      '&TileMatrix={z}&TileCol={x}&TileRow={y}'
      '&layer=';

  static const String layer10k = 'RASTER_MARINE_10_WMTS_3857';

  static String clevisuWmtsUrl(String layerName) =>
      '$_clevisuWmtsLayerPrefix$layerName';

  static const Map<String, _MarineLayerZoomConfig> _zoomByLayer = {
    'RASTER_MARINE_3857_WMTS': _MarineLayerZoomConfig(
      minZoom: 1.0,
      maxZoom: 8.0,
      minNativeZoom: 1,
      maxNativeZoom: 7,
    ),
    'RASTER_MARINE_350_WMTS_3857': _MarineLayerZoomConfig(
      minZoom: 7.0,
      maxZoom: 10.0,
      minNativeZoom: 6,
      maxNativeZoom: 9,
    ),
    'RASTER_MARINE_100_WMTS_3857': _MarineLayerZoomConfig(
      minZoom: 9.0,
      maxZoom: 12.0,
      minNativeZoom: 9,
      maxNativeZoom: 11,
    ),
    'RASTER_MARINE_50_WMTS_3857': _MarineLayerZoomConfig(
      minZoom: 11.0,
      maxZoom: 14.0,
      minNativeZoom: 11,
      maxNativeZoom: 19,
    ),
    'RASTER_MARINE_25_WMTS_3857': _MarineLayerZoomConfig(
      minZoom: 13.0,
      maxZoom: 16.0,
      minNativeZoom: 12,
      maxNativeZoom: 19,
    ),
    'RASTER_MARINE_10_WMTS_3857': _MarineLayerZoomConfig(
      minZoom: 15.0,
      maxZoom: 22.0,
      minNativeZoom: 14,
      maxNativeZoom: 19,
    ),
  };

  /// Renvoie UNE SEULE couche active selon le zoom courant (350k inclus).
  static TileLayer getActiveMarineTileLayer(
    double currentZoom, {
    ErrorTileCallBack? errorTileCallback,
  }) {
    String selectedLayer;

    if (currentZoom < 7.5) {
      selectedLayer = 'RASTER_MARINE_3857_WMTS';
    } else if (currentZoom < 9.5) {
      selectedLayer = 'RASTER_MARINE_350_WMTS_3857';
    } else if (currentZoom < 11.5) {
      selectedLayer = 'RASTER_MARINE_100_WMTS_3857';
    } else if (currentZoom < 13.5) {
      selectedLayer = 'RASTER_MARINE_50_WMTS_3857';
    } else if (currentZoom < 15.5) {
      selectedLayer = 'RASTER_MARINE_25_WMTS_3857';
    } else {
      selectedLayer = 'RASTER_MARINE_10_WMTS_3857';
    }

    final zoom = _zoomByLayer[selectedLayer]!;

    return TileLayer(
      key: Key('marine_layer_$selectedLayer'),
      urlTemplate: '$_clevisuWmtsLayerPrefix$selectedLayer',
      userAgentPackageName: MapTileCacheService.packageName,
      minZoom: zoom.minZoom,
      maxZoom: zoom.maxZoom,
      minNativeZoom: zoom.minNativeZoom,
      maxNativeZoom: zoom.maxNativeZoom,
      tileDimension: 256,
      keepBuffer: 0,
      panBuffer: 0,
      tileProvider: MapTileCacheService.marineTileProviderFor(selectedLayer),
      errorTileCallback: (tile, error, stackTrace) {},
      evictErrorTileStrategy: EvictErrorTileStrategy.none,
    );
  }

  /// Renvoie une LISTE de couches empilées selon l'échelle active pour éviter le fond blanc.
  /// Les couches sont empilées de la plus générale (en bas) à la plus précise (en haut).
  /// Chaque couche a maxZoom: 22.0 pour permettre l'étirement des tuiles sous-jacentes.
  static List<TileLayer> getActiveMarineTileLayers(
    double currentZoom, {
    ErrorTileCallBack? errorTileCallback,
  }) {
    List<String> layerOrder;

    if (currentZoom >= 15.0) {
      // Echelle 10k : empiler [50k, 25k, 10k]
      layerOrder = [
        'RASTER_MARINE_50_WMTS_3857',
        'RASTER_MARINE_25_WMTS_3857',
        'RASTER_MARINE_10_WMTS_3857',
      ];
    } else if (currentZoom >= 13.0) {
      // Echelle 25k : empiler [50k, 25k]
      layerOrder = ['RASTER_MARINE_50_WMTS_3857', 'RASTER_MARINE_25_WMTS_3857'];
    } else if (currentZoom >= 11.0) {
      // Echelle 50k : couche [50k] uniquement
      layerOrder = ['RASTER_MARINE_50_WMTS_3857'];
    } else if (currentZoom >= 9.0) {
      // Echelle 100k : couche [100k] uniquement
      layerOrder = ['RASTER_MARINE_100_WMTS_3857'];
    } else if (currentZoom >= 7.0) {
      // Echelle 350k : couche [350k] uniquement
      layerOrder = ['RASTER_MARINE_350_WMTS_3857'];
    } else {
      // Echelle 1M / Carte du monde : couche globale [3857_WMTS]
      layerOrder = ['RASTER_MARINE_3857_WMTS'];
    }

    return layerOrder.map((layerName) {
      final zoom = _zoomByLayer[layerName]!;

      return TileLayer(
        key: Key('marine_layer_$layerName'),
        urlTemplate: '$_clevisuWmtsLayerPrefix$layerName',
        userAgentPackageName: MapTileCacheService.packageName,
        minZoom: zoom.minZoom,
        maxZoom: 22.0, // Permet l'étirement des tuiles sous-jacentes
        minNativeZoom: zoom.minNativeZoom,
        maxNativeZoom: zoom.maxNativeZoom,
        tileDimension: 256,
        keepBuffer: 0,
        panBuffer: 0,
        tileProvider: MapTileCacheService.marineTileProviderFor(layerName),
        errorTileCallback: errorTileCallback ?? (tile, error, stackTrace) {},
        evictErrorTileStrategy: EvictErrorTileStrategy.none,
        tileDisplay: TileDisplay.fadeIn(
          duration: const Duration(milliseconds: 200),
        ),
      );
    }).toList();
  }

  static const String _inspireWmtsBase =
      'https://services.data.shom.fr/INSPIRE/wmts'
      '?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0'
      '&STYLE=normal'
      '&FORMAT=image/png'
      '&TILEMATRIXSET=3857'
      '&TILEMATRIX={z}&TILECOL={x}&TILEROW={y}';

  static List<TileLayer> getActiveLidarLayers(
    LatLngBounds? visibleBounds, {
    double? opacity,
    ErrorTileCallBack? errorTileCallback,
  }) {
    if (!AppSettings.bathymetryOverlayEnabled) return [];
    if (visibleBounds == null) return [];

    final layers = LidarRegionCatalog.activeLayersForView(visibleBounds);
    if (layers.isEmpty) return [];

    final layerOpacity = opacity ?? AppSettings.bathymetryOverlayOpacity;

    return layers
        .map(
          (layer) => _lidarTileLayer(
            layer,
            opacity: layerOpacity,
            errorTileCallback: errorTileCallback,
          ),
        )
        .toList();
  }

  static TileLayer _lidarTileLayer(
    Litto3DLayer layer, {
    required double opacity,
    ErrorTileCallBack? errorTileCallback,
  }) {
    return TileLayer(
      key: Key('lidar_${layer.id}'),
      urlTemplate: '$_inspireWmtsBase&LAYER=${layer.wmtsLayerName}',
      userAgentPackageName: MapTileCacheService.packageName,
      tileDisplay: TileDisplay.instantaneous(opacity: opacity),
      tileProvider: MapTileCacheService.bathymetryTileProviderFor(
        layer.wmtsLayerName,
      ),
      minNativeZoom: 6,
      maxNativeZoom: 18,
      maxZoom: 22,
      errorTileCallback: (tile, error, stackTrace) {},
    );
  }
}
