import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/marine_map_service.dart';

import 'package:my_spots/services/zone_download/repository_interface.dart';
import 'package:my_spots/services/zone_download/layer_download_result.dart';
import 'package:my_spots/services/zone_download/fmtc_layer_downloader.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/negative_tile_filter.dart';

// ─── Callbacks publics ──────────────────────────────────────────────────────

/// Callback de progression pour une zone en cours de téléchargement.
///
/// [progress] est compris entre 0.0 et 1.0 (progression globale de la zone).
/// [layerLabel] est le libellé de la couche actuellement en cours.
typedef ZoneProgressCallback =
    void Function({required double progress, required String layerLabel});

/// Callback d'erreur pour une zone en cours de téléchargement.
typedef ZoneErrorCallback = void Function(String message);

// ─── État interne d'une zone ────────────────────────────────────────────────

class _ZoneState {
  bool isCancelled = false;
  int completedLayers = 0;
  int failedLayers = 0;
  Completer<void>? allDone;
  FMTCStore? activeStore;
  String? activeInstanceId;
}

// ─── Service principal ──────────────────────────────────────────────────────

/// Orchestrateur du téléchargement hors-ligne d'une zone.
///
/// Gère le cycle de vie complet :
/// - Téléchargement séquentiel de chaque couche (marine 50k/25k/10k + LiDAR)
/// - Suivi de la progression et gestion des erreurs
/// - Évaluation finale (ready / partial / failed)
/// - Annulation, pause et reprise
class ZoneDownloadService {
  ZoneDownloadService({
    required MapLayerRepository repository,
    LayerDownloader downloader = const FmtcLayerDownloader(),
  }) : _repository = repository,
       _downloader = downloader;

  final MapLayerRepository _repository;
  final LayerDownloader _downloader;
  final Map<String, _ZoneState> _zones = {};
  final Map<String, int> _runCounters = {};
  final Map<String, String> _previousInstanceIds = {};

  /// Accès au repository (utile pour les tests).
  MapLayerRepository get repository => _repository;

  /// `true` si une zone est en cours de téléchargement.
  bool isDownloading(String zoneUuid) => _zones.containsKey(zoneUuid);

  /// Nombre de zones actuellement en cours de téléchargement.
  int get activeCount => _zones.length;

  /// Télécharge toutes les couches d'une zone.
  ///
  /// Les couches sont téléchargées séquentiellement. En cas d'erreur réseau
  /// sur une couche, le téléchargement continue avec les couches suivantes
  /// (la zone sera marquée `partial` à la fin).
  Future<void> downloadZone({
    required OfflineMap map,
    required List<OfflineMapLayer> layers,
    LatLngBounds? zoneBounds,
    ZoneProgressCallback? onProgress,
    ZoneErrorCallback? onError,
  }) async {
    final zoneUuid = map.uuid;
    final runCount = _runCounters[zoneUuid] ?? 0;

    if (_zones.containsKey(zoneUuid)) return;

    final state = _zones[zoneUuid] = _ZoneState()..allDone = Completer();
    _runCounters[zoneUuid] = runCount + 1;
    final preCancelId = _previousInstanceIds[zoneUuid];
    bool initializationFailed = false;

    try {
      map.status = OfflineMapStatus.downloading;
      _repository.save(map);

      for (final layer in layers) {
        _repository.saveLayer(map, layer);
        layer.estimatedTileCount = 0;
        layer.downloadedTileCount = 0;
        layer.downloadStatus = LayerDownloadStatus.downloading;
      }

      final bounds =
          zoneBounds ??
          LatLngBounds(
            LatLng(map.southLat, map.westLng),
            LatLng(map.northLat, map.eastLng),
          );
      final routingBounds = zoneBounds;

      final layerResults = <LayerType, LayerDownloadResult>{};

      for (var i = 0; i < layers.length; i++) {
        if (state.isCancelled) break;

        final layer = layers[i];
        final layerLabel = _layerLabel(layer);

        final instanceId = '${map.uuid}#$runCount';
        final storeName = _fmtcStoreName(
          map.uuid,
          layer.layerType,
          layer.lidarLayerId,
        );
        final store = FMTCStore(storeName);
        state.activeStore = store;
        state.activeInstanceId = instanceId;

        LayerDownloadResult result;
        try {
          result = await _downloader.downloadLayer(
            zoneUuid: map.uuid,
            store: store,
            instanceId: instanceId,
            urlTemplate: _layerUrl(
              layer.layerType,
              routingBounds,
              layer.lidarLayerId,
            ),
            bounds: bounds,
            minZoom: layer.minZoom,
            maxZoom: layer.maxZoom,
            headers: _layerHeaders(layer.layerType),
            onProgress: (layerProgress) {
              if (layers.isNotEmpty) {
                onProgress?.call(
                  progress: (i + layerProgress) / layers.length,
                  layerLabel: layerLabel,
                );
              }
            },
            preCancelInstanceId: preCancelId,
            preCancelStore: store,
          );
        } catch (e) {
          state.failedLayers++;
          layer.downloadStatus = LayerDownloadStatus.failed;
          layer.estimatedTileCount = 0;
          layer.downloadedTileCount = 0;
          _repository.saveLayer(map, layer);
          onError?.call('Erreur reseau couche $layerLabel: $e');
          continue;
        }

        if (state.isCancelled) break;

        layer.estimatedTileCount = result.estimatedTileCount;
        layer.downloadedTileCount = result.downloadedTileCount;

        if (result.successful) {
          state.completedLayers++;
          layer.downloadStatus = LayerDownloadStatus.completed;
        } else {
          state.failedLayers++;
          layer.downloadStatus = LayerDownloadStatus.failed;
        }
        _repository.saveLayer(map, layer);

        layerResults[layer.layerType] = result;
      }

      final lastInstance = state.activeInstanceId;
      if (lastInstance != null) {
        _previousInstanceIds[map.uuid] = lastInstance;
      }

      _finalizeZone(map, state, layers, onError);
    } catch (e) {
      initializationFailed = true;
      final msg = 'Erreur initialisation zone: $e';
      onError?.call(msg);
    } finally {
      if (initializationFailed) {
        map.status = OfflineMapStatus.failed;
        _repository.save(map);
        _zones.remove(map.uuid);
      }
    }

    state.allDone?.complete();
    if (!initializationFailed) {
      _zones.remove(map.uuid);
    }
  }

