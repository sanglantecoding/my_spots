import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/zone_download/layer_download_result.dart';

/// Logs de debugging downloader FMTC. Laisser à false.
const bool kVerboseDownloader = false;
const bool kVerboseTileAudit = false;

// ─── Callbacks & interface abstraite ────────────────────────────────────────

/// Callback de progression pour une couche en cours de téléchargement.
typedef LayerProgressCallback = void Function(double progress);

/// Interface abstraite pour le téléchargement d'une couche.
///
/// Permet de substituer [FmtcLayerDownloader] par un mock en tests unitaires.
abstract class LayerDownloader {
  /// Télécharge une couche et retourne le résultat de l'évaluation.
  ///
  /// [expectPolygon] : si `true`, la zone a été tracée en mode main levée
  /// et un polygone valide est attendu. Si `polygon` est absent ou invalide
  /// (JSON corrompu), le téléchargement est refusé pour éviter de télécharger
  /// silencieusement tout le rectangle englobant.
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
    List<LatLng>? polygon,
    bool expectPolygon = false,
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

  static final Map<String, DateTime> _lastEventAtByInstance = {};

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
    List<LatLng>? polygon,
    bool expectPolygon = false,
  }) async {
    // Force minZoom à au moins 8 pour éviter le téléchargement des zooms 0-7
    // (trop de tuiles, inutiles pour la navigation hors-ligne)
    final effectiveMinZoom = minZoom.clamp(8, 17).toInt();
    final effectiveMaxZoom = maxZoom.clamp(effectiveMinZoom, 17).toInt();

    // 🛡️ GARDE-FOU POLYGONE : la zone a été tracée en mode main levée
    // (expectPolygon == true) mais le polygone décodé est absent ou
    // invalide (JSON corrompu, < 3 sommets). On refuse de télécharger
    // le rectangle englobant, qui pourrait représenter des Go de tuiles
    // inutiles. On passe par assessResult pour une sortie cohérente
    // (successful=false, tous compteurs à 0).
    if (expectPolygon && (polygon == null || polygon.length < 3)) {
      if (kVerboseDownloader) {
        debugPrint(
          '[FmtcLayerDownloader] ERREUR : zone polygone attendue mais polygon '
          'invalide (corruption ou <3 sommets). Téléchargement annulé.',
        );
      }
      return assessResult(0, 0, 0, 0, DownloadInterruptReason.none);
    }

    await store.manage.create();

    // Use CustomPolygonRegion if polygon is provided and valid, otherwise RectangleRegion
    final region = (polygon != null && polygon.length >= 3)
        ? CustomPolygonRegion(polygon).toDownloadable(
            minZoom: effectiveMinZoom,
            maxZoom: effectiveMaxZoom,
            options: TileLayer(
              urlTemplate: urlTemplate,
              userAgentPackageName: MapTileCacheService.packageName,
              tileProvider: _DownloadOnlyTileProvider(headers: headers),
            ),
          )
        : RectangleRegion(bounds).toDownloadable(
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
    StreamSubscription<DownloadProgress>? bridgeSub;
    StreamSubscription<TileEvent>? tileEventsSub;
    Timer? watchdog;

    var maxTiles = 0;
    var successful = 0;
    var negative = 0;
    var failed = 0;

    // Variables pour l'audit détaillé
    var attempted = 0;
    var remaining = 0;
    var failedTiles = 0;
    var sea = 0;
    var existing = 0;
    var skipped = 0;
    var buffered = 0;
    var flushed = 0;
    var eventCount = 0; // Limite à 300 événements loggés

    _lastEventAtByInstance[instanceId] = DateTime.now();
    var interruptReason = DownloadInterruptReason.none;

    // 🛡️ Flag pour éviter les appels multiples à cancel()
    var cancellationRequested = false;

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

      // 🟢 AUDIT : S'abonner aux événements détaillés des tuiles
      if (kVerboseTileAudit) {
        tileEventsSub = fgReturn.tileEvents.listen((event) {
          // Limiter à 300 événements pour ne pas saturer logcat
          if (eventCount >= 300) return;

          // Ignorer SuccessfulTileEvent (trop nombreux)
          if (event is SuccessfulTileEvent) return;

          eventCount++;
          // Cette version de FMTC n'expose que [TileEvent.url] :
          // on extrait z/x/y depuis l'URL elle-même.
          final url = event.url;
          final coord = _coordFromUrl(url);

          if (event is SeaTileEvent) {
            debugPrint('[FMTCTILE-AUDIT] SeaTileEvent $coord url=$url');
          } else if (event is ExistingTileEvent) {
            debugPrint('[FMTCTILE-AUDIT] ExistingTileEvent $coord url=$url');
          } else if (event is NegativeResponseTileEvent) {
            debugPrint(
              '[FMTCTILE-AUDIT] NegativeResponseTileEvent $coord url=$url',
            );
          } else if (event is FailedRequestTileEvent) {
            debugPrint(
              '[FMTCTILE-AUDIT] FailedRequestTileEvent $coord url=$url',
            );
          }
        });
      }

      _activeInstances.add(instanceId);

      watchdog = Timer.periodic(const Duration(seconds: 30), (t) async {
        if (_pausedInstances.contains(instanceId)) {
          return;
        }
        final lastEvent = _lastEventAtByInstance[instanceId] ?? DateTime.now();
        if (DateTime.now().difference(lastEvent) > _stallWindow) {
          t.cancel();
          if (kVerboseDownloader) {
            debugPrint(
              '[FmtcLayerDownloader] WATCHDOG stall detected - cancelling instance $instanceId.',
            );
          }
          interruptReason = DownloadInterruptReason.watchdog;

          // ✅ Attendre le cancel pour garantir que FMTC honore l'annulation
          if (!cancellationRequested) {
            cancellationRequested = true;
            try {
              await store.download.cancel(instanceId: instanceId);
            } catch (e) {
              if (kVerboseDownloader) {
                debugPrint('[FmtcLayerDownloader] Watchdog cancel error: $e');
              }
            }
          }
        }
      });

      await for (final p in ctrl.stream) {
        maxTiles = p.maxTilesCount;
        successful = p.successfulTilesCount;
        negative = p.negativeResponseTilesCount;
        failed = p.failedRequestTilesCount;

        // Capturer toutes les stats pour l'audit
        attempted = p.attemptedTilesCount;
        remaining = p.remainingTilesCount;
        failedTiles = p.failedTilesCount;
        sea = p.seaTilesCount;
        existing = p.existingTilesCount;
        skipped = p.skippedTilesCount;
        buffered = p.bufferedTilesCount;
        flushed = p.flushedTilesCount;

        _lastEventAtByInstance[instanceId] = DateTime.now();
        if (maxTiles > 0) {
          final progress = (p.attemptedTilesCount / maxTiles)
              .clamp(0.0, 1.0)
              .toDouble();
          onProgress(progress);
        }

        // ✅ Vérification plafond avec attente du cancel
        if (maxTiles > _maxTileCountCeiling && !cancellationRequested) {
          if (kVerboseDownloader) {
            debugPrint(
              '[FmtcLayerDownloader] Tile count $maxTiles > ceiling - aborting.',
            );
          }
          interruptReason = DownloadInterruptReason.tileCeiling;
          cancellationRequested = true;

          try {
            await store.download.cancel(instanceId: instanceId);
          } catch (e) {
            if (kVerboseDownloader) {
              debugPrint('[FmtcLayerDownloader] Ceiling cancel error: $e');
            }
          }
          // Sortir de la boucle après avoir demandé l'annulation
          break;
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
      _lastEventAtByInstance.remove(instanceId);
      watchdog?.cancel();
      await bridgeSub?.cancel();
      await tileEventsSub?.cancel();
      if (!ctrl.isClosed) {
        await ctrl.close();
      }

      // ✅ Cancel final uniquement si pas déjà demandé
      if (!cancellationRequested) {
        try {
          await store.download
              .cancel(instanceId: instanceId)
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          if (kVerboseDownloader) {
            debugPrint(
              '[FmtcLayerDownloader] Final cancel error (timeout?): $e',
            );
          }
        }
      }
    }

    if (kVerboseTileAudit) {
      final gap = maxTiles - successful;
      debugPrint(
        '[FMTCTILE-AUDIT]\n'
        '  zone=$zoneUuid\n'
        '  instance=$instanceId\n'
        '  max=$maxTiles\n'
        '  successful=$successful\n'
        '  gap=$gap\n'
        '  attempted=$attempted\n'
        '  remaining=$remaining\n'
        '  negative=$negative\n'
        '  failedRequest=$failed\n'
        '  failedTiles=$failedTiles\n'
        '  sea=$sea\n'
        '  existing=$existing\n'
        '  skipped=$skipped\n'
        '  buffered=$buffered\n'
        '  flushed=$flushed',
      );
    }

    return assessResult(
      maxTiles,
      successful,
      failed,
      negative,
      interruptReason,
    );
  }

  /// Extrait z/x/y depuis l'URL de la tuile.
  ///
  /// Cette version de FMTC n'expose aucun getter de coordonnées sur
  /// [TileEvent] (ni `tile`, ni `coords`) : seule l'URL est disponible.
  /// Deux formats supportés :
  ///   - XYZ path : `.../z/x/y.png`
  ///   - WMTS KVP (SHOM / INSPIRE) : `TILEMATRIX=z&TILECOL=x&TILEROW=y`
  static String _coordFromUrl(String url) {
    // Format XYZ path
    final path = RegExp(r'/(\d+)/(\d+)/(\d+)(?:\.\w+)?').firstMatch(url);
    if (path != null) {
      return '${path.group(1)}/${path.group(2)}/${path.group(3)}';
    }
    // Format WMTS KVP
    final q = Uri.tryParse(url)?.queryParameters;
    if (q != null) {
      final z = q['TILEMATRIX'] ?? q['tilematrix'];
      final x = q['TILECOL'] ?? q['tilecol'];
      final y = q['TILEROW'] ?? q['tilerow'];
      if (z != null && x != null && y != null) return '$z/$x/$y';
    }
    return '-';
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
        negativeTileCount: 0,
        failedTileCount: 0,
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
      _lastEventAtByInstance[instanceId] = DateTime.now();
      return true;
    } catch (e) {
      if (kVerboseDownloader) {
        debugPrint('[FmtcLayerDownloader] resume() échoué : $e');
      }
    }
    return false;
  }
}
