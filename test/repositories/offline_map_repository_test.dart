// Unit tests for OfflineMapRepository.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/objectbox.g.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';

OfflineMap _newMap(String uuid, String name) => OfflineMap.create(
      uuid: uuid, name: name,
      northLat: 44.0, southLat: 43.0,
      westLng: 6.0, eastLng: 7.5,
    );

OfflineMapLayer _newLayer(LayerType t, int zmin, int zmax) =>
    OfflineMapLayer.create(layerType: t, minZoom: zmin, maxZoom: zmax);

void main() {
  late Directory tmpDir;
  late Store store;
  late OfflineMapRepository repo;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('offline_map_test_');
    store = await openStore(directory: tmpDir.path);
    repo = OfflineMapRepository(store);
  });

  tearDown(() async {
    store.close();
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group("OfflineMap CRUD", () {
    test("save assigns a new id and findById retrieves it", () {
      final saved = repo.save(_newMap("uuid-1", "Cote"));
      expect(saved.id, isNot(0));
      final fetched = repo.findById(saved.id);
      expect(fetched, isNotNull);
      expect(fetched!.uuid, "uuid-1");
      expect(fetched.name, "Cote");
      expect(fetched.status, OfflineMapStatus.notStarted);
      expect(fetched.isNotStarted, isTrue);
      expect(fetched.isCompleted, isFalse);
    });
  });

  group("markCompleted / isCompleted", () {
    test("markCompleted sets status to ready and updates completedAt", () {
      final saved = repo.save(_newMap("uuid-complete", "Map"));
      expect(saved.isCompleted, isFalse);
      saved.markCompleted();
      repo.save(saved);
      final fetched = repo.findById(saved.id);
      expect(fetched!.isCompleted, isTrue);
      expect(fetched.isReady, isTrue);
      expect(fetched.completedAt.millisecondsSinceEpoch, greaterThan(0));
    });
  });

  group("OfflineMapLayer CRUD", () {
    test("saveLayer links a layer to a map via offlineMapId", () {
      final map = repo.save(_newMap("m-uuid", "Parent"));
      final savedLayer = repo.saveLayer(map, _newLayer(LayerType.marine25k, 8, 14));
      expect(savedLayer.id, isNot(0));
      expect(savedLayer.offlineMapId, map.id);
      expect(savedLayer.isPending, isTrue);
    });

    test("findLayersForMap returns only layers of the given map", () {
      final m1 = repo.save(_newMap("m1", "Map 1"));
      final m2 = repo.save(_newMap("m2", "Map 2"));
      repo.saveLayer(m1, _newLayer(LayerType.marine50k, 6, 12));
      repo.saveLayer(m1, _newLayer(LayerType.marine25k, 8, 14));
      repo.saveLayer(m2, _newLayer(LayerType.marine10k, 12, 16));
      final layersOfM1 = repo.findLayersForMap(m1);
      expect(layersOfM1.length, 2);
      expect(layersOfM1.every((l) => l.offlineMapId == m1.id), isTrue);
      final layersOfM2 = repo.findLayersForMap(m2);
      expect(layersOfM2.length, 1);
      expect(layersOfM2.first.layerType, LayerType.marine10k);
    });

    test("findLayerById retrieves a layer by id", () {
      final map = repo.save(_newMap("m", "M"));
      final layer = repo.saveLayer(map, _newLayer(LayerType.marine25k, 8, 14));
      final fetched = repo.findLayerById(layer.id);
      expect(fetched, isNotNull);
      expect(fetched!.layerType, LayerType.marine25k);
    });

    test("deleteLayer removes a single layer", () {
      final map = repo.save(_newMap("m", "M"));
      final layer = repo.saveLayer(map, _newLayer(LayerType.marine50k, 6, 12));
      expect(repo.layerCount, 1);
      final ok = repo.deleteLayer(layer.id);
      expect(ok, isTrue);
      expect(repo.layerCount, 0);
      expect(repo.findLayerById(layer.id), isNull);
    });
  });

  group("Cascading delete", () {
    test("delete removes the map and its layers", () {
      final map = repo.save(_newMap("cascade-uuid", "Cascade"));
      repo.saveLayer(map, _newLayer(LayerType.marine25k, 8, 14));
      repo.saveLayer(map, _newLayer(LayerType.marine50k, 6, 12));
      expect(repo.mapCount, 1);
      expect(repo.layerCount, 2);
      final ok = repo.delete(map.id);
      expect(ok, isTrue);
      expect(repo.mapCount, 0);
      expect(repo.layerCount, 0);
    });

    test("delete returns false when map does not exist", () {
      expect(repo.delete(99999), isFalse);
    });

    test("deleteByUuid removes a map by uuid", () {
      final map = repo.save(_newMap("delete-by-uuid", "To delete"));
      final ok = repo.deleteByUuid("delete-by-uuid");
      expect(ok, isTrue);
      expect(repo.findById(map.id), isNull);
    });

    test("deleteByUuid returns false when uuid is unknown", () {
      expect(repo.deleteByUuid("unknown-uuid"), isFalse);
    });
  });

  group("LayerDownloadStatus transitions", () {
    test("set downloadStatus updates statusIndex", () {
      final layer = _newLayer(LayerType.marine25k, 8, 14);
      expect(layer.isPending, isTrue);
      layer.downloadStatus = LayerDownloadStatus.downloading;
      expect(layer.isDownloading, isTrue);
      layer.downloadStatus = LayerDownloadStatus.completed;
      expect(layer.isCompleted, isTrue);
      expect(layer.isPending, isFalse);
    });
  });
}
