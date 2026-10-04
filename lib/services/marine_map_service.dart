import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/models/marine_layer.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/tile_cache/blank_gray_filter.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';

/// Logs de construction des couches (1 à 3 Hz). Laisser à false.
const bool kVerboseLayers = false;

class MarineMapService {
  static const String _clevisuWmtsLayerPrefix =
      'https://services.data.shom.fr/clevisu/wmts'
      '?style=normal'
      '&tilematrixset=3857'
      '&Service=WMTS&Request=GetTile&Version=1.0.0'
      '&Format=image/png'
      '&TileMatrix={z}&TileCol={x}&TileRow={y}'
      '&layer=';

  static String clevisuWmtsUrl(String layerName) =>
      '$_clevisuWmtsLayerPrefix$layerName';

  /// Ordre d'empilement (bas → haut). Les seuils 12.0 / 14.0 sont en deçà
  /// du demi-niveau (12.5 / 14.5) où flutter_map passe à z entier +1.
  static List<String> _layerOrderForZoom(
    double currentZoom, {
    required bool offline,
  }) {
    // Utilisation des noms centralisés depuis le catalogue
    final n50 = MarineLayerCatalog.marine50k.wmtsLayerName;
    final n25 = MarineLayerCatalog.marine25k.wmtsLayerName;
    final n10 = MarineLayerCatalog.marine10k.wmtsLayerName;
    final n100 = MarineLayerCatalog.marine100k.wmtsLayerName;
    final n350 = MarineLayerCatalog.marine350k.wmtsLayerName;
    final nOverview = MarineLayerCatalog.overview.wmtsLayerName;

    if (currentZoom >= 14.0) {
      return [n50, n25, n10];
    }
    if (currentZoom >= 12.0) {
      return [n50, n25];
    }
    if (offline) {
      return [n50];
    }
    if (currentZoom >= 11.0) {
      return [n50];
    }
    if (currentZoom >= 9.0) {
      return [n100];
    }
    if (currentZoom >= 7.0) {
      return [n350];
    }
    return [nOverview];
  }

  @visibleForTesting
  static List<String> layerOrderForZoom(double zoom, {bool offline = false}) =>
      _layerOrderForZoom(zoom, offline: offline);

