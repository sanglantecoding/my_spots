import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\test\repositories\offline_map_repository_test.dart';
  final existing = File(path).readAsStringSync();
  final lastBrace = existing.lastIndexOf('}');
  final before = existing.substring(0, lastBrace);

  final sb = StringBuffer(before);
  sb.writeln();
  sb.writeln('  group("Cascading delete", () {');
  sb.writeln('    test("delete removes the map and its layers", () {');
  sb.writeln('      final map = repo.save(_newMap("cascade-uuid", "Cascade"));');
  sb.writeln('      repo.saveLayer(map, _newLayer(LayerType.marine25k, 8, 14));');
  sb.writeln('      repo.saveLayer(map, _newLayer(LayerType.marine50k, 6, 12));');
  sb.writeln('      expect(repo.mapCount, 1);');
  sb.writeln('      expect(repo.layerCount, 2);');
  sb.writeln('      final ok = repo.delete(map.id);');
  sb.writeln('      expect(ok, isTrue);');
  sb.writeln('      expect(repo.mapCount, 0);');
  sb.writeln('      expect(repo.layerCount, 0);');
  sb.writeln('    });');
  sb.writeln();
  sb.writeln('    test("delete returns false when map does not exist", () {');
  sb.writeln('      expect(repo.delete(99999), isFalse);');
  sb.writeln('    });');
  sb.writeln();
  sb.writeln('    test("deleteByUuid removes a map by uuid", () {');
  sb.writeln('      final map = repo.save(_newMap("delete-by-uuid", "To delete"));');
  sb.writeln('      final ok = repo.deleteByUuid("delete-by-uuid");');
  sb.writeln('      expect(ok, isTrue);');
  sb.writeln('      expect(repo.findById(map.id), isNull);');
  sb.writeln('    });');
  sb.writeln();
  sb.writeln('    test("deleteByUuid returns false when uuid is unknown", () {');
  sb.writeln('      expect(repo.deleteByUuid("unknown-uuid"), isFalse);');
  sb.writeln('    });');
  sb.writeln('  });');
  sb.writeln();
  sb.writeln('  group("LayerDownloadStatus transitions", () {');
  sb.writeln('    test("set downloadStatus updates statusIndex", () {');
  sb.writeln('      final layer = _newLayer(LayerType.marine25k, 8, 14);');
  sb.writeln('      expect(layer.isPending, isTrue);');
  sb.writeln('      layer.downloadStatus = LayerDownloadStatus.downloading;');
  sb.writeln('      expect(layer.isDownloading, isTrue);');
  sb.writeln('      layer.downloadStatus = LayerDownloadStatus.completed;');
  sb.writeln('      expect(layer.isCompleted, isTrue);');
  sb.writeln('      expect(layer.isPending, isFalse);');
  sb.writeln('    });');
  sb.writeln('  });');
  sb.writeln('}');

  File(path).writeAsStringSync(sb.toString());
  print('Added remaining groups');
}
