import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\test\repositories\offline_map_repository_test.dart';
  final existing = File(path).readAsStringSync();
  // Remove trailing "});\n}"
  final trimmed = existing.substring(0, existing.length - 4);
  final buffer = StringBuffer(trimmed);

  buffer.writeln();
  buffer.writeln('  group("OfflineMapLayer CRUD", () {');
  buffer.writeln('    test("saveLayer links a layer to a map via offlineMapId", () {');
  buffer.writeln('      final map = repo.save(_newMap("m-uuid", "Parent"));');
  buffer.writeln('      final savedLayer = repo.saveLayer(map, _newLayer(LayerType.marine25k, 8, 14));');
  buffer.writeln('      expect(savedLayer.id, isNot(0));');
  buffer.writeln('      expect(savedLayer.offlineMapId, map.id);');
  buffer.writeln('      expect(savedLayer.isPending, isTrue);');
  buffer.writeln('    });');
  buffer.writeln();
  buffer.writeln('    test("findLayersForMap returns only layers of the given map", () {');
  buffer.writeln('      final m1 = repo.save(_newMap("m1", "Map 1"));');
  buffer.writeln('      final m2 = repo.save(_newMap("m2", "Map 2"));');
  buffer.writeln('      repo.saveLayer(m1, _newLayer(LayerType.marine50k, 6, 12));');
  buffer.writeln('      repo.saveLayer(m1, _newLayer(LayerType.lidarOmbrage, 10, 18));');
  buffer.writeln('      repo.saveLayer(m2, _newLayer(LayerType.marine10k, 12, 16));');
  buffer.writeln('      final layersOfM1 = repo.findLayersForMap(m1);');
  buffer.writeln('      expect(layersOfM1.length, 2);');
  buffer.writeln('      expect(layersOfM1.every((l) => l.offlineMapId == m1.id), isTrue);');
  buffer.writeln('      final layersOfM2 = repo.findLayersForMap(m2);');
  buffer.writeln('      expect(layersOfM2.length, 1);');
  buffer.writeln('      expect(layersOfM2.first.layerType, LayerType.marine10k);');
  buffer.writeln('    });');
  buffer.writeln();
  buffer.writeln('    test("findLayerById retrieves a layer by id", () {');
  buffer.writeln('      final map = repo.save(_newMap("m", "M"));');
  buffer.writeln('      final layer = repo.saveLayer(map, _newLayer(LayerType.marine25k, 8, 14));');
  buffer.writeln('      final fetched = repo.findLayerById(layer.id);');
  buffer.writeln('      expect(fetched, isNotNull);');
  buffer.writeln('      expect(fetched!.layerType, LayerType.marine25k);');
  buffer.writeln('    });');
  buffer.writeln();
  buffer.writeln('    test("deleteLayer removes a single layer", () {');
  buffer.writeln('      final map = repo.save(_newMap("m", "M"));');
  buffer.writeln('      final layer = repo.saveLayer(map, _newLayer(LayerType.marine50k, 6, 12));');
  buffer.writeln('      expect(repo.layerCount, 1);');
  buffer.writeln('      final ok = repo.deleteLayer(layer.id);');
  buffer.writeln('      expect(ok, isTrue);');
  buffer.writeln('      expect(repo.layerCount, 0);');
  buffer.writeln('      expect(repo.findLayerById(layer.id), isNull);');
  buffer.writeln('    });');
  buffer.writeln('  });');
  buffer.writeln('}');

  File(path).writeAsStringSync(buffer.toString());
  print('Appended OfflineMapLayer CRUD group');
}
