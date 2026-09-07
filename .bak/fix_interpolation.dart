import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\lib\services\map_tile_cache_service.dart';
  final content = File(path).readAsStringSync();

  // Fix the two concatenation → interpolation issues
  var updated = content.replaceAll(
    "FMTCStore('marine_zone_' + zoneUuid)",
    "FMTCStore('marine_zone_\$zoneUuid')",
  );
  updated = updated.replaceAll(
    "FMTCStore('lidar_zone_' + zoneUuid)",
    "FMTCStore('lidar_zone_\$zoneUuid')",
  );

  if (updated == content) {
    print('No changes needed');
  } else {
    File(path).writeAsStringSync(updated);
    print('Fixed interpolation');
  }
}
