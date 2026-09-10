import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/io_client.dart';
import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/marine_map_service.dart';

// ─── Repository interface ─────────────────────────────────────────────────────

abstract class MapLayerRepository {
  void save(OfflineMap map);
  void saveLayer(OfflineMap map, OfflineMapLayer layer);
  OfflineMap? findByUuid(String uuid);
  OfflineMapLayer? findLayerById(int id);
}

typedef ZoneProgressCallback =
    void Function({required double progress, required String layerLabel});

typedef ZoneErrorCallback = void Function(String message);

// ─── Download result ─────────────────────────────────────────────────────────

class LayerDownloadResult {
  const LayerDownloadResult({
    required this.downloadedTileCount,
    required this.estimatedTileCount,
    required this.successful,
    this.negativeTileCount = 0,
    this.failedTileCount = 0,
  });
  final int downloadedTileCount;
  final int estimatedTileCount;
  final bool successful;
  final int negativeTileCount;
  final int failedTileCount;
}

// ─── Layer downloader abstraction ────────────────────────────────────────────

abstract class LayerDownloader {
  Future<LayerDownloadResult> downloadLayer({
    required String zoneUuid,
    required FMTCStore store,
    required String instanceId,
    required String urlTemplate,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required Map<String, String> headers,
    required void Function(double progress) onProgress,
    String? preCancelInstanceId,
    FMTCStore? preCancelStore,
  });
  Future<void> cancel(String zoneUuid, FMTCStore store, String instanceId);
  void pause(String zoneUuid, FMTCStore store, String instanceId);
  void resume(String zoneUuid, FMTCStore store, String instanceId);
}

// ─── Tile provider for download (no http.Client — safe for isolate) ───────────

/// Minimal [TileProvider] used exclusively inside a [DownloadableRegion] passed
/// to FMTC's [Isolate.spawn].
///
/// This provider deliberately contains NO [http.Client] instance, avoiding the
/// "unsendable object" crash that occurs when Dart attempts to serialize the
/// entire [DownloadableRegion] into an isolate.
///
/// FMTC's download worker only accesses two properties of the tile provider:
///   - `headers`  — propagated to the worker's own internal HTTP client
///   - `getTileUrl(coords, options)` — used to generate tile URLs
///
/// Both are fully supported by the base [TileProvider] class, so no
/// [FMTCTileProvider] is needed here.  The [FMTCTileProvider] (with its
/// `httpClient` field) must remain on the [TileLayer] used for *display* only;
/// it must never be embedded in a [DownloadableRegion] that crosses an isolate
/// boundary.
class _DownloadOnlyTileProvider extends TileProvider {
  _DownloadOnlyTileProvider({required Map<String, String> headers})
    : super(headers: headers);
}

// ─── FMTC implementation ─────────────────────────────────────────────────────

class FmtcLayerDownloader implements LayerDownloader {
  const FmtcLayerDownloader();

