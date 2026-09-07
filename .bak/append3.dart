import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\test\repositories\offline_map_repository_test.dart';
  final existing = File(path).readAsStringSync();
  final trimmed = existing.substring(0, existing.length - 4);
  final buffer = StringBuffer(trimmed);

  buffer.writeln();
  buffer.writeln('  group("Cascading delete", () {');
  buffer.writeln('    test("delete removes the map and its layers", () {');
  buffer.writeln('      final map = repo.save(_newMap("cascade-uuid", "Cascade"));');
  buffer.writeln('      repo.saveLayer(map, _newLayer(LayerType.marine25k, 8, 14));');
  buffer.writeln('      repo.saveLayer(map, _newLayer(LayerType.marine50k, 6, 12));');
  buffer.writeln('      expect(repo.mapCount, 1);');
  buffer.writeln('      expect(repo.layerCount, 2);');
  buffer.writeln('      final ok = repo.delete(map.id);');
  buffer.writeln('      expect(ok, isTrue);');
  buffer.writeln('      expect(repo.mapCount, 0);');
  buffer.writeln('      expect(repo.layerCount, 0);');
  buffer.writeln('    });');
  buffer.writeln();
  buffer.writeln('    test("delete returns false when map does not exist", () {');
  buffer.writeln('      expect(repo.delete(99999), isFalse);');
  buffer.writeln('    });');
  buffer.writeln();
  buffer.writeln('    test("deleteByUuid removes a map by uuid", () {');
  buffer.writeln('      final map = repo.save(_newMap("delete-by-uuid", "To delete"));');
  buffer.writeln('      final ok = repo.deleteByUuid("delete-by-uuid");');
  buffer.writeln('      expect(ok, isTrue);');
  buffer.writeln('      expect(repo.findById(map.id), isNull);');
  buffer.writeln('    });');
  buffer.writeln();
  buffer.writeln('    test("deleteByUuid returns false when uuid is unknown", () {');
  buffer.writeln('      expect(repo.deleteByUuid("unknown-uuid"), isFalse);');
  buffer.writeln('    });');
  buffer.writeln('  });');
  buffer.writeln();
  buffer.writeln('  group("LayerDownloadStatus transitions", () {');
  buffer.writeln('    test("set downloadStatus updates statusIndex", () {');
  buffer.writeln('      final layer = _newLayer(LayerType.marine25k, 8, 14);');
  buffer.writeln('      expect(layer.isPending, isTrue);');
  buffer.writeln('      layer.downloadStatus = LayerDownloadStatus.downloading;');
  buffer.writeln('      expect(layer.isDownloading, isTrue);');
  buffer.writeln('      layer.downloadStatus = LayerDownloadStatus.completed;');
  buffer.writeln('      expect(layer.isCompleted, isTrue);');
  buffer.writeln('      expect(layer.isPending, isFalse);');
  buffer.writeln('    });');
  buffer.writeln('  });');
  buffer.writeln('}');

  File(path).writeAsStringSync(buffer.toString());
  print('Appended remaining groups');
}
