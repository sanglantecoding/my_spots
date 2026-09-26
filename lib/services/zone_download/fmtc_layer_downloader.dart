import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/zone_download/layer_download_result.dart';

/// Logs de debugging downloader FMTC. Laisser à false.
const bool kVerboseDownloader = false;

// ─── Callbacks & interface abstraite ────────────────────────────────────────

/// Callback de progression pour une couche en cours de téléchargement.
typedef LayerProgressCallback = void Function(double progress);

/// Interface abstraite pour le téléchargement d'une couche.
///
/// Permet de substituer [FmtcLayerDownloader] par un mock en tests unitaires.
abstract class LayerDownloader {
  /// Télécharge une couche et retourne le résultat de l'évaluation.
  Future<LayerDownloadResult> downloadLayer({
    required String zoneUuid,
    required FMTCStore store,
    required String instanceId,
    required String urlTemplate,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required Map<String, String> headers,
    required LayerProgressCallback onProgress,
    String? preCancelInstanceId,
    FMTCStore? preCancelStore,
  });

  /// Annule un téléchargement en cours.
  Future<void> cancel(String zoneUuid, FMTCStore store, String instanceId);

  /// Met en pause un téléchargement en cours.
  bool pause(String zoneUuid, FMTCStore store, String instanceId);

  /// Reprend un téléchargement précédemment mis en pause.
  bool resume(String zoneUuid, FMTCStore store, String instanceId);
}

// ─── TileProvider minimal pour isolate FMTC ─────────────────────────────────

/// [TileProvider] minimal utilisé exclusivement dans un [DownloadableRegion]
/// passé à [Isolate.spawn] de FMTC.
///
/// Ce provider ne contient **aucun** [http.Client] (qui n'est pas sérialisable
/// vers un isolate). FMTC n'utilise que `headers` et `getTileUrl()` côté
/// worker, tous deux supportés par la classe de base [TileProvider].
class _DownloadOnlyTileProvider extends TileProvider {
  _DownloadOnlyTileProvider({required Map<String, String> headers})
    : super(headers: headers);
}

// ─── Implémentation FMTC ────────────────────────────────────────────────────

/// Implémentation de [LayerDownloader] utilisant FMTC (Flutter Map Tile Caching).
///
/// Gère le téléchargement en foreground via [FMTCStore.download.startForeground],
/// avec un watchdog anti-stall et une évaluation finale du résultat.
class FmtcLayerDownloader implements LayerDownloader {
  /// Instances actuellement en cours de téléchargement.
  /// Utilisé pour valider que pause/resume sont appelés sur des instances valides.
  static final Set<String> _activeInstances = {};

  /// Instances actuellement en pause : le watchdog ne doit PAS les
  /// considérer comme gelées (une pause n'est pas un stall).
  static final Set<String> _pausedInstances = {};

  const FmtcLayerDownloader();

  /// Nettoie les sets de tracking (réservé aux tests).
  @visibleForTesting
  static void clearTrackingSets() {
    _activeInstances.clear();
    _pausedInstances.clear();
  }

  /// Retourne true si l'instance est marquée comme paused (réservé aux tests).
  @visibleForTesting
  static bool isPaused(String instanceId) =>
      _pausedInstances.contains(instanceId);

  /// Ajoute manuellement une instance aux actifs (réservé aux tests).
  @visibleForTesting
  static void addToActive(String instanceId) =>
      _activeInstances.add(instanceId);

