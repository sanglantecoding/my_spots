import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/litto3d_layer.dart';
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

// ─── Callbacks publics ──────────────────────────────────────────────────────

/// Callback de progression pour une zone en cours de téléchargement.
///
/// [progress] est compris entre 0.0 et 1.0 (progression globale de la zone).
/// [layerLabel] est le libellé de la couche actuellement en cours.
typedef ZoneProgressCallback =
    void Function({required double progress, required String layerLabel});

/// Callback d'erreur pour une zone en cours de téléchargement.
typedef ZoneErrorCallback = void Function(String message);

// ─── Raisons d'interruption d'un téléchargement ─────────────────────────────

/// Raison pour laquelle un téléchargement de zone a été interrompu.
///
/// Persistée dans [_ZoneState.cancelReason] afin que l'évaluation finale
/// ([_finalizeZone]) puisse produire un statut (`partial`/`failed`) et un
/// message (`map.lastError`) adaptés à la cause réelle.
enum DownloadCancelReason {
  /// Téléchargement non interrompu (allé jusqu'au bout).
  none,

  /// Annulation explicite par l'utilisateur.
  user,

  /// Interrompu par le watchdog (flux gelé).
  watchdog,

  /// Interrompu car le plafond de tuiles a été dépassé.
  tileCeiling,
}

/// Résultat de l'évaluation d'une couche en fin de téléchargement.
enum LayerOutcome {
  /// Toutes les tuiles téléchargées, aucun échec.
  ok,

  /// Certaines tuiles OK mais aussi des échecs réseau.
  partial,

  /// Seulement des échecs réseau.
  networkFailure,

  /// 0 tuile réelle téléchargée ET 0 échec réseau = couche hors couverture.
  /// (ex. LiDAR hors campagne) — ni un succès, ni un échec réseau.
  noCoverage,

  /// Couche interrompue (par utilisateur, watchdog ou plafond).
  interrupted,
}

// ─── État interne d'une zone ────────────────────────────────────────────────

class _ZoneState {
  bool isCancelled = false;
  bool isPaused = false;

  /// Raison de l'interruption (reste à [DownloadCancelReason.none] si le
  /// téléchargement est allé jusqu'au bout).
  DownloadCancelReason cancelReason = DownloadCancelReason.none;

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
/// - Évaluation finale (ready / partial / failed) basée sur la cause réelle
///   (annulation utilisateur, watchdog, plafond, échecs réseau, sans couverture)
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

  /// Dernière instanceId utilisée par couple (zone, store) : permet au run
  /// suivant de pré-annuler l'orphelin du MÊME store uniquement — plus jamais
  /// d'association croisée « instance d'un run précédent / store d'une autre couche ».
  final Map<String, String> _previousInstanceIds = {};

  /// Instance partagée par tous les écrans : un téléchargement lancé depuis
  /// la carte reste pilotable (pause / reprise / suivi) depuis l'écran des
  /// zones, et inversement. Les tests unitaires continuent d'utiliser le
  /// constructeur directement avec leurs fakes.
  static ZoneDownloadService? _instance;

  static ZoneDownloadService get instance {
    return _instance ??= ZoneDownloadService(
      repository: OfflineMapRepository.instance ?? _NoopRepo(),
    );
  }

  /// Réservé aux tests : permet d'injecter/remettre à zéro le singleton.
  @visibleForTesting
  static void overrideInstanceForTest(ZoneDownloadService? service) =>
      _instance = service;

  /// Accès au repository (utile pour les tests).
  MapLayerRepository get repository => _repository;

  /// `true` si une zone est en cours de téléchargement.
  bool isDownloading(String zoneUuid) => _zones.containsKey(zoneUuid);

  /// Nombre de zones actuellement en cours de téléchargement.
  int get activeCount => _zones.length;

  /// True si la zone a un téléchargement enregistré (en cours ou en pause).
  bool hasZone(String zoneUuid) => _zones.containsKey(zoneUuid);

  /// True si un téléchargement tourne actuellement (hors pause).
  bool isRunning(String zoneUuid) {
    final s = _zones[zoneUuid];
    return s != null && !s.isPaused;
  }

  /// True si au moins une zone a un téléchargement actif ou en pause.
  bool get hasActiveZones => _zones.isNotEmpty;

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
    bool initializationFailed = false;

