import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\test\repositories\offline_map_repository_test.dart';
  final bytes = File(path).readAsBytesSync();
  // Strip UTF-8 BOM (0xEF 0xBB 0xBF) if present at the start
  final clean = bytes.sublist(0, 3) == [0xEF, 0xBB, 0xBF]
      ? bytes.sublist(3)
      : bytes;
  // Strip any internal BOM sequences
  final cleanStr = String.fromCharCodes(clean).replaceAll('\uFEFF', '');
  File(path).writeAsStringSync(cleanStr);
  print('Stripped BOM. File length: ${cleanStr.length}');
}
