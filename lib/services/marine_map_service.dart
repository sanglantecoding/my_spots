import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/models/offline_map_layer.dart';
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
      maxZoom: 22.0,
      minNativeZoom: 11,
      maxNativeZoom: 14,
    ),
    'RASTER_MARINE_25_WMTS_3857': _MarineLayerZoomConfig(
      minZoom: 13.0,
      maxZoom: 22.0,
      minNativeZoom: 12,
      maxNativeZoom: 15,
    ),
    'RASTER_MARINE_10_WMTS_3857': _MarineLayerZoomConfig(
      minZoom: 15.0,
      maxZoom: 22.0,
      minNativeZoom: 14,
      maxNativeZoom: 16,
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
  ///
  /// If [zoneUuids] is non-empty, the marine [TileProvider] is built with the
  /// given zones as read-only fallback stores (in addition to the network and
  /// the general store). When null or empty, the historical cached
  /// single-store provider is used — i.e. behaviour is strictly unchanged.
  static List<TileLayer> getActiveMarineTileLayers(
    double currentZoom, {
    List<String>? zoneUuids,
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

    // INSTRUMENTATION TEMPORAIRE : log de sélection de couches ONLINE
    debugPrint(
      '[MARINE-ZOOM-LAYERS] mode=ONLINE zoom=$currentZoom layers=$layerOrder',
    );

    return layerOrder.map((layerName) {
      final zoom = _zoomByLayer[layerName]!;
      final urlTemplate = '$_clevisuWmtsLayerPrefix$layerName';

      // INSTRUMENTATION TEMPORAIRE : log de création de TileLayer ONLINE
      debugPrint(
        '[MARINE-TILELAYER] mode=ONLINE layer=$layerName urlTemplate=$urlTemplate minNativeZoom=${zoom.minNativeZoom} maxNativeZoom=${zoom.maxNativeZoom}',
      );

      return TileLayer(
        key: Key('marine_layer_$layerName'),
        urlTemplate: urlTemplate,
        userAgentPackageName: MapTileCacheService.packageName,
        minZoom: zoom.minZoom,
        maxZoom: 22.0, // Permet l'étirement des tuiles sous-jacentes
        minNativeZoom: zoom.minNativeZoom,
        maxNativeZoom: zoom.maxNativeZoom,
        tileDimension: 256,
        keepBuffer: 0,
        panBuffer: 0,
        tileProvider: MapTileCacheService.marineTileProviderFor(
          layerName,
          zoneUuids: zoneUuids,
        ),
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

  /// Builds an INSPIRE WMTS URL for a given WMTS layer name.
  /// Used by LiDAR (Litto3D) and LiDAR ombrage layers.
  static String inspireWmtsUrl(String wmtsLayerName) =>
      '$_inspireWmtsBase&LAYER=$wmtsLayerName';

  /// Active LiDAR (Litto3D) tile layers for the current view.
  ///
  /// Campaign selection is *strictly* delegated to
  /// [LidarRegionCatalog.activeLayersForView] — order, bounds and filtering
  /// are unchanged.
  ///
  /// If [zoneUuids] is non-empty, the bathymetry [TileProvider] is built
  /// with the given zones as read-only fallback stores (in addition to the
  /// network and the general store). When null or empty, the historical
  /// cached single-store provider is used — i.e. behaviour is strictly
  /// unchanged.
  static List<TileLayer> getActiveLidarLayers(
    LatLngBounds? visibleBounds, {
    List<String>? zoneUuids,
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
            zoneUuids: zoneUuids,
          ),
        )
        .toList();
  }

  static TileLayer _lidarTileLayer(
    Litto3DLayer layer, {
    required double opacity,
    ErrorTileCallBack? errorTileCallback,
    List<String>? zoneUuids,
  }) {
    return TileLayer(
      key: Key('lidar_${layer.id}'),
      urlTemplate: inspireWmtsUrl(layer.wmtsLayerName),
      userAgentPackageName: MapTileCacheService.packageName,
      tileDisplay: TileDisplay.instantaneous(opacity: opacity),
      tileProvider: MapTileCacheService.bathymetryTileProviderFor(
        layer.wmtsLayerName,
        zoneUuids: zoneUuids,
      ),
      minNativeZoom: 6,
      maxNativeZoom: 17,
      maxZoom: 22,
      errorTileCallback: (tile, error, stackTrace) {},
    );
  }

  // --- Offline-aware layers (uses FMTC zone stores with network fallback) ---

  /// Marine tile layers for HORS-LIGNE mode.
  ///
  /// Layer selection (which scales are shown at a given zoom) is
  /// **identical** to [getActiveMarineTileLayers] — same `layerOrder`
  /// thresholds, same `minZoom` / `maxZoom`, same stacking order.
  ///
  /// The only difference from ONLINE is the [TileProvider]:
  /// - `loadingStrategy: cacheOnly` — no network requests.
  /// - `stores` contains only `marine_zone_<uuid>` stores; the general
  ///   `marineBase_*` FMTC store is never consulted.
  /// - `TileLayer.key` uses the same values as ONLINE
  ///   (`'marine_layer_$layerName'`), so flutter_map treats both
  ///   modes as the same layer and swaps only the provider on change.
  static List<TileLayer> getOfflineMarineTileLayers(
    double currentZoom,
    List<String> zoneUuids, {
    ErrorTileCallBack? errorTileCallback,
  }) {
    List<String> layerOrder;
    if (currentZoom >= 15.0) {
      layerOrder = [
        'RASTER_MARINE_50_WMTS_3857',
        'RASTER_MARINE_25_WMTS_3857',
        'RASTER_MARINE_10_WMTS_3857',
      ];
    } else if (currentZoom >= 13.0) {
      layerOrder = ['RASTER_MARINE_50_WMTS_3857', 'RASTER_MARINE_25_WMTS_3857'];
    } else if (currentZoom >= 11.0) {
      layerOrder = ['RASTER_MARINE_50_WMTS_3857'];
    } else if (currentZoom >= 9.0) {
      layerOrder = ['RASTER_MARINE_100_WMTS_3857'];
    } else if (currentZoom >= 7.0) {
      layerOrder = ['RASTER_MARINE_350_WMTS_3857'];
    } else {
      layerOrder = ['RASTER_MARINE_3857_WMTS'];
    }

    // INSTRUMENTATION TEMPORAIRE : log de sélection de couches OFFLINE
    debugPrint(
      '[MARINE-ZOOM-LAYERS] mode=OFFLINE zoom=$currentZoom layers=$layerOrder',
    );

    final offlineProvider = MapTileCacheService.offlineMarineTileProvider(
      zoneUuids,
    );

    return layerOrder.map((layerName) {
      final zoom = _zoomByLayer[layerName]!;
      final urlTemplate = '$_clevisuWmtsLayerPrefix$layerName';

      // INSTRUMENTATION TEMPORAIRE : log de création de TileLayer OFFLINE
      debugPrint(
        '[MARINE-TILELAYER] mode=OFFLINE layer=$layerName urlTemplate=$urlTemplate minNativeZoom=${zoom.minNativeZoom} maxNativeZoom=${zoom.maxNativeZoom}',
      );

      return TileLayer(
        key: Key('marine_layer_$layerName'),
        urlTemplate: urlTemplate,
        userAgentPackageName: MapTileCacheService.packageName,
        minZoom: zoom.minZoom,
        maxZoom: 22.0,
        minNativeZoom: zoom.minNativeZoom,
        maxNativeZoom: zoom.maxNativeZoom,
        tileDimension: 256,
        keepBuffer: 0,
        panBuffer: 0,
        // Reuse the same provider across all marine layers so a single
        // FMTCTileProvider handles the cache + network fallback for them.
        tileProvider: offlineProvider,
        errorTileCallback: errorTileCallback ?? (tile, error, stackTrace) {},
        evictErrorTileStrategy: EvictErrorTileStrategy.none,
        tileDisplay: TileDisplay.fadeIn(
          duration: const Duration(milliseconds: 200),
        ),
      );
    }).toList();
  }

  /// LiDAR (Litto3D) tile layers for HORS-LIGNE mode.
  ///
  /// Campaign selection and bounds filtering are **identical** to
  /// [getActiveLidarLayers] — both delegate to
  /// [LidarRegionCatalog.activeLayersForView] with the same `visibleBounds`.
  ///
  /// The only difference from ONLINE is the [TileProvider]:
  /// - `loadingStrategy: cacheOnly` — no network requests.
  /// - `stores` contains only `lidar_zone_<uuid>_<lidarLayerId>` stores; the general
  ///   `bathymetryOverlay_*` FMTC store is never consulted.
  /// - `TileLayer.key` uses the same values as ONLINE
  ///   (`'lidar_${layer.id}'`), so flutter_map treats both
  ///   modes as the same layer and swaps only the provider on change.
  ///
  /// [lidarLayers] are the downloaded LiDAR layers for the ready/partial zones,
  /// each carrying its [OfflineMapLayer.lidarLayerId]. If `lidarLayerId` is null
  /// (legacy zone), the fallback store name `lidar_zone_<uuid>` is used.
  static List<TileLayer> getOfflineLidarLayers(
    LatLngBounds? visibleBounds,
    List<OfflineMapLayer> lidarLayers, {
    double? opacity,
    ErrorTileCallBack? errorTileCallback,
  }) {
    final enabled = AppSettings.bathymetryOverlayEnabled;
    debugPrint(
      '[OFFLINE-LIDAR] enabled=$enabled visibleBounds=$visibleBounds lidarLayers=${lidarLayers.length}',
    );

    if (!enabled) return [];

    // CORRECTION : En mode hors-ligne, on détermine les couches à afficher
    // en fonction des couches ACTUELLEMENT téléchargées (lidarLayers),
    // et non en fonction des bounds visibles de la carte.
    // Cela garantit que les tuiles en cache sont bien affichées.

    // DEBUG : Log détaillé de chaque couche
    for (var i = 0; i < lidarLayers.length; i++) {
      final layer = lidarLayers[i];
      debugPrint(
        '[OFFLINE-LIDAR-DEBUG] Layer $i: lidarLayerId=${layer.lidarLayerId}, '
        'layerType=${layer.layerType.name}, status=${layer.downloadStatus.name}',
      );
    }

    final layers = lidarLayers
        .map((layer) {
          final lidarLayerId = layer.lidarLayerId;
          debugPrint(
            '[OFFLINE-LIDAR-MAP] Trying to find layer with id: $lidarLayerId',
          );
          final found = Litto3DCatalog.findById(lidarLayerId ?? '');
          debugPrint('[OFFLINE-LIDAR-MAP] Found: ${found?.id ?? "NULL"}');
          return found;
        })
        .whereType<Litto3DLayer>()
        .toList();

    debugPrint('[OFFLINE-LIDAR] activeLayers.count=${layers.length}');

    if (layers.isEmpty) return [];

    final layerOpacity = opacity ?? AppSettings.bathymetryOverlayOpacity;

    // Construire les store names LiDAR pour le provider offline
    final lidarStoreNames = lidarLayers
        .map((layer) {
          final zoneUuid = layer.offlineMap.target?.uuid ?? '';
          if (layer.lidarLayerId != null && zoneUuid.isNotEmpty) {
            return 'lidar_zone_${zoneUuid}_${layer.lidarLayerId}';
          } else if (zoneUuid.isNotEmpty) {
            return 'lidar_zone_$zoneUuid';
          }
          return '';
        })
        .where((name) => name.isNotEmpty)
        .toList();

    final offlineProvider = MapTileCacheService.offlineLidarTileProvider(
      lidarStoreNames,
    );

    debugPrint(
      '[OFFLINE-LIDAR] provider stores=${(offlineProvider as dynamic).stores?.keys}',
    );

    return layers.map((layer) {
      debugPrint(
        '[OFFLINE-LIDAR-LAYER] name=${layer.id} created=true provider=${offlineProvider.runtimeType}',
      );
      return TileLayer(
        key: Key('lidar_${layer.id}'),
        urlTemplate: inspireWmtsUrl(layer.wmtsLayerName),
        userAgentPackageName: MapTileCacheService.packageName,
        tileDisplay: TileDisplay.instantaneous(opacity: layerOpacity),
        tileProvider: offlineProvider,
        minNativeZoom: 6,
        maxNativeZoom: 22,
        maxZoom: 22,
        errorTileCallback:
            errorTileCallback ??
            (tile, error, stackTrace) {
              debugPrint(
                '[OFFLINE-LIDAR-TILE-DISPOSE] layer=${layer.id} error=$error',
              );
            },
      );
    }).toList();
  }
}