    try {
      map.status = OfflineMapStatus.downloading;
      map.lastError = null; // Reset avant de démarrer
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

        final storeName = _fmtcStoreName(
          map.uuid,
          layer.layerType,
          layer.lidarLayerId,
        );
        final store = FMTCStore(storeName);

        // 👇 Identité unique : zone + run + couche (+ campagne LiDAR).
        final instanceId = '${map.uuid}#$runCount#${_layerKey(layer)}';

        // 👇 Pre-cancel cohérent : l'orphelin éventuel est celui du MÊME store.
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

        // 👇 TRADUCTION : DownloadInterruptReason → DownloadCancelReason
        // Le downloader a détecté watchdog / plafond et posé la raison dans
        // le LayerDownloadResult. On la propage dans le state global pour
        // que _finalizeZone puisse produire le bon statut/message.
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

      _finalizeZone(map, state, layers, layerResults, onError);
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

  /// Évalue le résultat d'une couche en tenant compte de la raison
  /// d'interruption éventuelle du téléchargement global.
  LayerOutcome assessLayerResult(
    LayerDownloadResult r,
    DownloadCancelReason cancelReason,
  ) {
    // Interruption technique ou utilisateur : JAMAIS un succès,
    // même si des tuiles ont été téléchargées avant l'interruption.
    if (cancelReason != DownloadCancelReason.none) {
      return r.downloadedTileCount > 0
          ? LayerOutcome.partial
          : LayerOutcome.interrupted;
    }

    // Aucune tuile réelle téléchargée
    if (r.downloadedTileCount == 0) {
      // 0 tuile réelle + 0 échec réseau = couche hors couverture sur la zone
      // (ex. LiDAR hors campagne) → ni un succès, ni un échec réseau.
      if (r.failedTileCount == 0) return LayerOutcome.noCoverage;
      return LayerOutcome.networkFailure;
    }

    // Des tuiles ont été téléchargées, mais le downloader a jugé la couche
    // en échec (trop d'échecs réseau selon _networkFailureTolerance) :
    // on ne doit PAS la compter comme un succès.
    if (!r.successful) {
      return LayerOutcome.networkFailure;
    }

    // Des tuiles OK avec quelques échecs réseau isolés → partiel
    if (r.failedTileCount > 0) return LayerOutcome.partial;
    return LayerOutcome.ok;
  }

  /// Détermine le statut final de la zone à partir des résultats par couche
  /// et de la raison d'interruption.
  ///
  /// Règles :
  /// - Si toutes les couches sont `ok` et aucune interruption → `ready`.
  /// - Si interruption utilisateur → `partial` (s'il y a du contenu),
  ///   sinon `notStarted` ; message clair dans `map.lastError`.
  /// - Si interruption watchdog/plafond → `partial` (avec contenu) ou `failed`.
  /// - Si échecs réseau → `partial` ou `failed` selon qu'il y a au moins
  ///   une couche avec du contenu.
  /// - Si des couches sont `noCoverage` (seules OU mixées avec ok/partial)
  ///   → `partial` avec message explicite (jamais `ready`, jamais `failed`).
  ///
  /// Exposée pour les tests unitaires.
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

    // Pas d'interruption : évaluation par résultats des couches
    if (outcomes.every((o) => o == LayerOutcome.ok)) {
      map.lastError = null;
      return OfflineMapStatus.ready;
    }

    if (outcomes.contains(LayerOutcome.networkFailure)) {
      final n = outcomes.where((o) => o == LayerOutcome.networkFailure).length;
      map.lastError = 'Échecs réseau sur $n couche(s)';
      return hasOkOrPartial
          ? OfflineMapStatus.partial
          : OfflineMapStatus.failed;
    }

    // Couche(s) sans couverture : partiel avec message clair,
    // MÊME en cas mixte (ex. marine ok + LiDAR hors campagne) :
    // l'utilisateur doit savoir pourquoi la zone n'est pas `ready`.
    final noCov = outcomes.where((o) => o == LayerOutcome.noCoverage).length;
    if (noCov > 0) {
      map.lastError = '$noCov couche(s) sans couverture sur cette zone';
      return OfflineMapStatus.partial;
    }

    // Cas mixte restant (interrupted + ok + partial)
    map.lastError = null;
    return hasOkOrPartial ? OfflineMapStatus.partial : OfflineMapStatus.failed;
  }

