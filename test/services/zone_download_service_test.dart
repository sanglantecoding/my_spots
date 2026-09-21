// Unit tests for ZoneDownloadService — zone-scoped FMTC download orchestration.
//
// NOTE: Uses an in-memory FakeMapLayerRepository instead of ObjectBox
// (pre-existing objectbox.dll unavailable in test PATH).

import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/zone_download/zone_download.dart';

// In-memory fake: replaces OfflineMapRepository so tests avoid ObjectBox.
class FakeMapLayerRepository implements MapLayerRepository {
  final maps = <String, OfflineMap>{}; // keyed by uuid
  final layers = <int, OfflineMapLayer>{}; // keyed by ObjectBox-assigned id
  int _nextMapId = 1;
  int _nextLayerId = 1;

  @override
  void save(OfflineMap map) {
    map.id = _nextMapId++;
    maps[map.uuid] = map;
  }

  @override
  void saveLayer(OfflineMap map, OfflineMapLayer layer) {
    layer.offlineMapId = map.id;
    layer.id = _nextLayerId++;
    layers[layer.id] = layer;
  }

  @override
  OfflineMap? findByUuid(String uuid) => maps[uuid];

  @override
  OfflineMapLayer? findLayerById(int id) => layers[id];
}

// Fake downloader that records calls and returns configurable results.
// Set [gateCompletion] to a Completer; downloadLayer will await it
// before returning so tests can inspect intermediate state.
class FakeLayerDownloader implements LayerDownloader {
  FakeLayerDownloader({
    this.results = const [],
    this.cancelError,
    Completer<void>? gateCompletion,
  }) : _gate = gateCompletion ?? (Completer<void>()..complete());
  final List<LayerDownloadResult> results;
  final Object? cancelError;
  Completer<void> _gate;

  /// Set a new gate that downloadLayer should wait on.
  void gate(Completer<void> c) => _gate = c;
  final calls = <_Call>[];
  final preCancels = <_PreCancel>[];
  String? cancelledZone;
  int count = 0;
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
    required void Function(double) onProgress,
    String? preCancelInstanceId,
    FMTCStore? preCancelStore,
  }) async {
    // Record pre-cancel so tests can verify the service forwards it.
    if (preCancelInstanceId != null && preCancelStore != null) {
      preCancels.add(
        _PreCancel(
          id: preCancelInstanceId,
          storeName: preCancelStore.storeName,
        ),
      );
    }
    calls.add(
      _Call(
        z: zoneUuid,
        sn: store.storeName,
        u: urlTemplate,
        zmin: minZoom,
        zmax: maxZoom,
        iid: instanceId,
      ),
    );
    count++;
    onProgress(1.0);
    await _gate.future; // block until test signals to continue
    if (count <= results.length) return results[count - 1];
    return const LayerDownloadResult(
      downloadedTileCount: 0,
      estimatedTileCount: 0,
      successful: true,
    );
  }

  @override
  Future<void> cancel(
    String zoneUuid,
    FMTCStore store,
    String instanceId,
  ) async {
    cancelledZone = zoneUuid;
    if (cancelError != null) throw StateError('cancel-fail');
  }

  @override
  void pause(String z, FMTCStore s, String iid) {}
  @override
  void resume(String z, FMTCStore s, String iid) {}
}

class _Call {
  _Call({
    required this.z,
    required this.sn,
    required this.u,
    required this.zmin,
    required this.zmax,
    required this.iid,
  });
  final String z, sn, u, iid;
  final int zmin, zmax;
}

/// Records a pre-cancel request forwarded by the service.
class _PreCancel {
  _PreCancel({required this.id, required this.storeName});
  final String id;
  final String storeName;
}

OfflineMap _m(String u) => OfflineMap.create(
  uuid: u,
  name: 'Z',
  northLat: 44,
  southLat: 43,
  westLng: 6,
  eastLng: 7,
);
OfflineMapLayer _l(LayerType t) =>
    OfflineMapLayer.create(layerType: t, minZoom: 8, maxZoom: 14);