  static List<TileLayer> getActiveMarineTileLayers(
    double currentZoom, {
    List<String>? zoneUuids,
    ErrorTileCallBack? errorTileCallback,
  }) {
    final layerOrder = _layerOrderForZoom(currentZoom, offline: false);

    final marineLayers = layerOrder.asMap().entries.map((entry) {
      final index = entry.key; // 0 = couche du BAS
      final layerName = entry.value;
      final layer = MarineLayerCatalog.findByWmtsName(layerName)!;
      final urlTemplate = '$_clevisuWmtsLayerPrefix$layerName';
      final rawProvider = MapTileCacheService.marineTileProviderFor(
        layerName,
        zoneUuids: zoneUuids,
      );

      return TileLayer(
        key: Key('marine_layer_$layerName'),
        urlTemplate: urlTemplate,
        userAgentPackageName: MapTileCacheService.packageName,
        minZoom: layer.minZoom,
        maxZoom: 22.0,
        minNativeZoom: layer.minNativeZoom,
        maxNativeZoom: layer.maxNativeZoom,
        retinaMode: false,
        tileDimension: 256,
        keepBuffer: 0,
        panBuffer: 0,
        tileProvider: BlankGrayFilteringTileProvider(
          rawProvider,
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

  static const String _inspireWmtsBase =
      'https://services.data.shom.fr/INSPIRE/wmts'
      '?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0'
      '&STYLE=normal'
      '&FORMAT=image/png'
      '&TILEMATRIXSET=3857'
      '&TILEMATRIX={z}&TILECOL={x}&TILEROW={y}';

  static String inspireWmtsUrl(String wmtsLayerName) =>
      '$_inspireWmtsBase&LAYER=$wmtsLayerName';

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
      minZoom: 11,
      minNativeZoom: 6,
      maxNativeZoom: 17,
      maxZoom: 22,
      errorTileCallback: errorTileCallback ?? (tile, error, stackTrace) {},
    );
  }

  /// Couches marines en mode HORS-LIGNE.
  static List<TileLayer> getOfflineMarineTileLayers(
    double currentZoom,
    List<String> zoneUuids, {
    ErrorTileCallBack? errorTileCallback,
  }) {
    final layerOrder = _layerOrderForZoom(currentZoom, offline: true);

    final offlineProvider = MapTileCacheService.offlineMarineTileProvider(
      zoneUuids,
    );

    final marineLayers = layerOrder.asMap().entries.map((entry) {
      final index = entry.key;
      final layerName = entry.value;
      final layer = MarineLayerCatalog.findByWmtsName(layerName)!;
      final urlTemplate = '$_clevisuWmtsLayerPrefix$layerName';
      if (kVerboseLayers) {
        debugPrint(
          '[MarineService] Layer[$index] $layerName: minNativeZoom=${layer.minNativeZoom} maxNativeZoom=${layer.maxNativeZoom}',
        );
      }

      return TileLayer(
        key: Key('marine_layer_$layerName'),
        urlTemplate: urlTemplate,
        userAgentPackageName: MapTileCacheService.packageName,
        minZoom: 8.0,
        maxZoom: 22.0,
        minNativeZoom: layer.minNativeZoom,
        maxNativeZoom: layer.maxNativeZoom,
        retinaMode: false,
        tileDimension: 256,
        keepBuffer: 0,
        panBuffer: 0,
        tileProvider: BlankGrayFilteringTileProvider(offlineProvider),
        errorImage: MemoryImage(TileProviderFactory.transparentTilePng),
        errorTileCallback: errorTileCallback ?? (tile, error, stackTrace) {},
        evictErrorTileStrategy: EvictErrorTileStrategy.none,
        tileDisplay: TileDisplay.instantaneous(),
      );
    }).toList();

    return [
      TileLayer(
        key: const Key('offline_message_base'),
        urlTemplate: 'https://offline.message.local/{z}/{x}/{y}',
        userAgentPackageName: MapTileCacheService.packageName,
        minZoom: 1.0,
        maxZoom: 22.0,
        tileProvider: MessageBaseTileProvider(),
        tileDisplay: TileDisplay.instantaneous(),
      ),
      ...marineLayers,
    ];
  }

  /// Couches LiDAR en mode HORS-LIGNE.
  static List<TileLayer> getOfflineLidarLayers(
    LatLngBounds? visibleBounds,
    Map<String, List<OfflineMapLayer>> lidarLayersByZone, {
    double? opacity,
    ErrorTileCallBack? errorTileCallback,
  }) {
    final enabled = AppSettings.bathymetryOverlayEnabled;
    if (!enabled) return [];

    final zonesByCampaign = <String, List<String>>{};
    lidarLayersByZone.forEach((uuid, layers) {
      if (uuid.isEmpty) return;
      for (final layer in layers) {
        final campaignId = layer.lidarLayerId;
        if (campaignId == null || campaignId.isEmpty) continue;
        final hasTiles =
            layer.downloadStatus == LayerDownloadStatus.completed ||
            layer.downloadedTileCount > 0;
        if (!hasTiles) continue;
        zonesByCampaign.putIfAbsent(campaignId, () => []).add(uuid);
      }
    });
    if (zonesByCampaign.isEmpty) return [];

    Set<String>? allowedLayerIds;
    if (visibleBounds != null) {
      allowedLayerIds = <String>{};
      final intersectingRegions = LidarRegionCatalog.regionsIntersecting(
        visibleBounds,
      );
      for (final region in intersectingRegions) {
        allowedLayerIds.addAll(region.layerIds);
      }
    }

    final campaigns = <Litto3DLayer>[];
    for (final campaignId in zonesByCampaign.keys) {
      if (allowedLayerIds != null && !allowedLayerIds.contains(campaignId)) {
        continue;
      }
      final litto = Litto3DCatalog.findById(campaignId);
      if (litto != null) campaigns.add(litto);
    }
    if (campaigns.isEmpty) return [];
    campaigns.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final layerOpacity = opacity ?? AppSettings.bathymetryOverlayOpacity;
    return campaigns.map((layer) {
      final storeNames = <String>[
        for (final uuid in zonesByCampaign[layer.id]!)
          'lidar_zone_${uuid}_${layer.id}',
      ];
      final offlineProvider = MapTileCacheService.offlineLidarTileProvider(
        storeNames,
      );
      int campaignMaxNativeZoom = 16;
      int campaignMinNativeZoom = 11;
      bool found = false;
      for (final uuid in zonesByCampaign[layer.id]!) {
        final zoneLayers = lidarLayersByZone[uuid] ?? [];
        for (final ol in zoneLayers) {
          if (ol.lidarLayerId == layer.id) {
            campaignMaxNativeZoom = ol.maxZoom;
            campaignMinNativeZoom = ol.minZoom;
            found = true;
            break;
          }
          if (found) break;
        }
      }
      return TileLayer(
        key: Key('lidar_${layer.id}'),
        urlTemplate: inspireWmtsUrl(layer.wmtsLayerName),
        userAgentPackageName: MapTileCacheService.packageName,
        tileDisplay: TileDisplay.instantaneous(opacity: layerOpacity),
        tileProvider: offlineProvider,
        minZoom: 11,
        minNativeZoom: campaignMinNativeZoom,
        maxNativeZoom: campaignMaxNativeZoom,
        maxZoom: 22,
        errorTileCallback: errorTileCallback ?? (tile, error, stackTrace) {},
      );
    }).toList();
  }
}
