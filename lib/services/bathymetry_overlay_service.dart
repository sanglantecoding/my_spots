import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';

/// Litto3D côtier-maritime — flux WMTS SHOM INSPIRE (EPSG:3857).
class BathymetryOverlayService {
  /// URL de base du flux WMTS SHOM INSPIRE (Web Mercator / tuile 3857).
  static const String _shomWmtsBase =
      'https://services.data.shom.fr/INSPIRE/wmts'
      '?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0'
      '&STYLE=normal'
      '&FORMAT=image/png'
      '&TILEMATRIXSET=3857'
      '&TILEMATRIX={z}&TILECOL={x}&TILEROW={y}';

  /// Débug 1 — isolation : passer à `true` pour n'afficher qu'une seule couche.
  static const bool debugSingleLayerOnly = false;
  static const String debugSingleLayerName =
      'L3D_MAR_LR_2014_2015_WMTS_3857';

  /// Empilement rendu : fond (2009) → milieu (2011) → premier plan (2014-2015).
  static const List<String> _layersBottomToTop = [
    'LITTO3D_LR_2009_PYR_3857_WMTS',
    'L3D_MAR_LR_2011_PYR_3857_WMTS',
    'L3D_MAR_LR_2014_2015_WMTS_3857',
  ];

  static List<TileLayer> getLayers({
    required double opacity,
    TileProvider Function(String layerName)? tileProviderForLayer,
  }) {
    final String baseUrl = '$_shomWmtsBase&LAYER=';

    final layers = debugSingleLayerOnly
        ? [debugSingleLayerName]
        : _layersBottomToTop;

    return layers.map((layerName) {
      return TileLayer(
        key: Key('bathymetry_$layerName'),
        urlTemplate: '$baseUrl$layerName',
        userAgentPackageName: MapTileCacheService.packageName,
        tileDisplay: TileDisplay.instantaneous(opacity: opacity),
        tileProvider: tileProviderForLayer?.call(layerName) ??
            MapTileCacheService.bathymetryTileProviderFor(layerName),
        minNativeZoom: 6,
        maxNativeZoom: 18,
        maxZoom: 22,
      );
    }).toList();
  }
}