  /// Finalise le statut d'une zone après téléchargement de toutes ses couches.
  void _finalizeZone(
    OfflineMap map,
    _ZoneState state,
    List<OfflineMapLayer> layers, [
    ZoneErrorCallback? onError,
  ]) {
    if (state.isCancelled) {
      map.status = OfflineMapStatus.failed;
      _repository.save(map);
      onError?.call('Telechargement annule');
      return;
    }

    var totalDownloaded = 0;
    for (final layer in layers) {
      totalDownloaded += layer.downloadedTileCount;
    }

    if (state.failedLayers == 0) {
      map.status = OfflineMapStatus.ready;
      map.completedAt = DateTime.now();
    } else if (state.completedLayers == 0 && totalDownloaded == 0) {
      map.status = OfflineMapStatus.failed;
      onError?.call(
        'Echec total: aucune tuile telechargee. Verifiez votre connexion et les coordonnees de la zone.',
      );
    } else {
      map.status = OfflineMapStatus.partial;
      map.completedAt = DateTime.now();
    }
    _repository.save(map);

    // Invalidate the store names cache after a successful download
    // to ensure the new stores are properly reflected
    NegativeFilteringImageProvider.clearStoreNamesCache();
  }

  /// Annule le téléchargement d'une zone.
  Future<void> cancelDownload(String zoneUuid) async {
    final state = _zones[zoneUuid];
    if (state == null) return;

    state.isCancelled = true;
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;

    if (store != null && instanceId != null) {
      await _downloader.cancel(zoneUuid, store, instanceId);
    }
  }

  /// Met en pause le téléchargement d'une zone.
  void pauseDownload(String zoneUuid) {
    final state = _zones[zoneUuid];
    if (state == null) return;
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;
    if (store != null && instanceId != null) {
      _downloader.pause(zoneUuid, store, instanceId);
    }
  }

  /// Reprend le téléchargement d'une zone précédemment mise en pause.
  void resumeDownload(String zoneUuid) {
    final state = _zones[zoneUuid];
    if (state == null) return;
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;
    if (store != null && instanceId != null) {
      _downloader.resume(zoneUuid, store, instanceId);
    }
  }

  // ─── Helpers internes ─────────────────────────────────────────────────────

  /// Génère le nom du store FMTC pour une couche.
  String _fmtcStoreName(
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
  String _layerUrl(
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
  Map<String, String> _layerHeaders(LayerType type) {
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

  /// Génère un libellé lisible pour une couche.
  String _layerLabel(OfflineMapLayer layer) {
    if (layer.layerType == LayerType.lidarLitto3d &&
        layer.lidarLayerId != null) {
      return 'lidarLitto3d:${layer.lidarLayerId}';
    }
    return layer.layerType.name;
  }
}
