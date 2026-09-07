import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/zone_download_service.dart';
import 'package:my_spots/views/widgets/offline_maps/zone_list_tile.dart';

// In-memory fake: replaces OfflineMapRepository so tests avoid ObjectBox.
class FakeMapLayerRepository implements MapLayerRepository {
  final maps = <String, OfflineMap>{};
  final layers = <int, OfflineMapLayer>{};
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

  // --- cascade-test helpers ---
  bool deleteByUuidCalled = false;
  String? deletedUuid;
  bool deleteByUuid(String uuid) {
    deleteByUuidCalled = true;
    deletedUuid = uuid;
    final mapId = _mapIdByUuid(uuid);
    if (mapId == null) return false;
    maps.remove(uuid);
    layers.removeWhere((id, l) => l.offlineMapId == mapId);
    return true;
  }
  int? _mapIdByUuid(String uuid) => maps[uuid]?.id;
}

class FakeLayerDownloader implements LayerDownloader {
  @override
  Future<LayerDownloadResult> downloadLayer({
    required String zoneUuid, required FMTCStore store,
    required String instanceId,
    required String urlTemplate, required LatLngBounds bounds,
    required int minZoom, required int maxZoom,
    required Map<String, String> headers,
    required void Function(double) onProgress,
    String? preCancelInstanceId,
    FMTCStore? preCancelStore,
  }) async {
    onProgress(1.0);
    return const LayerDownloadResult(downloadedTileCount: 0, estimatedTileCount: 0, successful: true);
  }
  @override
  Future<void> cancel(String zoneUuid, FMTCStore store, String instanceId) async {}
  @override
  void pause(String zoneUuid, FMTCStore store, String instanceId) {}
  @override
  void resume(String zoneUuid, FMTCStore store, String instanceId) {}
}

OfflineMap _m(String u) => OfflineMap.create(uuid: u, name: 'Z', northLat: 44, southLat: 43, westLng: 6, eastLng: 7);
OfflineMapLayer _l(LayerType t) => OfflineMapLayer.create(layerType: t, minZoom: 8, maxZoom: 14);

void main() {
  group('ZoneListTile status display', () {
    OfflineMap makeMap({OfflineMapStatus status = OfflineMapStatus.notStarted}) {
      final map = _m('tile-${DateTime.now().microsecondsSinceEpoch}');
      map.status = status;
      return map;
    }

    testWidgets('displays zone name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ZoneListTile(
          map: makeMap(),
          layers: [_l(LayerType.marine50k)],
          progress: 0.0,
          isDownloading: false,
          activeLayerLabel: '',
          onDownload: () {},
          onCancel: () {},
          onPause: () {},
          onResume: () {},
          onDelete: () {},
        )),
      ));
      expect(find.text('Z'), findsOneWidget);
    });

    testWidgets('shows active layer label when downloading', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ZoneListTile(
          map: makeMap(),
          layers: [_l(LayerType.marine50k)],
          progress: 0.5,
          isDownloading: true,
          activeLayerLabel: 'Cartes 1:50 000',
          onDownload: () {},
          onCancel: () {},
          onPause: () {},
          onResume: () {},
          onDelete: () {},
        )),
      ));
      expect(find.textContaining('Cartes 1:50 000'), findsOneWidget);
    });

    testWidgets('shows LinearProgressIndicator when downloading', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ZoneListTile(
          map: makeMap(),
          layers: [_l(LayerType.marine50k)],
          progress: 0.75,
          isDownloading: true,
          activeLayerLabel: '',
          onDownload: () {},
          onCancel: () {},
          onPause: () {},
          onResume: () {},
          onDelete: () {},
        )),
      ));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows Supprimer button for every status', (tester) async {
      for (final status in OfflineMapStatus.values) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ZoneListTile(
            map: makeMap(status: status),
            layers: [_l(LayerType.marine50k)],
            progress: 0.0,
            isDownloading: false,
            activeLayerLabel: '',
            onDownload: () {},
            onCancel: () {},
            onPause: () {},
            onResume: () {},
            onDelete: () {},
          )),
        ));
        expect(find.text('Supprimer'), findsOneWidget);
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      }
    });
  });

  group('Cascade delete', () {
    test('deleteByUuid removes map and associated layers', () {
      final repo = FakeMapLayerRepository();
      final map = _m('cascade-test');
      repo.save(map);
      repo.saveLayer(map, _l(LayerType.marine50k));
      final deleted = repo.deleteByUuid(map.uuid);
      expect(deleted, isTrue);
      expect(repo.findByUuid(map.uuid), isNull);
      expect(repo.layers, isEmpty);
    });

    test('deleteByUuid returns false for non-existent map', () {
      final repo = FakeMapLayerRepository();
      expect(repo.deleteByUuid('non-existent-uuid'), isFalse);
    });
  });
}