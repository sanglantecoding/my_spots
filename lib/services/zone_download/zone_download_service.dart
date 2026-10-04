import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/models/marine_layer.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/marine_map_service.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';
import 'package:my_spots/services/zone_download/repository_interface.dart';
import 'package:my_spots/services/zone_download/layer_download_result.dart';
import 'package:my_spots/services/zone_download/fmtc_layer_downloader.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/negative_tile_filter.dart';
import 'package:my_spots/services/tile_cache/tile_provider_factory.dart';

/// Logs de debugging zone download. Laisser à false.
const bool kVerboseZoneDownload = false;

// ─── Callbacks publics ─────────────────────────────────────────────────────
/// Callback de progression pour une zone en cours de téléchargement.
typedef ZoneProgressCallback =
    void Function({required double progress, required String layerLabel});

/// Callback d'erreur pour une zone en cours de téléchargement.
typedef ZoneErrorCallback = void Function(String message);

// ─── Raisons d'interruption d'un téléchargement ────────────────────────────
enum DownloadCancelReason { none, user, watchdog, tileCeiling }

enum LayerOutcome { ok, partial, networkFailure, noCoverage, interrupted }

// ─── État interne d'une zone ───────────────────────────────────────────────
class _ZoneState {
  bool isCancelled = false;
  bool isPaused = false;
  DownloadCancelReason cancelReason = DownloadCancelReason.none;
  Completer<void>? allDone;
  FMTCStore? activeStore;
  String? activeInstanceId;
}

class ZoneProgressEvent {
  final String zoneUuid;
  final double progress;
  final String layerLabel;
  const ZoneProgressEvent({
    required this.zoneUuid,
    required this.progress,
    required this.layerLabel,
  });
}

class ZoneErrorEvent {
  final String zoneUuid;
  final String message;
  const ZoneErrorEvent({required this.zoneUuid, required this.message});
}

// ─── Service principal ─────────────────────────────────────────────────────
class ZoneDownloadService {
  ZoneDownloadService({
    MapLayerRepository? repository,
    LayerDownloader downloader = const FmtcLayerDownloader(),
  }) : _injectedRepository = repository,
       _downloader = downloader;

  final MapLayerRepository? _injectedRepository;
  final LayerDownloader _downloader;
  static final MapLayerRepository _noopFallback = _NoopRepo();
  MapLayerRepository get _repository =>
      _injectedRepository ?? OfflineMapRepository.instance ?? _noopFallback;
  bool get hasRealRepository =>
      _injectedRepository != null || OfflineMapRepository.instance != null;

  final Map<String, _ZoneState> _zones = {};
  final Map<String, int> _runCounters = {};
  final Map<String, String> _previousInstanceIds = {};

  final StreamController<ZoneProgressEvent> _progressController =
      StreamController<ZoneProgressEvent>.broadcast();
  Stream<ZoneProgressEvent> get progressStream => _progressController.stream;

  final StreamController<ZoneErrorEvent> _errorController =
      StreamController<ZoneErrorEvent>.broadcast();
  Stream<ZoneErrorEvent> get errorStream => _errorController.stream;

  final StreamController<String> _completionController =
      StreamController<String>.broadcast();

  Stream<String> get completionStream => _completionController.stream;

  static ZoneDownloadService? _instance;
  static ZoneDownloadService get instance =>
      _instance ??= ZoneDownloadService();

  @visibleForTesting
  static void overrideInstanceForTest(ZoneDownloadService? service) =>
      _instance = service;

  bool isDownloading(String zoneUuid) => _zones.containsKey(zoneUuid);
  int get activeCount => _zones.length;

