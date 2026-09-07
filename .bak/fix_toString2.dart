import 'dart:io';

void main() {
  // Fix offline_map.dart
  final path = r'C:\Users\JIM\my_spots\lib\models\offline_map.dart';
  var lines = File(path).readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains("'OfflineMap(id=\\")) {
      lines[i] = "  String toString() => 'OfflineMap(id=\$id, uuid=\$uuid, name=\$name, status=\${status.name})';";
      // Remove the next line (the broken continuation)
      if (i + 1 < lines.length && lines[i + 1].trim().startsWith("'")) {
        lines.removeAt(i + 1);
      }
      break;
    }
  }
  File(path).writeAsStringSync(lines.join('\n'));
  print('Fixed offline_map.dart toString');

  // Fix offline_map_layer.dart
  final path2 = r'C:\Users\JIM\my_spots\lib\models\offline_map_layer.dart';
  var lines2 = File(path2).readAsLinesSync();
  for (var i = 0; i < lines2.length; i++) {
    if (lines2[i].contains("'OfflineMapLayer(id=\\")) {
      lines2[i] = "  String toString() => 'OfflineMapLayer(id=\$id, type=\${layerType.name}, status=\${downloadStatus.name}, minZoom=\$minZoom, maxZoom=\$maxZoom, downloaded=\$downloadedTileCount/\$estimatedTileCount)';";
      if (i + 1 < lines2.length && lines2[i + 1].trim().startsWith("'")) {
        lines2.removeAt(i + 1);
      }
      break;
    }
  }
  File(path2).writeAsStringSync(lines2.join('\n'));
  print('Fixed offline_map_layer.dart toString');
}
