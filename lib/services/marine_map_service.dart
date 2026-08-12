import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';

/// Cartes marines RasterMarine SHOM — empilement par échelle (clevisu WMTS).
///
/// Les identifiants `5_RASTER_3857_WMTS` / `4_RASTER_3857_WMTS` ne sont pas
/// publiés sur le WMTS INSPIRE ; les gammes d'échelle sont diffusées sur
/// clevisu sous les noms `RASTER_MARINE_*_WMTS_3857`.
class MarineMapService {
  static const String _clevisuWmtsLayerPrefix =
      'https://services.data.shom.fr/clevisu/wmts'
      '?style=normal'
      '&tilematrixset=3857'
      '&Service=WMTS&Request=GetTile&Version=1.0.0'
      '&Format=image/png'
      '&TileMatrix={z}&TileCol={x}&TileRow={y}'
      '&layer=';

  /// Du général au détaillé : la dernière couche recouvre les trous des autres.
  static const List<String> _layersBottomToTop = [
    'RASTER_MARINE_50_WMTS_3857', // ~1:50 000 (cartes d'approche)
    'RASTER_MARINE_25_WMTS_3857', // ~1:25 000
    'RASTER_MARINE_10_WMTS_3857', // ~1:10 000 (ports et détails)
  ];

  static List<TileLayer> getLayers({
    ErrorTileCallBack? errorTileCallback,
  }) {
    return _layersBottomToTop.map((layerName) {
      return TileLayer(
        key: Key('marine_$layerName'),
        urlTemplate: '$_clevisuWmtsLayerPrefix$layerName',
        userAgentPackageName: MapTileCacheService.packageName,
        minZoom: AppSettings.getMapMinZoom(),
        minNativeZoom: AppSettings.getMapMinNativeZoom(),
        maxNativeZoom: AppSettings.getMapMaxNativeZoom(),
        maxZoom: AppSettings.getMapMaxZoom(),
        tileProvider: MapTileCacheService.marineTileProviderFor(layerName),
        errorTileCallback: errorTileCallback,
      );
    }).toList();
  }
}