  @override
  Future<LayerDownloadResult> downloadLayer({
    required String zoneUuid,
    required FMTCStore store,
    required String instanceId,
    required String urlTemplate,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required Map<String, String> headers,
    required void Function(double progress) onProgress,
    String? preCancelInstanceId,
    FMTCStore? preCancelStore,
  }) async {
    debugPrint(
      '[DL][$zoneUuid][$instanceId] downloadLayer ENTER store=${store.storeName}',
    );
    debugPrint(
      '[FmtcLayerDownloader] START zone=$zoneUuid store=${store.storeName} '
      'instance=$instanceId url=$urlTemplate zoom=$minZoom-$maxZoom',
    );

    // LOG TEMPORAIRE : informations détaillées pour comparaison offline
    debugPrint(
      '[LIDAR-DL] store=${store.storeName} url=$urlTemplate minZoom=$minZoom maxZoom=$maxZoom',
    );

    final effectiveMaxZoom = maxZoom.clamp(minZoom, 17);

    // Build an IOClient wrapping an HttpClient with the required User-Agent.
    // FMTC uses this for tile downloads; the headers map is also forwarded
    // to FMTCTileProvider so browsing can use the same credentials.
    final tileHttpClient = IOClient(
      HttpClient()
        ..userAgent =
            '${MapTileCacheService.packageName}/1.0 (Flutter Mobile App)',
    );

    debugPrint('[DL][$zoneUuid][$instanceId] store.manage.create START');
    await store.manage.create();
    debugPrint('[DL][$zoneUuid][$instanceId] store.manage.create END');
    final region = RectangleRegion(bounds).toDownloadable(
      minZoom: minZoom,
      maxZoom: effectiveMaxZoom,
      options: TileLayer(
        urlTemplate: urlTemplate,
        userAgentPackageName: MapTileCacheService.packageName,
        // Use a minimal sendable TileProvider: this DownloadableRegion is
        // serialized into the FMTC worker isolate via Isolate.spawn, so we
        // must NOT embed MapTileCacheService._httpClient (a Client wrapping
        // HttpClient with live _HttpClientConnection instances), which is
        // unsendable and would crash the spawn.
        // FMTC's worker only needs `headers` and `getTileUrl`, both supported
        // by the base TileProvider class.
        tileProvider: _DownloadOnlyTileProvider(headers: headers),
      ),
    );

    if (preCancelInstanceId != null && preCancelStore != null) {
      try {
        await preCancelStore.download.cancel(instanceId: preCancelInstanceId);
        debugPrint(
          '[FmtcLayerDownloader] Pre-cancelled orphan instance $preCancelInstanceId.',
        );
      } catch (e) {
        debugPrint('[FmtcLayerDownloader] Pre-cancel failed (non-fatal): $e');
      }
    }

    // Emit an immediate 0% progress event so the UI refreshes right away
    // instead of staying stuck at "0 / N tiles" before the stream fires.
    onProgress(0.0);

    final ctrl = StreamController<DownloadProgress>.broadcast();
    late final StreamSubscription<DownloadProgress> bridgeSub;
    debugPrint(
      '[DL][$zoneUuid][$instanceId] startForeground START store=${store.storeName}',
    );
    final fgReturn = store.download.startForeground(
      region: region,
      instanceId: instanceId,
      disableRecovery: false,
      parallelThreads: 2,
      maxBufferLength: 200,
      retryFailedRequestTiles: true,
      maxReportInterval: const Duration(milliseconds: 500),
    );
    debugPrint('[DL][$zoneUuid][$instanceId] startForeground RETURNED');
    bridgeSub = fgReturn.downloadProgress.listen(
      ctrl.add,
      onError: (Object e, StackTrace st) {
        debugPrint('[STREAM][$zoneUuid][$instanceId] ERROR $e');
        ctrl.addError(e);
      },
      onDone: () {
        debugPrint('[STREAM][$zoneUuid][$instanceId] DONE');
        ctrl.close();
      },
    );
    ctrl.onCancel = () {
      debugPrint(
        '[CTRL][$zoneUuid][$instanceId] onCancel → bridgeSub.cancel()',
      );
      bridgeSub.cancel();
    };

    var maxTiles = 0;
    var successful = 0;
    var failed = 0;
    var negative = 0;
    var lastEventAt = DateTime.now();
    Timer? watchdog;

    try {
      watchdog = Timer.periodic(const Duration(seconds: 30), (t) {
        if (DateTime.now().difference(lastEventAt) > _stallWindow) {
          t.cancel();
          debugPrint(
            '[FmtcLayerDownloader] WATCHDOG stall detected '
            '(${_stallWindow.inSeconds}s without events) - cancelling instance $instanceId.',
          );
          store.download.cancel(instanceId: instanceId);
        }
      });

      debugPrint('[DL][$zoneUuid][$instanceId] await-for ENTER');
      await for (final p in ctrl.stream) {
        maxTiles = p.maxTilesCount;
        successful = p.successfulTilesCount;
        negative = p.negativeResponseTilesCount;
        failed = p.failedRequestTilesCount;
        lastEventAt = DateTime.now();
        debugPrint(
          '[DL][$zoneUuid][$instanceId] STREAM EVENT maxTiles=$maxTiles successful=$successful attempted=${p.attemptedTilesCount}',
        );
        if (maxTiles > 0) {
          final progress = (p.attemptedTilesCount / maxTiles).clamp(0.0, 1.0);
          onProgress(progress);
          if (p.attemptedTilesCount % 50 == 0 || progress >= 1.0) {
            debugPrint(
              '[FmtcLayerDownloader] Progress: '
              '$successful/$maxTiles tiles (${(progress * 100).toStringAsFixed(1)}%)',
            );
          }
          // LOG TEMPORAIRE : logguer quelques tiles spécifiques pour comparaison
          if (p.attemptedTilesCount == 1 ||
              p.attemptedTilesCount == 10 ||
              p.attemptedTilesCount == 50) {
            debugPrint(
              '[LIDAR-DL-TILE] store=${store.storeName} url=$urlTemplate zoom=$minZoom-$maxZoom '
              'attemptedTileCount=${p.attemptedTilesCount}',
            );
          }
        }
        if (maxTiles > _maxTileCountCeiling) {
          debugPrint(
            '[FmtcLayerDownloader] Tile count $maxTiles > ceiling '
            '$_maxTileCountCeiling - aborting.',
          );
          store.download.cancel(instanceId: instanceId);
        }
      }
      debugPrint('[DL][$zoneUuid][$instanceId] await-for EXIT (stream closed)');
    } catch (e, st) {
      debugPrint('[FmtcLayerDownloader] Isolate stream error: $e\n$st');
      rethrow;
    } finally {
      watchdog?.cancel();
      try {
        try {
          tileHttpClient.close();
        } catch (_) {}
      } catch (_) {}
      await ctrl.close();
      debugPrint(
        '[FmtcLayerDownloader] DONE zone=$zoneUuid '
        'successful=$successful maxTiles=$maxTiles failed=$failed',
      );
    }

    debugPrint(
      '[DL][$zoneUuid][$instanceId] downloadLayer RETURN maxTiles=$maxTiles successful=$successful',
    );
    return _assessResult(maxTiles, successful, failed, negative);
  }

