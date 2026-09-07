import 'dart:io';
void main() {
  final path = r'C:\Users\JIM\my_spots\test\repositories\offline_map_repository_test.dart';
  final content = File(path).readAsStringSync();
  // Find the location of 'group("OfflineMapLayer CRUD"' to see surrounding chars
  final idx = content.indexOf('group("OfflineMapLayer CRUD"');
  print('Index: $idx');
  print('Chars around: ${content.substring(idx-5, idx+50).codeUnits}');
  print('Bytes: ${content.codeUnits.length}');

  // Check the line numbers directly
  final lines = content.split('\n');
  for (int i = 59; i < 65; i++) {
    print("Line $i: '${lines[i]}'");
    print("  codes: ${lines[i].codeUnits.take(40).toList()}");
  }
}
