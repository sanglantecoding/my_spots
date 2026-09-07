import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\test\repositories\offline_map_repository_test.dart';
  final existing = File(path).readAsStringSync();
  // Find the last '}' of main() and remove it
  final lastBrace = existing.lastIndexOf('}');
  final before = existing.substring(0, lastBrace);

  final sb = StringBuffer(before);
  sb.writeln();
  sb.writeln('  group("OfflineMapLayer CRUD", () {');
  sb.writeln('    test("saveLayer links a layer to a map via offlineMapId", () {');
  sb.writeln('      final map = repo.save(_newMap("m-uuid", "Parent"));');
  sb.writeln('      final savedLayer = repo.saveLayer(map, _newLayer(LayerType.marine25k, 8, 14));');
  sb.writeln('      expect(savedLayer.id, isNot(0));');
  sb.writeln('      expect(savedLayer.offlineMapId, map.id);');
  sb.writeln('      expect(savedLayer.isPending, isTrue);');
  sb.writeln('    });');
  sb.writeln();
  sb.writeln('    test("findLayersForMap returns only layers of the given map", () {');
  sb.writeln('      final m1 = repo.save(_newMap("m1", "Map 1"));');
  sb.writeln('      final m2 = repo.save(_newMap("m2", "Map 2"));');
  sb.writeln('      repo.saveLayer(m1, _newLayer(LayerType.marine50k, 6, 12));');
  sb.writeln('      repo.saveLayer(m1, _newLayer(LayerType.lidarOmbrage, 10, 18));');
  sb.writeln('      repo.saveLayer(m2, _newLayer(LayerType.marine10k, 12, 16));');
  sb.writeln('      final layersOfM1 = repo.findLayersForMap(m1);');
  sb.writeln('      expect(layersOfM1.length, 2);');
  sb.writeln('      expect(layersOfM1.every((l) => l.offlineMapId == m1.id), isTrue);');
  sb.writeln('      final layersOfM2 = repo.findLayersForMap(m2);');
  sb.writeln('      expect(layersOfM2.length, 1);');
  sb.writeln('      expect(layersOfM2.first.layerType, LayerType.marine10k);');
  sb.writeln('    });');
  sb.writeln();
  sb.writeln('    test("findLayerById retrieves a layer by id", () {');
  sb.writeln('      final map = repo.save(_newMap("m", "M"));');
  sb.writeln('      final layer = repo.saveLayer(map, _newLayer(LayerType.marine25k, 8, 14));');
  sb.writeln('      final fetched = repo.findLayerById(layer.id);');
  sb.writeln('      expect(fetched, isNotNull);');
  sb.writeln('      expect(fetched!.layerType, LayerType.marine25k);');
  sb.writeln('    });');
  sb.writeln();
  sb.writeln('    test("deleteLayer removes a single layer", () {');
  sb.writeln('      final map = repo.save(_newMap("m", "M"));');
  sb.writeln('      final layer = repo.saveLayer(map, _newLayer(LayerType.marine50k, 6, 12));');
  sb.writeln('      expect(repo.layerCount, 1);');
  sb.writeln('      final ok = repo.deleteLayer(layer.id);');
  sb.writeln('      expect(ok, isTrue);');
  sb.writeln('      expect(repo.layerCount, 0);');
  sb.writeln('      expect(repo.findLayerById(layer.id), isNull);');
  sb.writeln('    });');
  sb.writeln('  });');
  sb.writeln('}');

  File(path).writeAsStringSync(sb.toString());
  print('Added OfflineMapLayer CRUD group');
}