  LayerDownloadResult _assessResult(
    int maxTiles,
    int successful,
    int failed,
    int negative,
  ) {
    final total = maxTiles > 0 ? maxTiles : (successful + failed + negative);
    if (total == 0) {
      return const LayerDownloadResult(
        downloadedTileCount: 0,
        estimatedTileCount: 0,
        successful: false,
      );
    }
    final negativeRatio = negative / total;
    final failedRatio = failed / total;
    final ok =
        successful > 0 &&
        negativeRatio <= _negativeTolerance &&
        failedRatio <= _networkFailureTolerance;
    if (!ok) {
      debugPrint(
        '[FmtcLayerDownloader] Layer assessed FAILED: '
        'successful=$successful negativeRatio=${negativeRatio.toStringAsFixed(3)} '
        'failedRatio=${failedRatio.toStringAsFixed(3)} total=$total',
      );
    }
    return LayerDownloadResult(
      downloadedTileCount: successful,
      estimatedTileCount: total,
      successful: ok,
      negativeTileCount: negative,
      failedTileCount: failed,
    );
  }

  static const int _maxTileCountCeiling = 12000;
  static const double _negativeTolerance = 0.20;
  static const double _networkFailureTolerance = 0.15;
  static const Duration _stallWindow = Duration(minutes: 15);

  @override
  Future<void> cancel(
    String zoneUuid,
    FMTCStore store,
    String instanceId,
  ) async {
    debugPrint('[CANCEL][$zoneUuid][$instanceId] ENTER');
    try {
      debugPrint(
        '[CANCEL][$zoneUuid][$instanceId] store.download.cancel START',
      );
      await store.download.cancel(instanceId: instanceId);
      debugPrint(
        '[CANCEL][$zoneUuid][$instanceId] store.download.cancel RETURNED',
      );
      debugPrint(
        '[FmtcLayerDownloader] Cancelled zone=$zoneUuid instance=$instanceId',
      );
    } catch (e) {
      debugPrint(
        '[CANCEL][$zoneUuid][$instanceId] store.download.cancel ERROR $e',
      );
      debugPrint('[FmtcLayerDownloader] cancel error: $e');
    }
    debugPrint('[CANCEL][$zoneUuid][$instanceId] EXIT');
  }

  @override
  void pause(String zoneUuid, FMTCStore store, String instanceId) {
    store.download.pause(instanceId: instanceId);
    debugPrint(
      '[FmtcLayerDownloader] Paused zone=$zoneUuid instance=$instanceId',
    );
  }

  @override
  void resume(String zoneUuid, FMTCStore store, String instanceId) {
    store.download.resume(instanceId: instanceId);
    debugPrint(
      '[FmtcLayerDownloader] Resumed zone=$zoneUuid instance=$instanceId',
    );
  }
}

// ─── Zone download service ───────────────────────────────────────────────────

