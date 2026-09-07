import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\test\repositories\offline_map_repository_test.dart';
  final existing = File(path).readAsStringSync();
  final content = existing.substring(0, existing.length - 2).trimRight();
  final buffer = StringBuffer(content);

  buffer.writeln();
  buffer.writeln('  group("markCompleted / isCompleted", () {');
  buffer.writeln('    test("markCompleted sets status to ready and updates completedAt", () {');
  buffer.writeln('      final saved = repo.save(_newMap("uuid-complete", "Map"));');
  buffer.writeln('      expect(saved.isCompleted, isFalse);');
  buffer.writeln('      saved.markCompleted();');
  buffer.writeln('      repo.save(saved);');
  buffer.writeln('      final fetched = repo.findById(saved.id);');
  buffer.writeln('      expect(fetched!.isCompleted, isTrue);');
  buffer.writeln('      expect(fetched.isReady, isTrue);');
  buffer.writeln('      expect(fetched.completedAt.millisecondsSinceEpoch, greaterThan(0));');
  buffer.writeln('    });');
  buffer.writeln('  });');
  buffer.writeln('}');

  File(path).writeAsStringSync(buffer.toString());
  print('Appended markCompleted group');
}
