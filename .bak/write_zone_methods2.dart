import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\lib\services\map_tile_cache_service.dart';
  final existing = File(path).readAsStringSync();

  final lastBrace = existing.lastIndexOf('}');
  final before = existing.substring(0, lastBrace);

  final sb = StringBuffer(before);
  sb.writeln();
  sb.writeln('  // ─── Zone-scoped FMTC stores (one store per zone, per type) ───');
  sb.writeln();
  sb.writeln('  /// Returns the FMTC store dedicated to marine tiles for the given zone.');
  sb.writeln('  ///');
  sb.writeln('  /// Naming: `marine_zone_\$zoneUuid`.');
  sb.writeln('  ///');
  sb.writeln('  /// The caller is responsible for creating the store');
  sb.writeln('  /// ([FMTCStore.manage.create]) before downloading and for disposing');
  sb.writeln('  /// it via [deleteStoresForZone] when the zone is deleted.');
  sb.writeln('  static FMTCStore marineStoreForZone(String zoneUuid) =>');
  sb.writeln("      FMTCStore('marine_zone_' + zoneUuid);");
  sb.writeln();
  sb.writeln('  /// Returns the FMTC store dedicated to LiDAR tiles for the given zone.');
  sb.writeln('  ///');
  sb.writeln('  /// Naming: `lidar_zone_\$zoneUuid`.');
  sb.writeln('  ///');
  sb.writeln('  /// The caller is responsible for creating the store');
  sb.writeln('  /// ([FMTCStore.manage.create]) before downloading and for disposing');
  sb.writeln('  /// it via [deleteStoresForZone] when the zone is deleted.');
  sb.writeln('  static FMTCStore lidarStoreForZone(String zoneUuid) =>');
  sb.writeln("      FMTCStore('lidar_zone_' + zoneUuid);");
  sb.writeln();
  sb.writeln('  /// Deletes ALL FMTC stores associated with a zone (marine + LiDAR).');
  sb.writeln('  ///');
  sb.writeln('  /// Uses only the public FMTC API ([FMTCStore.manage.delete]) — no');
  sb.writeln('  /// direct calls to `FMTCBackendAccess.internal`.');
  sb.writeln('  ///');
  sb.writeln('  /// Silently ignores [StoreNotExists] errors (already absent).');
  sb.writeln('  static Future<void> deleteStoresForZone(String zoneUuid) async {');
  sb.writeln('    for (final store in [');
  sb.writeln('      marineStoreForZone(zoneUuid),');
  sb.writeln('      lidarStoreForZone(zoneUuid),');
  sb.writeln('    ]) {');
  sb.writeln('      try {');
  sb.writeln('        await store.manage.delete();');
  sb.writeln('      } catch (_) {');
  sb.writeln('        // StoreNotExists or already absent — ignore.');
  sb.writeln('      }');
  sb.writeln('    }');
  sb.writeln('  }');
  sb.writeln('}');

  File(path).writeAsStringSync(sb.toString());
  print('Updated MapTileCacheService: ${sb.length} chars');
}