class _ZoneState {
  bool isCancelled = false;
  int completedLayers = 0;
  int failedLayers = 0;
  Completer<void>? allDone;
  FMTCStore? activeStore;
  String? activeInstanceId;
}

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

  MapLayerRepository get repository => _repository;
  bool isDownloading(String zoneUuid) => _zones.containsKey(zoneUuid);
  int get activeCount => _zones.length;

  Future<void> downloadZone({
    required OfflineMap map,
    required List<OfflineMapLayer> layers,
    LatLngBounds? zoneBounds,
    ZoneProgressCallback? onProgress,
    ZoneErrorCallback? onError,
  }) async {
    final zoneUuid = map.uuid;
    final runCount = _runCounters[zoneUuid] ?? 0;
    debugPrint(
      '[ZONE][$zoneUuid] START run=$runCount _zones.keys=${_zones.keys.toList()}',
    );
    if (_zones.containsKey(zoneUuid)) return;
    final state = _zones[zoneUuid] = _ZoneState()..allDone = Completer();
    _runCounters[zoneUuid] = runCount + 1;
    final preCancelId = _previousInstanceIds[zoneUuid];
    bool initializationFailed = false;

    try {
      map.status = OfflineMapStatus.downloading;
      _repository.save(map);

      for (final layer in layers) {
        debugPrint(
          '[ZONE][$zoneUuid] layer START ${layer.layerType.name}'
          '${layer.lidarLayerId != null ? ' (lidarLayerId=${layer.lidarLayerId})' : ''}',
        );
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

      // INSTRUMENTATION TEMPORAIRE : stockage par couche pour le résumé.
      final layerResults = <LayerType, LayerDownloadResult>{};

      for (var i = 0; i < layers.length; i++) {
        if (state.isCancelled) break;

        final layer = layers[i];
        final layerLabel = _layerLabel(layer);
        debugPrint(
          '[ZoneDownloadService] Layer $i+1/${layers.length} ($layerLabel) '
          'for zone ${map.uuid}',
        );

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
        } catch (e, st) {
          debugPrint('[ZoneDownloadService] Layer $layerLabel threw $e\n$st');
          state.failedLayers++;
          layer.downloadStatus = LayerDownloadStatus.failed;
          layer.estimatedTileCount = 0;
          layer.downloadedTileCount = 0;
          _repository.saveLayer(map, layer);
          onError?.call('Erreur reseau couche $layerLabel: $e');
          continue; // skip to next layer instead of aborting the whole zone
        }

        if (state.isCancelled) break;

        layer.estimatedTileCount = result.estimatedTileCount;
        layer.downloadedTileCount = result.downloadedTileCount;
        if (result.successful) {
          state.completedLayers++;
          layer.downloadStatus = LayerDownloadStatus.completed;
          debugPrint(
            '[ZONE][$zoneUuid] layer END ${layer.layerType.name} completed: '
            '${result.downloadedTileCount}/${result.estimatedTileCount} tiles',
          );
          debugPrint(
            '[ZoneDownloadService] Layer $layerLabel completed: '
            '${result.downloadedTileCount}/${result.estimatedTileCount} tiles',
          );
        } else {
          state.failedLayers++;
          layer.downloadStatus = LayerDownloadStatus.failed;
          debugPrint(
            '[ZONE][$zoneUuid] layer END ${layer.layerType.name} FAILED',
          );
          debugPrint(
            '[ZoneDownloadService] Layer $layerLabel FAILED: '
            '${result.downloadedTileCount}/${result.estimatedTileCount} tiles',
          );
        }
        _repository.saveLayer(map, layer);

        // INSTRUMENTATION TEMPORAIRE : log par couche.
        debugPrint(
          '[OFFLINE-DL] zone=${map.uuid} layer=$layerLabel '
          'requested=${result.estimatedTileCount} '
          'successful=${result.downloadedTileCount} '
          'negative=${result.negativeTileCount} '
          'failed=${result.failedTileCount}',
        );

        // Stockage pour le résumé de zone.
        layerResults[layer.layerType] = result;
      }

      final lastInstance = state.activeInstanceId;
      if (lastInstance != null) {
        _previousInstanceIds[map.uuid] = lastInstance;
      }
      debugPrint('[ZONE][$zoneUuid] FINALIZE instance=$lastInstance');

      // INSTRUMENTATION TEMPORAIRE : résumé de zone.
      debugPrint(
        '[OFFLINE-DL] ZONE SUMMARY uuid=${map.uuid} layers=${layers.length}',
      );

      for (final entry in layerResults.entries) {
        debugPrint(
          '[OFFLINE-DL]   ${entry.key} requested=${entry.value.estimatedTileCount} '
          'successful=${entry.value.downloadedTileCount} '
          'negative=${entry.value.negativeTileCount} '
          'failed=${entry.value.failedTileCount}',
        );
      }

      var totalReq = 0;
      var totalOk = 0;
      var totalNeg = 0;
      var totalFail = 0;
      for (final r in layerResults.values) {
        totalReq += r.estimatedTileCount;
        totalOk += r.downloadedTileCount;
        totalNeg += r.negativeTileCount;
        totalFail += r.failedTileCount;
      }

      debugPrint(
        '[OFFLINE-DL]   TOTAL requested=$totalReq successful=$totalOk '
        'negative=$totalNeg failed=$totalFail',
      );

      _finalizeZone(map, state, layers, onError);
      debugPrint('[ZONE][$zoneUuid] FINALIZE DONE');
    } catch (e, st) {
      initializationFailed = true;
      final msg = 'Erreur initialisation zone: $e';
      debugPrint('[ZoneDownloadService] Zone ${map.uuid} error: $e\n$st');
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
      debugPrint('[ZONE][$map.uuid] _zones REMOVE');
      _zones.remove(map.uuid);
    }
    debugPrint('[ZONE][$map.uuid] EXIT _zones.keys=${_zones.keys.toList()}');
  }

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
  }

  Future<void> cancelDownload(String zoneUuid) async {
    debugPrint(
      '[ZONE][$zoneUuid] cancelDownload ENTER _zones.keys=${_zones.keys.toList()}',
    );
    final state = _zones[zoneUuid];
    if (state == null) {
      debugPrint('[ZONE][$zoneUuid] cancelDownload state=null EXIT');
      return;
    }
    state.isCancelled = true;
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;
    debugPrint(
      '[ZONE][$zoneUuid] cancelDownload store=$store instanceId=$instanceId',
    );
    if (store != null && instanceId != null) {
      await _downloader.cancel(zoneUuid, store, instanceId);
    }
    debugPrint('[ZONE][$zoneUuid] cancelDownload EXIT');
  }

  void pauseDownload(String zoneUuid) {
    final state = _zones[zoneUuid];
    if (state == null) return;
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;
    if (store != null && instanceId != null) {
      _downloader.pause(zoneUuid, store, instanceId);
    }
  }

  void resumeDownload(String zoneUuid) {
    debugPrint(
      '[ZONE][$zoneUuid] resumeDownload ENTER _zones.keys=${_zones.keys.toList()}',
    );
    final state = _zones[zoneUuid];
    if (state == null) {
      debugPrint('[ZONE][$zoneUuid] resumeDownload state=null EXIT');
      return;
    }
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;
    debugPrint(
      '[ZONE][$zoneUuid] resumeDownload store=$store instanceId=$instanceId',
    );
    if (store != null && instanceId != null) {
      _downloader.resume(zoneUuid, store, instanceId);
    }
  }

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
        // Nouveau : un store par campagne LiDAR
        if (lidarLayerId != null) {
          return 'lidar_zone_${zoneUuid}_$lidarLayerId';
        }
        // Fallback : anciens layers sans lidarLayerId
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
        return MarineMapService.clevisuWmtsUrl('RASTER_MARINE_50_WMTS_3857');
      case LayerType.marine25k:
        return MarineMapService.clevisuWmtsUrl('RASTER_MARINE_25_WMTS_3857');
      case LayerType.marine10k:
        return MarineMapService.clevisuWmtsUrl('RASTER_MARINE_10_WMTS_3857');
      case LayerType.lidarLitto3d:
        // Nouveau : si lidarLayerId est fourni, l'utiliser directement
        if (lidarLayerId != null) {
          final layer = Litto3DCatalog.findById(lidarLayerId);
          if (layer != null) {
            return MarineMapService.inspireWmtsUrl(layer.wmtsLayerName);
          }
          debugPrint(
            '[ZoneDownloadService] WARNING: lidarLayerId=$lidarLayerId not found in catalog, falling back.',
          );
        }
        // Fallback : comportement actuel pour anciens layers sans lidarLayerId
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

  String _layerLabel(OfflineMapLayer layer) {
    if (layer.layerType == LayerType.lidarLitto3d &&
        layer.lidarLayerId != null) {
      return 'lidarLitto3d:${layer.lidarLayerId}';
    }
    return layer.layerType.name;
  }
}