  void _finalizeZone(
    OfflineMap map,
    _ZoneState state,
    List<OfflineMapLayer> layers,
    Map<LayerType, LayerDownloadResult> layerResults, [
    ZoneErrorCallback? onError,
  ]) {
    // Évaluation fine par couche via assessLayerResult (utilise les compteurs
    // réels : downloaded / failed / negative), avec fallback si la couche
    // n'a pas de résultat (exception réseau avant retour du downloader).
    final outcomes = layers.map((layer) {
      final result = layerResults[layer.layerType];
      if (result != null) {
        return assessLayerResult(result, state.cancelReason);
      }
      if (layer.downloadStatus == LayerDownloadStatus.completed) {
        return LayerOutcome.ok;
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

    debugPrint(
      '[ZoneDownload] ${map.uuid}: status=$status, reason=${state.cancelReason.name}, '
      'outcomes=${outcomes.map((o) => o.name).toList()}, lastError="${map.lastError}"',
    );

    NegativeFilteringImageProvider.clearStoreNamesCache();
  }

  /// Annule le téléchargement d'une zone.
  ///
  /// Pose la raison [DownloadCancelReason.user] avant de déclencher le
  /// cancel FMTC, afin que [_finalizeZone] produise le bon statut/message.
  Future<void> cancelDownload(String zoneUuid) async {
    final state = _zones[zoneUuid];
    if (state == null) return;

    state.isCancelled = true;
    state.cancelReason = DownloadCancelReason.user; // ← raison persistée
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;

    if (store != null && instanceId != null) {
      await _downloader.cancel(zoneUuid, store, instanceId);
    }
  }

  /// Met en pause le téléchargement d'une zone (même instance FMTC).
  void pauseDownload(String zoneUuid) {
    final state = _zones[zoneUuid];
    if (state == null) return;
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;
    if (store == null || instanceId == null) return;
    state.isPaused = true;
    debugPrint('[ZoneDownload] PAUSE $zoneUuid instance=$instanceId');
    _downloader.pause(zoneUuid, store, instanceId);
  }

  /// Reprend un téléchargement mis en pause (même instance FMTC).
  void resumeDownload(String zoneUuid) {
    final state = _zones[zoneUuid];
    if (state == null) return;
    final store = state.activeStore;
    final instanceId = state.activeInstanceId;
    if (store == null || instanceId == null) return;
    state.isPaused = false;
    debugPrint('[ZoneDownload] RESUME $zoneUuid instance=$instanceId');
    _downloader.resume(zoneUuid, store, instanceId);
  }

  /// True si la zone est actuellement en pause.
  bool isPaused(String zoneUuid) => _zones[zoneUuid]?.isPaused ?? false;

  /// Attend la fin réelle d'un téléchargement de zone avant de purger.
  ///
  /// Utile depuis `deleteZone()` par exemple : on attend que le téléchargeur
  /// ait vraiment terminé (y compris l'écriture du statut final) avant de
  /// supprimer le store FMTC et la ligne ObjectBox.
  ///
  /// Timeout après [timeout] secondes pour ne pas bloquer indéfiniment.
  Future<void> waitForCompletion(
    String zoneUuid, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final state = _zones[zoneUuid];
    final allDone = state?.allDone;
    if (allDone == null) return;
    try {
      await allDone.future.timeout(timeout);
    } on TimeoutException {
      debugPrint('[ZoneDownload] waitForCompletion: timeout pour $zoneUuid');
    }
  }

  // ─── Helpers internes ─────────────────────────────────────────────────────

  /// Clé courte et stable identifiant une couche (et sa campagne LiDAR),
  /// utilisée dans l'instanceId FMTC : `<zone>#<run>#<clé>`.
  String _layerKey(OfflineMapLayer layer) =>
      layer.layerType.name +
      (layer.lidarLayerId != null ? ':${layer.lidarLayerId}' : '');

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

  /// Génère un libellé lisible pour une couche.
  String _layerLabel(OfflineMapLayer layer) {
    if (layer.layerType == LayerType.lidarLitto3d &&
        layer.lidarLayerId != null) {
      return 'lidarLitto3d:${layer.lidarLayerId}';
    }
    return layer.layerType.name;
  }
}

/// Repository vide pour le mode dégradé (ObjectBox indisponible).
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