void main() {
  late FakeMapLayerRepository repo;

  setUp(() {
    repo = FakeMapLayerRepository();
  });
  group('downloadZone — empty input', () {
    test('empty layers list returns without calling downloader', () async {
      final d = FakeLayerDownloader();
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('empty');
      repo.save(map);
      await s2.downloadZone(map: map, layers: []);
      expect(d.count, 0);
    });
  });

  group('downloadZone — initial state', () {
    test('sets map status to downloading before completion', () async {
      final gate = Completer<void>();
      final d = FakeLayerDownloader(gateCompletion: gate);
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('init-map');
      repo.save(map);
      final layer = _l(LayerType.marine25k);
      repo.saveLayer(map, layer);
      unawaited(s2.downloadZone(map: map, layers: [layer]));
      await Future.delayed(Duration.zero); // let zone enter _zones
      expect(repo.findByUuid(map.uuid)!.status, OfflineMapStatus.downloading);
      gate.complete(); // allow download to finish
    });
    test('sets all layer statuses to downloading', () async {
      final gate = Completer<void>();
      final d = FakeLayerDownloader(gateCompletion: gate);
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('init-layers');
      repo.save(map);
      final a = _l(LayerType.marine25k);
      final b = _l(LayerType.lidarLitto3d);
      repo.saveLayer(map, a);
      repo.saveLayer(map, b);
      unawaited(s2.downloadZone(map: map, layers: [a, b]));
      await Future.delayed(Duration.zero);
      expect(
        repo.findLayerById(a.id)!.downloadStatus,
        LayerDownloadStatus.downloading,
      );
      expect(
        repo.findLayerById(b.id)!.downloadStatus,
        LayerDownloadStatus.downloading,
      );
      gate.complete();
    });
  });

  group('downloadZone — completion states', () {
    test('all layers successful → map status ready', () async {
      final d = FakeLayerDownloader(
        results: [
          const LayerDownloadResult(
            downloadedTileCount: 100,
            estimatedTileCount: 100,
            successful: true,
          ),
          const LayerDownloadResult(
            downloadedTileCount: 50,
            estimatedTileCount: 50,
            successful: true,
          ),
        ],
      );
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('all-ok');
      repo.save(map);
      final a = _l(LayerType.marine25k);
      final b = _l(LayerType.lidarLitto3d);
      repo.saveLayer(map, a);
      repo.saveLayer(map, b);
      await s2.downloadZone(map: map, layers: [a, b]);
      final u = repo.findByUuid(map.uuid)!;
      expect(u.status, OfflineMapStatus.ready);
      expect(u.completedAt.millisecondsSinceEpoch, greaterThan(0));
      expect(
        repo.findLayerById(a.id)!.downloadStatus,
        LayerDownloadStatus.completed,
      );
      expect(
        repo.findLayerById(b.id)!.downloadStatus,
        LayerDownloadStatus.completed,
      );
    });
    test('all layers failed → map status failed', () async {
      final d = FakeLayerDownloader(
        results: [
          const LayerDownloadResult(
            downloadedTileCount: 0,
            estimatedTileCount: 50,
            successful: false,
            failedTileCount: 50, // Échecs réseau réels
          ),
          const LayerDownloadResult(
            downloadedTileCount: 0,
            estimatedTileCount: 50,
            successful: false,
            failedTileCount: 50, // Échecs réseau réels
          ),
        ],
      );
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('all-fail');
      repo.save(map);
      final a = _l(LayerType.marine25k);
      final b = _l(LayerType.lidarLitto3d);
      repo.saveLayer(map, a);
      repo.saveLayer(map, b);
      await s2.downloadZone(map: map, layers: [a, b]);
      expect(repo.findByUuid(map.uuid)!.status, OfflineMapStatus.failed);
    });
    test('mixed results → map status partial', () async {
      final d = FakeLayerDownloader(
        results: [
          const LayerDownloadResult(
            downloadedTileCount: 100,
            estimatedTileCount: 100,
            successful: true,
          ),
          const LayerDownloadResult(
            downloadedTileCount: 0,
            estimatedTileCount: 50,
            successful: false,
          ),
        ],
      );
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('partial');
      repo.save(map);
      final a = _l(LayerType.marine25k);
      final b = _l(LayerType.lidarLitto3d);
      repo.saveLayer(map, a);
      repo.saveLayer(map, b);
      await s2.downloadZone(map: map, layers: [a, b]);
      final u = repo.findByUuid(map.uuid)!;
      expect(u.status, OfflineMapStatus.partial);
      expect(u.completedAt.millisecondsSinceEpoch, greaterThan(0));
    });
    test('successful layer records tile counts in fake repo', () async {
      final d = FakeLayerDownloader(
        results: [
          const LayerDownloadResult(
            downloadedTileCount: 42,
            estimatedTileCount: 100,
            successful: true,
          ),
        ],
      );
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('tile-count');
      repo.save(map);
      final layer = _l(LayerType.marine25k);
      repo.saveLayer(map, layer);
      await s2.downloadZone(map: map, layers: [layer]);
      final u = repo.findLayerById(layer.id)!;
      expect(u.downloadedTileCount, 42);
      expect(u.estimatedTileCount, 100);
    });
  });

  group('downloadZone — cancellation', () {
    test('cancelDownload sets map to notStarted when no content', () async {
      final gate = Completer<void>();
      final d = FakeLayerDownloader(gateCompletion: gate);
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('cancel-fail');
      repo.save(map);
      final layer = _l(LayerType.marine25k);
      repo.saveLayer(map, layer);
      unawaited(s2.downloadZone(map: map, layers: [layer]));
      await Future.delayed(Duration.zero); // zone enters _zones
      await s2.cancelDownload(map.uuid); // signals isCancelled = true
      gate.complete(); // unblocks download — loop sees isCancelled, breaks
      await Future.delayed(Duration.zero); // finalize writes status=notStarted
      expect(repo.findByUuid(map.uuid)!.status, OfflineMapStatus.notStarted);
    });
    test('cancelDownload delegates zone uuid to downloader', () async {
      final gate = Completer<void>();
      final d = FakeLayerDownloader(gateCompletion: gate);
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('cancel-delegate');
      repo.save(map);
      final layer = _l(LayerType.marine25k);
      repo.saveLayer(map, layer);
      // Start download so zone is registered, then cancel.
      unawaited(s2.downloadZone(map: map, layers: [layer]));
      await Future.delayed(Duration.zero); // zone enters _zones
      await s2.cancelDownload(map.uuid);
      gate.complete();
      expect(d.cancelledZone, map.uuid);
    });
    test('cancel on inactive zone is safe no-op', () async {
      final d = FakeLayerDownloader();
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      await s2.cancelDownload('never-active'); // must not throw
    });
  });
  group('downloadZone — store routing', () {
    test('marine25k uses marine_zone_ uuid store', () async {
      final d = FakeLayerDownloader();
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('marine-store');
      repo.save(map);
      final layer = _l(LayerType.marine25k);
      repo.saveLayer(map, layer);
      await s2.downloadZone(map: map, layers: [layer]);
      expect(d.calls.single.sn, 'marine_zone_${map.uuid}');
    });
    test(
      'lidarLitto3d uses lidar_zone_ uuid store when lidarLayerId is null',
      () async {
        final d = FakeLayerDownloader();
        final s2 = ZoneDownloadService(repository: repo, downloader: d);
        final map = _m('lidar-store');
        repo.save(map);
        final layer = _l(LayerType.lidarLitto3d);
        repo.saveLayer(map, layer);
        await s2.downloadZone(map: map, layers: [layer]);
        // When lidarLayerId is null, uses legacy format: lidar_zone_<uuid>
        expect(d.calls.single.sn, equals('lidar_zone_${map.uuid}'));
      },
    );

    test(
      'lidarLitto3d uses lidar_zone_ uuid_layerId store when lidarLayerId is set',
      () async {
        final d = FakeLayerDownloader();
        final s2 = ZoneDownloadService(repository: repo, downloader: d);
        final map = _m('lidar-new-format');
        repo.save(map);
        final layer = _l(LayerType.lidarLitto3d);
        layer.lidarLayerId = 'occitanie_2009';
        repo.saveLayer(map, layer);
        await s2.downloadZone(map: map, layers: [layer]);
        // When lidarLayerId is set, uses new format: lidar_zone_<uuid>_<layerId>
        expect(
          d.calls.single.sn,
          equals('lidar_zone_${map.uuid}_occitanie_2009'),
        );
      },
    );
  });

  group('downloadZone — URL routing', () {
    test('marine10k URL contains RASTER_MARINE_10_WMTS_3857', () async {
      final d = FakeLayerDownloader();
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('url-10k');
      repo.save(map);
      final layer = _l(LayerType.marine10k);
      repo.saveLayer(map, layer);
      await s2.downloadZone(map: map, layers: [layer]);
      expect(d.calls.single.u, contains('RASTER_MARINE_10_WMTS_3857'));
    });
    test('marine50k URL contains RASTER_MARINE_50_WMTS_3857', () async {
      final d = FakeLayerDownloader();
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('url-50k');
      repo.save(map);
      final layer = _l(LayerType.marine50k);
      repo.saveLayer(map, layer);
      await s2.downloadZone(map: map, layers: [layer]);
      expect(d.calls.single.u, contains('RASTER_MARINE_50_WMTS_3857'));
    });
    test('zoom range forwarded from layer', () async {
      final d = FakeLayerDownloader();
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('zoom');
      repo.save(map);
      final layer = _l(LayerType.marine25k);
      layer.minZoom = 12;
      layer.maxZoom = 18;
      repo.saveLayer(map, layer);
      await s2.downloadZone(map: map, layers: [layer]);
      expect(d.calls.single.zmin, 12);
      expect(d.calls.single.zmax, 18);
    });

    test(
      'lidarLitto3d URL uses the regional layer covering the zone',
      () async {
        final d = FakeLayerDownloader();
        final s2 = ZoneDownloadService(repository: repo, downloader: d);
        // South Brittany — covered by bretagne_morbihan / bretagne / etc.
        // (see LidarRegionCatalog.regionsIntersecting).
        final map = OfflineMap.create(
          uuid: 'bzh',
          name: 'Bretagne sud',
          northLat: 47.8,
          southLat: 47.0,
          westLng: -3.5,
          eastLng: -2.0,
        );
        repo.save(map);
        final layer = _l(LayerType.lidarLitto3d);
        repo.saveLayer(map, layer);
        final bounds = LatLngBounds(LatLng(47.0, -3.5), LatLng(47.8, -2.0));
        await s2.downloadZone(map: map, layers: [layer], zoneBounds: bounds);
        // URL must NOT be the buggy "first layer" (Normandie).
        expect(
          d.calls.single.u,
          isNot(contains('L3D_MAR_NHDF_2016_2018_PYR_3857_WMTS')),
        );
        // It must be one of the Brittany layers.
        final url = d.calls.single.u;
        expect(
          url.contains('L3D_MAR_MORBIHAN_2015_PYR_3857_WMTS') ||
              url.contains('LITTO3D_BZH_2018_2021_PYR_3857_WMTS') ||
              url.contains('L3D_LIDAR_RANCE_2019_WMTS_3857') ||
              url.contains('LITTO3D_FINISTR_2014_PYR_3857_WMTS') ||
              url.contains('L3D_LIDAR_ROCHES_DOUVRES_BARNOUIC_2022_WMTS_3857'),
          isTrue,
          reason: 'Expected a Brittany Litto3D URL, got: $url',
        );
      },
    );

    test(
      'lidarLitto3d URL falls back to first layer when bounds outside any region',
      () async {
        final d = FakeLayerDownloader();
        final s2 = ZoneDownloadService(repository: repo, downloader: d);
        // Middle of the Atlantic — no LiDAR region covers this.
        final map = OfflineMap.create(
          uuid: 'ocean',
          name: 'Ocean',
          northLat: 30.0,
          southLat: 25.0,
          westLng: -40.0,
          eastLng: -30.0,
        );
        repo.save(map);
        final layer = _l(LayerType.lidarLitto3d);
        repo.saveLayer(map, layer);
        final bounds = LatLngBounds(LatLng(25.0, -40.0), LatLng(30.0, -30.0));
        await s2.downloadZone(map: map, layers: [layer], zoneBounds: bounds);
        // Falls back to first layer (no candidate for the bounds).
        expect(
          d.calls.single.u,
          contains('L3D_MAR_NHDF_2016_2018_PYR_3857_WMTS'),
        );
      },
    );

    test('lidarLitto3d URL with null zoneBounds uses first layer', () async {
      final d = FakeLayerDownloader();
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('lidar-null');
      repo.save(map);
      final layer = _l(LayerType.lidarLitto3d);
      repo.saveLayer(map, layer);
      // No zoneBounds -> first layer.
      await s2.downloadZone(map: map, layers: [layer]);
      expect(
        d.calls.single.u,
        contains('L3D_MAR_NHDF_2016_2018_PYR_3857_WMTS'),
      );
    });

    // ── Regression: re-downloading an Occitanie zone must preserve the
    //   three overlapping Litto3D campaigns. The UI now reconstructs
    //   zoneBounds from OfflineMap coords before calling downloadZone.
    //   If those bounds are lost, _layerUrl() falls back to NHDF.
    test(
      'lidarLitto3d Occitanie — initial creation and update select the same regional dataset',
      () async {
        // First creation: caller (MapScreen) passes explicit zoneBounds.
        final d1 = FakeLayerDownloader();
        final s1 = ZoneDownloadService(repository: repo, downloader: d1);
        final map1 = OfflineMap.create(
          uuid: 'occ-1',
          name: 'Occitanie initial',
          northLat: 44.0,
          southLat: 43.0,
          westLng: 2.5,
          eastLng: 3.5,
        );
        repo.save(map1);
        final layer1 = _l(LayerType.lidarLitto3d);
        repo.saveLayer(map1, layer1);
        final occitanieBounds = LatLngBounds(
          LatLng(43.0, 2.5),
          LatLng(44.0, 3.5),
        );
        await s1.downloadZone(
          map: map1,
          layers: [layer1],
          zoneBounds: occitanieBounds,
        );
        final urlInitial = d1.calls.single.u;
        expect(
          urlInitial,
          isNot(contains('NHDF')),
          reason:
              'Initial creation must use an Occitanie dataset, not NHDF. '
              'Got: $urlInitial',
        );
        expect(
          urlInitial.contains('L3D_MAR_LR_2014_2015_WMTS_3857') ||
              urlInitial.contains('L3D_MAR_LR_2011_PYR_3857_WMTS') ||
              urlInitial.contains('LITTO3D_LR_2009_PYR_3857_WMTS'),
          isTrue,
          reason: 'Expected an Occitanie Litto3D URL, got: $urlInitial',
        );

        // Update path: the UI now reconstructs zoneBounds from OfflineMap
        // coords (southLat/westLng/northLat/eastLng) — same exact rectangle.
        final d2 = FakeLayerDownloader();
        final s2 = ZoneDownloadService(repository: repo, downloader: d2);
        final map2 = OfflineMap.create(
          uuid: 'occ-2',
          name: 'Occitanie update',
          northLat: 44.0,
          southLat: 43.0,
          westLng: 2.5,
          eastLng: 3.5,
        );
        repo.save(map2);
        final layer2 = _l(LayerType.lidarLitto3d);
        repo.saveLayer(map2, layer2);
        final reconstructedBounds = LatLngBounds(
          LatLng(map2.southLat, map2.westLng),
          LatLng(map2.northLat, map2.eastLng),
        );
        await s2.downloadZone(
          map: map2,
          layers: [layer2],
          zoneBounds: reconstructedBounds,
        );
        final urlUpdate = d2.calls.single.u;
        expect(
          urlUpdate,
          isNot(contains('NHDF')),
          reason:
              'Update must use an Occitanie dataset, not NHDF. Got: $urlUpdate',
        );
        expect(
          urlUpdate,
          equals(urlInitial),
          reason:
              'Update must select the same Occitanie dataset as initial. '
              'Initial: $urlInitial, Update: $urlUpdate',
        );
      },
    );
  });
  group('onProgress callback', () {
    test('receives layer labels for each layer', () async {
      final d = FakeLayerDownloader(
        results: [
          const LayerDownloadResult(
            downloadedTileCount: 10,
            estimatedTileCount: 10,
            successful: true,
          ),
          const LayerDownloadResult(
            downloadedTileCount: 5,
            estimatedTileCount: 5,
            successful: true,
          ),
        ],
      );
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('progress');
      repo.save(map);
      final a = _l(LayerType.marine25k);
      final b = _l(LayerType.lidarLitto3d);
      repo.saveLayer(map, a);
      repo.saveLayer(map, b);
      final labels = <String>[];
      await s2.downloadZone(
        map: map,
        layers: [a, b],
        onProgress: ({required progress, required layerLabel}) {
          labels.add(layerLabel);
        },
      );
      expect(labels, containsAll(['marine25k', 'lidarLitto3d']));
    });
  });
  group('isDownloading / activeCount', () {
    test('isDownloading true during active download', () async {
      final gate = Completer<void>();
      final d = FakeLayerDownloader(gateCompletion: gate);
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('is-dl');
      repo.save(map);
      final layer = _l(LayerType.marine25k);
      repo.saveLayer(map, layer);
      expect(s2.isDownloading(map.uuid), isFalse);
      unawaited(s2.downloadZone(map: map, layers: [layer]));
      await Future.delayed(Duration.zero);
      expect(s2.isDownloading(map.uuid), isTrue);
      gate.complete();
    });
    test('activeCount is 1 during download', () async {
      final gate = Completer<void>();
      final d = FakeLayerDownloader(gateCompletion: gate);
      final s2 = ZoneDownloadService(repository: repo, downloader: d);
      final map = _m('active');
      repo.save(map);
      final layer = _l(LayerType.marine25k);
      repo.saveLayer(map, layer);
      expect(s2.activeCount, 0);
      unawaited(s2.downloadZone(map: map, layers: [layer]));
      await Future.delayed(Duration.zero);
      expect(s2.activeCount, 1);
      gate.complete();
    });
  });

  // ── Regression tests for FMTC instance ID + stream handling fixes ──
  group(
    'downloadZone — FMTC instance ID hygiene (regression for "Bad state: A download instance with ID ... already exists")',
    () {
      test(
        'two consecutive runs of the same zone use distinct instance ids',
        () async {
          final d = FakeLayerDownloader();
          final s2 = ZoneDownloadService(repository: repo, downloader: d);
          final map = _m('inst-id');
          repo.save(map);
          final layer = _l(LayerType.marine25k);
          repo.saveLayer(map, layer);

          await s2.downloadZone(map: map, layers: [layer]);
          await s2.downloadZone(map: map, layers: [layer]);

          expect(d.calls, hasLength(2));
          expect(
            d.calls[0].iid,
            isNot(d.calls[1].iid),
            reason:
                'Two runs of the same zone must use different FMTC '
                'instance ids to avoid "A download instance with ID ... '
                'already exists".',
          );
        },
      );

      test(
        'preCancelInstanceId is forwarded to the downloader as the previous run id',
        () async {
          final d = FakeLayerDownloader();
          final s2 = ZoneDownloadService(repository: repo, downloader: d);
          final map = _m('pre-cancel');
          repo.save(map);
          final layer = _l(LayerType.marine25k);
          repo.saveLayer(map, layer);

          // Run 1: no pre-cancel (no prior instance).
          await s2.downloadZone(map: map, layers: [layer]);
          // Run 2: must pre-cancel run-1's instance ('<uuid>#0') before starting.
          await s2.downloadZone(map: map, layers: [layer]);

          expect(
            d.preCancels,
            isNotEmpty,
            reason:
                'downloadZone must forward a pre-cancel id so FMTC cleans '
                'up orphan instances from a previous run.',
          );
          expect(d.preCancels.last.id, '${map.uuid}#0#marine25k');
          expect(d.preCancels.last.storeName, 'marine_zone_${map.uuid}');
        },
      );
    },
  );
}
