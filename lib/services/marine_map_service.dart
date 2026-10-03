import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/tile_cache/blank_gray_filter.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';

/// Logs de construction des couches (1 à 3 Hz). Laisser à false.
const bool kVerboseLayers = false;

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
        // En mode online : le filtre rend transparentes les zones grises
        // pour laisser voir la couche en dessous.
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
  ///
  /// Le filtre [BlankGrayFilteringTileProvider] distingue lui-même les deux cas :
  /// - tuile 100 % vide **opaque** (SHOM sans couverture) → message « Dézoomez »
  ///   sur la couche du bas ;
  /// - tuile 100 % **transparente** (absente du cache / hors zone, alpha = 0)
  ///   → transparent pur, jamais de message → pas de papier peint hors des
  ///   zones téléchargées.
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
      final index = entry.key; // 0 = couche du BAS
      final layerName = entry.value;
      final zoom = _zoomByLayer[layerName]!;
      final urlTemplate = '$_clevisuWmtsLayerPrefix$layerName';
      if (kVerboseLayers) {
        debugPrint(
          '[MarineService] Layer[$index] $layerName: minNativeZoom=${zoom.minNativeZoom} maxNativeZoom=${zoom.maxNativeZoom}',
        );
      }

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
        // ✅ Plus de paintMessage ici : une tuile absente/vide devient
        //    transparente, et c'est la couche-message DE SOUS qui apparaît.
        tileProvider: BlankGrayFilteringTileProvider(offlineProvider),
        errorImage: MemoryImage(TileProviderFactory.transparentTilePng),
        errorTileCallback: errorTileCallback ?? (tile, error, stackTrace) {},
        evictErrorTileStrategy: EvictErrorTileStrategy.none,
        tileDisplay: TileDisplay.instantaneous(),
      );
    }).toList();

    // 👇 Couche-message SOUS toutes les couches marines : visible partout où
    //    aucune tuile téléchargée n'apporte de contenu (miss ou 100 % vide),
    //    à TOUS les zooms — plus aucune dépendance au seuil 13.5.
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
  ///
  /// [lidarLayersByZone] associe l'uuid de chaque zone prête/partielle à ses
  /// couches LiDAR persistées. Une campagne ne consulte donc QUE les stores
  /// des zones qui la possèdent réellement (au lieu de toutes les zones
  /// prêtes) : moins de stores FMTC interrogés par tuile, moins de misses.
  static List<TileLayer> getOfflineLidarLayers(
    LatLngBounds? visibleBounds,
    Map<String, List<OfflineMapLayer>> lidarLayersByZone, {
    double? opacity,
    ErrorTileCallBack? errorTileCallback,
  }) {
    final enabled = AppSettings.bathymetryOverlayEnabled;
    if (!enabled) return [];

    // 👇 Campagne → uuids des zones qui possèdent RÉELLEMENT des tuiles.
    //    Une couche `skipped` (hors couverture) ou `failed` sans aucune tuile
    //    n'ajoute pas son store : la recherche serait toujours un miss.
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

    // 👇 Filtrage spatial : on ne garde que les campagnes dont l'emprise
    //    intersecte la vue actuelle (la marge de 25 km est gérée par le
    //    catalogue).
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

    // 👇 Résolution campagne → Litto3DLayer, tri sortOrder croissant
    //    (l'ancien dessiné en bas, le récent au-dessus).
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
      // 👇 UNIQUEMENT les stores des zones qui possèdent cette campagne.
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
