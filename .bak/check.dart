import 'dart:io';
void main() {
  final path = r'C:\Users\JIM\my_spots\test\repositories\offline_map_repository_test.dart';
  final lines = File(path).readAsLinesSync();
  for (int i = 60; i < 65; i++) {
    print("$i: ${lines[i]}");
  }
  print("---");
  for (int i = 101; i < 106; i++) {
    print("$i: ${lines[i]}");
  }
}
