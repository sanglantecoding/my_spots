import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\test\repositories\offline_map_repository_test.dart';
  final existing = File(path).readAsStringSync();
  // Find the last '}' of main() and remove it
  final lastBrace = existing.lastIndexOf('}');
  final before = existing.substring(0, lastBrace);

  final sb = StringBuffer(before);

  // Add markCompleted group
  sb.writeln();
  sb.writeln('  group("markCompleted / isCompleted", () {');
  sb.writeln('    test("markCompleted sets status to ready and updates completedAt", () {');
  sb.writeln('      final saved = repo.save(_newMap("uuid-complete", "Map"));');
  sb.writeln('      expect(saved.isCompleted, isFalse);');
  sb.writeln('      saved.markCompleted();');
  sb.writeln('      repo.save(saved);');
  sb.writeln('      final fetched = repo.findById(saved.id);');
  sb.writeln('      expect(fetched!.isCompleted, isTrue);');
  sb.writeln('      expect(fetched.isReady, isTrue);');
  sb.writeln('      expect(fetched.completedAt.millisecondsSinceEpoch, greaterThan(0));');
  sb.writeln('    });');
  sb.writeln('  });');
  sb.writeln('}');

  File(path).writeAsStringSync(sb.toString());
  print('Updated: ${sb.length} chars');
}