  static const int _maxTileCountCeiling =
      25000; //Joue sur la taille max de sauvegarde
  static const double _networkFailureTolerance = 0.15;
  static const Duration _stallWindow = Duration(minutes: 15);

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
    required LayerProgressCallback onProgress,
    String? preCancelInstanceId,
    FMTCStore? preCancelStore,
  }) async {
    // Force minZoom à au moins 8 pour éviter le téléchargement des zooms 0-7
    // (trop de tuiles, inutiles pour la navigation hors-ligne)
    final effectiveMinZoom = minZoom.clamp(8, 17).toInt();
    final effectiveMaxZoom = maxZoom.clamp(effectiveMinZoom, 17).toInt();

    await store.manage.create();

    final region = RectangleRegion(bounds).toDownloadable(
      minZoom: effectiveMinZoom,
      maxZoom: effectiveMaxZoom,
      options: TileLayer(
        urlTemplate: urlTemplate,
        userAgentPackageName: MapTileCacheService.packageName,
        tileProvider: _DownloadOnlyTileProvider(headers: headers),
      ),
    );

    // Annule un éventuel téléchargement orphelin de la même zone.
    if (preCancelInstanceId != null && preCancelStore != null) {
      try {
        await preCancelStore.download.cancel(instanceId: preCancelInstanceId);
      } catch (e) {
        if (kVerboseDownloader) {
          debugPrint('[FmtcLayerDownloader] Pre-cancel failed (non-fatal): $e');
        }
      }
    }

    // Émet immédiatement 0 % pour rafraîchir l'UI.
    onProgress(0.0);

    if (kVerboseDownloader) {
      debugPrint(
        '[FmtcLayerDownloader] START instance=$instanceId zooms=$minZoom..$maxZoom',
      );
    }

    final ctrl = StreamController<DownloadProgress>.broadcast();
    StreamSubscription<DownloadProgress>?
    bridgeSub; // nullable : pas encore posé si startForeground échoue
    Timer? watchdog;

    var maxTiles = 0;
    var successful = 0;
    var negative = 0;
    var failed = 0;
    var lastEventAt = DateTime.now();
    var interruptReason = DownloadInterruptReason.none;

    try {
      final fgReturn = store.download.startForeground(
        region: region,
        instanceId: instanceId,
        disableRecovery: false,
        parallelThreads: 2,
        maxBufferLength: 200,
        retryFailedRequestTiles: true,
        maxReportInterval: const Duration(milliseconds: 500),
      );

      bridgeSub = fgReturn.downloadProgress.listen(
        ctrl.add,
        onError: ctrl.addError,
        onDone: ctrl.close,
      );

      // 👇 Tracking posé UNIQUEMENT une fois le foreground réellement lancé :
      // un échec de startForeground ne laisse donc aucune entrée périmée.
      _activeInstances.add(instanceId);

      watchdog = Timer.periodic(const Duration(seconds: 30), (t) {
        if (_pausedInstances.contains(instanceId)) {
          lastEventAt = DateTime.now(); // pause ≠ stall
          return;
        }
        if (DateTime.now().difference(lastEventAt) > _stallWindow) {
          t.cancel();
          if (kVerboseDownloader) {
            debugPrint(
              '[FmtcLayerDownloader] WATCHDOG stall detected - cancelling instance $instanceId.',
            );
          }
          interruptReason = DownloadInterruptReason.watchdog;
          store.download.cancel(instanceId: instanceId);
        }
      });

      await for (final p in ctrl.stream) {
        maxTiles = p.maxTilesCount;
        successful = p.successfulTilesCount;
        negative = p.negativeResponseTilesCount;
        failed = p.failedRequestTilesCount;
        lastEventAt = DateTime.now();
        if (maxTiles > 0) {
          final progress = (p.attemptedTilesCount / maxTiles).clamp(0.0, 1.0);
          onProgress(progress);
        }
        if (maxTiles > _maxTileCountCeiling) {
          if (kVerboseDownloader) {
            debugPrint(
              '[FmtcLayerDownloader] Tile count $maxTiles > ceiling - aborting.',
            );
          }
          interruptReason = DownloadInterruptReason.tileCeiling;
          store.download.cancel(instanceId: instanceId);
        }
      }
    } catch (e, st) {
      if (kVerboseDownloader) {
        debugPrint('[FmtcLayerDownloader] Isolate stream error: $e$st');
      }
      rethrow;
    } finally {
      // 👇 Nettoyage complet — s'exécute MÊME si startForeground() a échoué.
      _activeInstances.remove(instanceId);
      _pausedInstances.remove(instanceId);
      watchdog?.cancel();
      await bridgeSub?.cancel();
      if (!ctrl.isClosed) {
        await ctrl.close();
      }
      try {
        await store.download.cancel(instanceId: instanceId);
      } catch (e) {
        if (kVerboseDownloader) {
          debugPrint('[FmtcLayerDownloader] cancel error: $e');
        }
      }
    }

    return assessResult(
      maxTiles,
      successful,
      failed,
      negative,
      interruptReason,
    );
  }

  /// Évalue le résultat d'une couche.
  ///
  /// Règles métier VERROUILLÉES par
  /// `test/services/zone_download/assess_result_test.dart` :
  /// - tolérance aux échecs réseau : 15 % du total ;
  /// - **P1** : au moins UNE tuile réelle exigée pour déclarer un succès
  ///   (une couche 100 % négative / 404 ne doit JAMAIS être « réussie ») ;
  /// - total inconnu (maxTiles = 0) → recalculé depuis les compteurs.
  @visibleForTesting
  LayerDownloadResult assessResult(
    int maxTiles,
    int successful,
    int failed,
    int negative,
    DownloadInterruptReason interruptReason,
  ) {
    final total = maxTiles > 0 ? maxTiles : (successful + failed + negative);
    if (total == 0) {
      return LayerDownloadResult(
        downloadedTileCount: 0,
        estimatedTileCount: 0,
        successful: false,
        interruptReason: interruptReason,
      );
    }
    final failedRatio = failed / total;

    // P1 audit : au moins UNE tuile réelle exigée pour déclarer succès.
    final ok = successful > 0 && failedRatio <= _networkFailureTolerance;

    if (!ok) {
      if (kVerboseDownloader) {
        debugPrint(
          '[FmtcLayerDownloader] Layer assessed FAILED: '
          'successful=$successful failedRatio=${failedRatio.toStringAsFixed(3)} total=$total',
        );
      }
    }

    return LayerDownloadResult(
      downloadedTileCount: successful,
      estimatedTileCount: total,
      successful: ok,
      negativeTileCount: negative,
      failedTileCount: failed,
      interruptReason: interruptReason,
    );
  }

  @override
  Future<void> cancel(
    String zoneUuid,
    FMTCStore store,
    String instanceId,
  ) async {
    try {
      await store.download.cancel(instanceId: instanceId);
    } catch (e) {
      if (kVerboseDownloader) {
        debugPrint('[FmtcLayerDownloader] cancel error: $e');
      }
    }
  }

  @override
  bool pause(String zoneUuid, FMTCStore store, String instanceId) {
    // 👇 Vérifie que l'instance est active avant de pauser
    if (!_activeInstances.contains(instanceId)) {
      if (kVerboseDownloader) {
        debugPrint(
          '[FmtcLayerDownloader] pause() ignoré : instance $instanceId inactive',
        );
      }
      return false;
    }
    try {
      store.download.pause(instanceId: instanceId);
      _pausedInstances.add(instanceId);
      return true;
    } catch (e) {
      if (kVerboseDownloader) {
        debugPrint('[FmtcLayerDownloader] pause() échoué : $e');
      }
    }
    return false;
  }

  @override
  bool resume(String zoneUuid, FMTCStore store, String instanceId) {
    // 👇 Vérifie que l'instance est active avant de resume
    if (!_activeInstances.contains(instanceId)) {
      if (kVerboseDownloader) {
        debugPrint(
          '[FmtcLayerDownloader] resume() ignoré : instance $instanceId inactive',
        );
      }
      return false;
    }
    try {
      store.download.resume(instanceId: instanceId);
      _pausedInstances.remove(instanceId);
      return true;
    } catch (e) {
      if (kVerboseDownloader) {
        debugPrint('[FmtcLayerDownloader] resume() échoué : $e');
      }
    }
    return false;
  }
}
