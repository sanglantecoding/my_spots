import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';
import 'package:my_spots/services/tile_cache/blank_gray_filter.dart';

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
    // minZoom 12.0 : flutter_map arrondit le zoom tuile à 13 dès ~12.5.
    // La 25K doit déjà être empilée avant ce palier, sinon les zones
    // transparentes de la 50K native z=13 laissent voir le fond « Dézoomez ».
    'RASTER_MARINE_25_WMTS_3857': _MarineLayerZoomConfig(
      minZoom: 12.0,
      maxZoom: 22.0,
      minNativeZoom: 12,
      maxNativeZoom: 15,
    ),
    'RASTER_MARINE_10_WMTS_3857': _MarineLayerZoomConfig(
      minZoom: 14.0,
      maxZoom: 22.0,
      minNativeZoom: 14,
      maxNativeZoom: 16,
    ),
  };

  /// Ordre d'empilement (bas → haut). Les seuils 12.0 / 14.0 sont en deçà
  /// du demi-niveau (12.5 / 14.5) où flutter_map passe à z entier +1.
  static List<String> _layerOrderForZoom(
    double currentZoom, {
    required bool offline,
  }) {
    if (currentZoom >= 14.0) {
      return const [
        'RASTER_MARINE_50_WMTS_3857',
        'RASTER_MARINE_25_WMTS_3857',
        'RASTER_MARINE_10_WMTS_3857',
      ];
    }
    if (currentZoom >= 12.0) {
      return const ['RASTER_MARINE_50_WMTS_3857', 'RASTER_MARINE_25_WMTS_3857'];
    }
    if (offline) {
      // 100K / 350K / 1M ne sont pas téléchargés hors-ligne : la 50K
      // s'étire (minNativeZoom 11, TileLayer.minZoom 8).
      return const ['RASTER_MARINE_50_WMTS_3857'];
    }
    if (currentZoom >= 11.0) {
      return const ['RASTER_MARINE_50_WMTS_3857'];
    }
    if (currentZoom >= 9.0) {
      return const ['RASTER_MARINE_100_WMTS_3857'];
    }
    if (currentZoom >= 7.0) {
      return const ['RASTER_MARINE_350_WMTS_3857'];
    }
    return const ['RASTER_MARINE_3857_WMTS'];
  }

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
    } else if (currentZoom < 12.5) {
      selectedLayer = 'RASTER_MARINE_50_WMTS_3857';
    } else if (currentZoom < 14.5) {
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
      retinaMode: false,
      tileDimension: 256,
      keepBuffer: 0,
      panBuffer: 0,
      tileProvider: MapTileCacheService.marineTileProviderFor(selectedLayer),
      errorImage: MemoryImage(TileProviderFactory.transparentTilePng),
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
    final layerOrder = _layerOrderForZoom(currentZoom, offline: false);

    final marineLayers = layerOrder.asMap().entries.map((entry) {
      final index = entry.key; // 0 = couche du BAS
      final layerName = entry.value;
      final zoom = _zoomByLayer[layerName]!;
      final urlTemplate = '$_clevisuWmtsLayerPrefix$layerName';
      final rawProvider = MapTileCacheService.marineTileProviderFor(
        layerName,
        zoneUuids: zoneUuids,
      );

      return TileLayer(
        key: Key('marine_layer_$layerName'),
        urlTemplate: urlTemplate,
        userAgentPackageName: MapTileCacheService.packageName,
        minZoom: zoom.minZoom,
        maxZoom: 22.0,
        minNativeZoom: zoom.minNativeZoom,
        maxNativeZoom: zoom.maxNativeZoom,
        retinaMode: false,
        tileDimension: 256,
        keepBuffer: 0,
        panBuffer: 0,
        // 👇 UNIQUEMENT la couche du bas peint le message ;
        // les couches du dessus restent transparentes si elles n'ont rien.
        tileProvider: BlankGrayFilteringTileProvider(
          rawProvider,
          paintMessage: index == 0, // SEUL le bas peint le message
        ),
        errorImage: MemoryImage(TileProviderFactory.transparentTilePng),
        errorTileCallback: errorTileCallback ?? (tile, error, stackTrace) {},
        evictErrorTileStrategy: EvictErrorTileStrategy.none,
        tileDisplay: TileDisplay.instantaneous(),
      );
    }).toList();
    return marineLayers;
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
    // Hors-ligne : mêmes seuils 12.0 / 14.0 que l'online. En dessous de 12,
    // seule la 50K (téléchargée) reste et s'étire.
    final layerOrder = _layerOrderForZoom(currentZoom, offline: true);

    final offlineProvider = MapTileCacheService.offlineMarineTileProvider(
      zoneUuids,
    );

    final marineLayers = layerOrder.asMap().entries.map((entry) {
      final index = entry.key;
      final layerName = entry.value;
      final zoom = _zoomByLayer[layerName]!;
      final urlTemplate = '$_clevisuWmtsLayerPrefix$layerName';

      return TileLayer(
        key: Key('marine_layer_$layerName'),
        urlTemplate: urlTemplate,
        userAgentPackageName: MapTileCacheService.packageName,
        minZoom: 8.0,
        maxZoom: 22.0,
        minNativeZoom: zoom.minNativeZoom,
        maxNativeZoom: zoom.maxNativeZoom,
        retinaMode: false,
        tileDimension: 256,
        keepBuffer: 0,
        panBuffer: 0,
        tileProvider: BlankGrayFilteringTileProvider(
          offlineProvider,
          paintMessage: index == 0,
        ),
        errorImage: MemoryImage(TileProviderFactory.transparentTilePng),
        errorTileCallback: errorTileCallback ?? (tile, error, stackTrace) {},
        evictErrorTileStrategy: EvictErrorTileStrategy.none,
        tileDisplay: TileDisplay.instantaneous(),
      );
    }).toList();
    return marineLayers;
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
    List<OfflineMapLayer> lidarLayers,
    List<String> zoneUuids, {
    double? opacity,
    ErrorTileCallBack? errorTileCallback,
  }) {
    final enabled = AppSettings.bathymetryOverlayEnabled;
    if (!enabled) return [];

    // Déterminer les couches à afficher
    final layers = lidarLayers
        .map((layer) {
          return Litto3DCatalog.findById(layer.lidarLayerId ?? '');
        })
        .whereType<Litto3DLayer>()
        .toList();

    if (layers.isEmpty) return [];

    final layerOpacity = opacity ?? AppSettings.bathymetryOverlayOpacity;

    // CORRECTION : Créer UN provider par couche (pas un provider global)
    return layers.map((layer) {
      // Créer le store name pour CETTE couche spécifique
      final storeNames = <String>[];
      for (final uuid in zoneUuids) {
        if (uuid.isNotEmpty && layer.id.isNotEmpty) {
          storeNames.add('lidar_zone_${uuid}_${layer.id}');
        }
      }

      // Créer un provider dédié pour cette couche
      final offlineProvider = MapTileCacheService.offlineLidarTileProvider(
        storeNames,
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
        errorTileCallback: errorTileCallback ?? (tile, error, stackTrace) {},
      );
    }).toList();
  }
}