  Future<void> downloadZone({
    required OfflineMap map,
    required List<OfflineMapLayer> layers,
    LatLngBounds? zoneBounds,
    ZoneProgressCallback? onProgress,
    ZoneErrorCallback? onError,
  }) async {
    if (!hasRealRepository) {
      const msg = 'Base de donnees indisponible : telechargement impossible';
      onError?.call(msg);
      if (!_errorController.isClosed) {
        _errorController.add(ZoneErrorEvent(zoneUuid: map.uuid, message: msg));
      }
      if (!_completionController.isClosed) {
        _completionController.add(map.uuid);
      }
      return;
    }
    final zoneUuid = map.uuid;
    final runCount = _runCounters[zoneUuid] ?? 0;
    if (_zones.containsKey(zoneUuid)) return;
    final state = _zones[zoneUuid] = _ZoneState()..allDone = Completer();
    _runCounters[zoneUuid] = runCount + 1;
    bool initializationFailed = false;
    try {
      map.status = OfflineMapStatus.downloading;
      map.lastError = null;
      _repository.save(map);

      final sortedLayers = _sortLayersByPriority(layers);
      for (final layer in sortedLayers) {
        if (layer.layerType == LayerType.lidarLitto3d && layer.minZoom < 11) {
          layer.minZoom = 11;
        }
        layer.estimatedTileCount = 0;
        layer.downloadedTileCount = 0;
        layer.downloadStatus = LayerDownloadStatus.downloading;
        _repository.saveLayer(map, layer);
      }
      final bounds =
          zoneBounds ??
          LatLngBounds(
            LatLng(map.southLat, map.westLng),
            LatLng(map.northLat, map.eastLng),
          );
      final routingBounds = zoneBounds;

      final polygonPoints = map.polygonPoints;

      final layerResults = <String, LayerDownloadResult>{};
      for (var i = 0; i < sortedLayers.length; i++) {
        if (state.isCancelled) break;
        final layer = sortedLayers[i];
        final layerLabel = _layerLabel(layer);
        final layerKey = _layerKey(layer);
        final storeName = _fmtcStoreName(
          map.uuid,
          layer.layerType,
          layer.lidarLayerId,
        );
        final store = FMTCStore(storeName);

        final instanceId = '${map.uuid}#$runCount#$layerKey';
        final preCancelKey = '${map.uuid}|$storeName';
        final preCancelId = _previousInstanceIds[preCancelKey];
        _previousInstanceIds[preCancelKey] = instanceId;
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
            polygon: polygonPoints,
            expectPolygon: map.hasPolygonData,
            onProgress: (layerProgress) {
              if (sortedLayers.isNotEmpty) {
                final globalProgress =
                    (i + layerProgress) / sortedLayers.length;
                onProgress?.call(
                  progress: (i + layerProgress) / sortedLayers.length,
                  layerLabel: layerLabel,
                );
                if (!_progressController.isClosed) {
                  _progressController.add(
                    ZoneProgressEvent(
                      zoneUuid: map.uuid,
                      progress: globalProgress,
                      layerLabel: layerLabel,
                    ),
                  );
                }
              }
            },
            preCancelInstanceId: preCancelId,
            preCancelStore: store,
          );
        } catch (e) {
          layer.downloadStatus = LayerDownloadStatus.failed;
          layer.estimatedTileCount = 0;
          layer.downloadedTileCount = 0;
          _repository.saveLayer(map, layer);

          // ✅ Classification intelligente de l'erreur
          final msg = _classifyError(e, layerLabel);

          onError?.call(msg);
          if (!_errorController.isClosed) {
            _errorController.add(
              ZoneErrorEvent(zoneUuid: map.uuid, message: msg),
            );
          }

          if (kVerboseZoneDownload) {
            debugPrint(
              '[ZoneDownload] ${map.uuid} couche $layerLabel: '
              'type=${e.runtimeType}, msg=$msg',
            );
          }

          continue;
        }

        if (state.cancelReason == DownloadCancelReason.none) {
          switch (result.interruptReason) {
            case DownloadInterruptReason.watchdog:
              state.cancelReason = DownloadCancelReason.watchdog;
              state.isCancelled = true;
              break;
            case DownloadInterruptReason.tileCeiling:
              state.cancelReason = DownloadCancelReason.tileCeiling;
              state.isCancelled = true;
              break;
            case DownloadInterruptReason.none:
              break;
          }
        }

        final outcome = assessLayerResult(result, state.cancelReason);
        layer.estimatedTileCount = result.estimatedTileCount;
        layer.downloadedTileCount = result.downloadedTileCount;
        switch (outcome) {
          case LayerOutcome.ok:
          case LayerOutcome.partial:
            layer.downloadStatus = LayerDownloadStatus.completed;
            break;
          case LayerOutcome.noCoverage:
            layer.downloadStatus = LayerDownloadStatus.skipped;
            break;
          case LayerOutcome.networkFailure:
          case LayerOutcome.interrupted:
            layer.downloadStatus = LayerDownloadStatus.failed;
            break;
        }
        _repository.saveLayer(map, layer);
        layerResults[layerKey] = result;
        if (state.isCancelled) break;
      }
      _finalizeZone(map, state, layers, layerResults, onError);
    } catch (e) {
      initializationFailed = true;
      final msg = 'Erreur initialisation zone: $e';
      onError?.call(msg);
      if (!_errorController.isClosed) {
        _errorController.add(ZoneErrorEvent(zoneUuid: map.uuid, message: msg));
      }
    } finally {
      if (initializationFailed) {
        map.status = OfflineMapStatus.failed;
        _repository.save(map);
      }
    }
    state.allDone?.complete();

    _zones.remove(map.uuid);
    if (!_completionController.isClosed) {
      _completionController.add(map.uuid);
    }
  }

  /// Classifie une exception et retourne un message utilisateur approprié.
  String _classifyError(Object error, String layerLabel) {
    final errorType = error.runtimeType.toString();

    // Erreurs réseau
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException ||
        errorType.contains('SocketException') ||
        errorType.contains('TimeoutException') ||
        errorType.contains('HttpException') ||
        errorType.contains('ClientException')) {
      return 'Erreur réseau couche $layerLabel: ${error.toString()}';
    }

    // Erreurs de stockage / système de fichiers
    if (error is FileSystemException ||
        errorType.contains('FileSystemException') ||
        errorType.contains('PathAccessException')) {
      return 'Erreur stockage couche $layerLabel: espace disque ou permissions';
    }

    // Erreurs de programmation / configuration
    if (error is StateError ||
        error is ArgumentError ||
        errorType.contains('StateError') ||
        errorType.contains('ArgumentError')) {
      return 'Erreur interne couche $layerLabel: ${error.toString()}';
    }

    // Erreurs FMTC spécifiques
    if (errorType.contains('FMTC') ||
        errorType.contains('StoreException') ||
        errorType.contains('IsolateException')) {
      return 'Erreur cache couche $layerLabel: ${error.toString()}';
    }

    // Erreur générique
    return 'Erreur inattendue couche $layerLabel: ${error.toString()}';
  }

  LayerOutcome assessLayerResult(
    LayerDownloadResult r,
    DownloadCancelReason cancelReason,
  ) {
    if (cancelReason != DownloadCancelReason.none) {
      return r.downloadedTileCount > 0
          ? LayerOutcome.partial
          : LayerOutcome.interrupted;
    }
    if (r.downloadedTileCount == 0) {
      if (r.failedTileCount == 0) {
        if (!r.successful) return LayerOutcome.networkFailure;
        return LayerOutcome.noCoverage;
      }
      return LayerOutcome.networkFailure;
    }
    if (!r.successful) {
      return LayerOutcome.networkFailure;
    }
    if (r.failedTileCount > 0) return LayerOutcome.partial;
    return LayerOutcome.ok;
  }

  @visibleForTesting
  OfflineMapStatus finalStatus(
    OfflineMap map,
    List<LayerOutcome> outcomes,
    DownloadCancelReason reason,
  ) {
    final hasOkOrPartial =
        outcomes.contains(LayerOutcome.ok) ||
        outcomes.contains(LayerOutcome.partial);
    switch (reason) {
      case DownloadCancelReason.user:
        map.lastError = 'Annulé par l\'utilisateur';
        return hasOkOrPartial
            ? OfflineMapStatus.partial
            : OfflineMapStatus.notStarted;
      case DownloadCancelReason.watchdog:
        map.lastError = 'Interrompu : téléchargement gelé (watchdog)';
        return hasOkOrPartial
            ? OfflineMapStatus.partial
            : OfflineMapStatus.failed;
      case DownloadCancelReason.tileCeiling:
        map.lastError =
            'Interrompu : plafond de tuiles dépassé (zone trop grande)';
        return hasOkOrPartial
            ? OfflineMapStatus.partial
            : OfflineMapStatus.failed;
      case DownloadCancelReason.none:
        break;
    }
    if (outcomes.isEmpty) {
      map.lastError = 'Aucune couche à télécharger';
      return OfflineMapStatus.failed;
    }
    if (outcomes.every((o) => o == LayerOutcome.ok)) {
      map.lastError = null;
      return OfflineMapStatus.ready;
    }
    if (outcomes.contains(LayerOutcome.networkFailure)) {
      final n = outcomes.where((o) => o == LayerOutcome.networkFailure).length;
      if (map.hasPolygonData && map.polygonPoints == null) {
        map.lastError =
            'Données polygone corrompues : téléchargement impossible';
      } else {
        map.lastError = 'Échecs réseau sur $n couche(s)';
      }
      return hasOkOrPartial
          ? OfflineMapStatus.partial
          : OfflineMapStatus.failed;
    }
    final noCov = outcomes.where((o) => o == LayerOutcome.noCoverage).length;
    if (noCov > 0) {
      // Si toutes les couches sont noCoverage sans aucune donnée utilisable
      if (!hasOkOrPartial && noCov == outcomes.length) {
        map.lastError = 'Zone sans couverture SHOM/LiDAR';
        return OfflineMapStatus.partial;
      }
      // Mixte avec des échecs/interruptions mais aucune donnée utilisable
      if (!hasOkOrPartial) {
        map.lastError =
            '$noCov couche(s) sans couverture, aucune donnée utilisable';
        return OfflineMapStatus.failed;
      }
      // Mélange de couches réussies et de couches sans couverture
      map.lastError = '$noCov couche(s) sans couverture sur cette zone';
      return OfflineMapStatus.partial;
    }
    map.lastError = null;
    return hasOkOrPartial ? OfflineMapStatus.partial : OfflineMapStatus.failed;
  }

  void _finalizeZone(
    OfflineMap map,
    _ZoneState state,
    List<OfflineMapLayer> layers,
    Map<String, LayerDownloadResult> layerResults, [
    ZoneErrorCallback? onError,
  ]) {
    final outcomes = layers.map((layer) {
      final result = layerResults[_layerKey(layer)];
      if (result != null) {
        return assessLayerResult(result, state.cancelReason);
      }
      if (layer.downloadStatus == LayerDownloadStatus.completed) {
        return LayerOutcome.ok;
      }
      if (layer.downloadStatus == LayerDownloadStatus.skipped) {
        return LayerOutcome.noCoverage;
      }
      if (state.cancelReason != DownloadCancelReason.none) {
        return LayerOutcome.interrupted;
      }
      return LayerOutcome.networkFailure;
    }).toList();
    final status = finalStatus(map, outcomes, state.cancelReason);
    map.status = status;
    if (status == OfflineMapStatus.ready ||
        status == OfflineMapStatus.partial) {
      map.completedAt = DateTime.now();
    }
    _repository.save(map);
    if (map.lastError != null && onError != null) {
      onError(map.lastError!);
    }
    if (kVerboseZoneDownload) {
      debugPrint(
        '[ZoneDownload] ${map.uuid}: status=$status, reason=${state.cancelReason.name}, '
        'outcomes=${outcomes.map((o) => o.name).toList()}, lastError="${map.lastError}"',
      );
    }
    NegativeFilteringImageProvider.clearStoreNamesCache();
    MapTileCacheService.invalidateZoneSizeCache(map.uuid);
  }

  Future<void> cancelDownload(String zoneUuid) async {
    final state = _zones[zoneUuid];
    if (state == null) return;
    state.isCancelled = true;
    if (state.cancelReason == DownloadCancelReason.none) {
      state.cancelReason = DownloadCancelReason.user;
    }
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;
    if (store != null && instanceId != null) {
      await _downloader.cancel(zoneUuid, store, instanceId);
    }
  }

  Future<bool> cancelAndAwaitEnd(
    String zoneUuid, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await cancelDownload(zoneUuid);
    return await waitForCompletion(zoneUuid, timeout: timeout);
  }

  Future<bool> forceStopDownload(
    String zoneUuid, {
    Duration finalTimeout = const Duration(seconds: 10),
  }) async {
    // Déjà terminé : rien à forcer.
    if (!_zones.containsKey(zoneUuid)) return true;

    // Appels cancel() répétés : FMTC peut ignorer le premier appel
    // si le worker isolate est occupé ou bloqué.
    for (var i = 0; i < 3; i++) {
      await cancelDownload(zoneUuid);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!isDownloading(zoneUuid)) return true;
    }

    // Dernière tentative : attente courte de la complétion réelle.
    await waitForCompletion(zoneUuid, timeout: finalTimeout, maxRetries: 1);
    return !isDownloading(zoneUuid);
  }

  bool pauseDownload(String zoneUuid) {
    final state = _zones[zoneUuid];
    if (state == null) return false;
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;
    if (store == null || instanceId == null) return false;
    if (kVerboseZoneDownload) {
      debugPrint('[ZoneDownload] PAUSE $zoneUuid instance=$instanceId');
    }
    final success = _downloader.pause(zoneUuid, store, instanceId);
    if (success) {
      state.isPaused = true;
    } else {
      if (kVerboseZoneDownload) {
        debugPrint(
          '[ZoneDownload] PAUSE échouée pour $zoneUuid - état non modifié',
        );
      }
    }
    return success;
  }

  bool resumeDownload(String zoneUuid) {
    final state = _zones[zoneUuid];
    if (state == null) return false;
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;
    if (store == null || instanceId == null) return false;
    if (kVerboseZoneDownload) {
      debugPrint('[ZoneDownload] RESUME $zoneUuid instance=$instanceId');
    }
    final success = _downloader.resume(zoneUuid, store, instanceId);
    if (success) {
      state.isPaused = false;
    } else {
      if (kVerboseZoneDownload) {
        debugPrint(
          '[ZoneDownload] RESUME échouée pour $zoneUuid - état non modifié',
        );
      }
    }
    return success;
  }

  bool isPaused(String zoneUuid) => _zones[zoneUuid]?.isPaused ?? false;

  Future<bool> waitForCompletion(
    String zoneUuid, {
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
  }) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final state = _zones[zoneUuid];
      final allDone = state?.allDone;

      // Zone déjà terminée ou jamais existé
      if (allDone == null) return true;

      try {
        await allDone.future.timeout(timeout);
        // Succès : le téléchargement est terminé
        return true;
      } on TimeoutException {
        if (kVerboseZoneDownload) {
          debugPrint(
            '[ZoneDownload] waitForCompletion: timeout attempt ${attempt + 1}/$maxRetries pour $zoneUuid',
          );
        }

        if (attempt == maxRetries - 1) {
          if (kVerboseZoneDownload) {
            debugPrint(
              '[ZoneDownload] WARNING: waitForCompletion a expiré après '
              '$maxRetries tentatives pour $zoneUuid.',
            );
          }
          return false;
        }

        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return false;
  }

  void clearZoneHistory(String zoneUuid) {
    _runCounters.remove(zoneUuid);
    _previousInstanceIds.removeWhere((key, _) => key.startsWith('$zoneUuid|'));
  }

  // ─── Helpers internes ──────────────────────────────────────────────────────
  String _layerKey(OfflineMapLayer layer) =>
      layer.layerType.name +
      (layer.lidarLayerId != null ? ':${layer.lidarLayerId}' : '');

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

  String _layerUrl(
    LayerType type,
    LatLngBounds? zoneBounds, [
    String? lidarLayerId,
  ]) {
    switch (type) {
      case LayerType.marine50k:
      case LayerType.marine25k:
      case LayerType.marine10k:
        final layer = MarineLayerCatalog.findByLayerType(type);
        if (layer == null) {
          throw StateError('Marine layer not found for type: $type');
        }
        return MarineMapService.clevisuWmtsUrl(layer.wmtsLayerName);

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

  Map<String, String> _layerHeaders(LayerType type) {
    final base = <String, String>{
      'User-Agent':
          '${MapTileCacheService.packageName}/${TileProviderFactory.appVersion} (Flutter Mobile App)',
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

  String _layerLabel(OfflineMapLayer layer) {
    if (layer.layerType == LayerType.lidarLitto3d &&
        layer.lidarLayerId != null) {
      return 'lidarLitto3d:${layer.lidarLayerId}';
    }
    return layer.layerType.name;
  }

  List<OfflineMapLayer> _sortLayersByPriority(List<OfflineMapLayer> layers) {
    final lidarLayers = layers
        .where((l) => l.layerType == LayerType.lidarLitto3d)
        .toList();
    final marineLayers = layers
        .where((l) => l.layerType != LayerType.lidarLitto3d)
        .toList();
    lidarLayers.sort((a, b) {
      final layerA = Litto3DCatalog.findById(a.lidarLayerId ?? '');
      final layerB = Litto3DCatalog.findById(b.lidarLayerId ?? '');
      if (layerA == null || layerB == null) return 0;
      return layerB.sortOrder.compareTo(layerA.sortOrder);
    });
    return [...marineLayers, ...lidarLayers];
  }
}

class _NoopRepo implements MapLayerRepository {
  @override
  OfflineMap? findByUuid(String uuid) => null;
  @override
  OfflineMapLayer? findLayerById(int id) => null;
  @override
  void save(OfflineMap map) {}
  @override
  void saveLayer(OfflineMap map, OfflineMapLayer layer) {}
}
