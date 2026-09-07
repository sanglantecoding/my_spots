import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\test\services\map_tile_cache_service_test.dart';
  var content = File(path).readAsStringSync();

  // Replace the unescaped $uuid in test descriptions
  content = content.replaceAll(
    'pattern marine_zone_\$uuid',
    'pattern marine_zone_\\\u0024uuid', // -> marine_zone_\$uuid in output
  );
  content = content.replaceAll(
    'pattern lidar_zone_\$uuid',
    'pattern lidar_zone_\\\u0024uuid',
  );

  File(path).writeAsStringSync(content);
  print('Fixed');
}
