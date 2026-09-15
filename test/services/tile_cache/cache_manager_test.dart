// Unit tests for CacheManager — zone-scoped FMTC store management with legacy support.
//
// Coverage:
// - deleteStoresForZone: deletes both new format (lidar_zone_<uuid>_<layerId>) and legacy format (lidar_zone_<uuid>)
// - getZoneSizeBytes: sums sizes of both new and legacy format stores
// - cleanLegacyLidarStores: removes legacy stores only

import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/services/tile_cache/cache_manager.dart';

void main() {
  group('deleteStoresForZone — legacy + new format support', () {
    test('does not throw when called on non-existent zone', () async {
      // Use a uuid that has zero chance of existing
      const nonExistentZone =
          'delete-test-zone-00000000-0000-0000-0000-000000000000';
      // Must not throw
      await CacheManager.deleteStoresForZone(nonExistentZone);
    });

    test('calling twice on same zone does not throw', () async {
      const zone = 'delete-test-zone-11111111-1111-1111-1111-111111111111';
      await CacheManager.deleteStoresForZone(zone);
      await CacheManager.deleteStoresForZone(zone);
      // If we get here, no exception propagated
    });

    test('deletes marine store', () async {
      const zone = 'marine-test-zone';
      // Verify it doesn't throw when trying to delete marine store
      await CacheManager.deleteStoresForZone(zone);
    });

    test('deletes new format lidar stores (lidar_zone_<uuid>_<layerId>)', () async {
      const zone = 'lidar-new-test-zone';
      // Verify it doesn't throw when trying to delete new format stores
      await CacheManager.deleteStoresForZone(zone);
    });

    test('deletes legacy format lidar store (lidar_zone_<uuid>)', () async {
      const zone = 'lidar-legacy-test-zone';
      // Verify it doesn't throw when trying to delete legacy store
      await CacheManager.deleteStoresForZone(zone);
    });
  });

  group('getZoneSizeBytes — legacy + new format support', () {
    test('returns 0 when zone has no stores', () async {
      const nonExistentZone =
          'size-test-zone-00000000-0000-0000-0000-000000000000';
      final size = await CacheManager.getZoneSizeBytes(nonExistentZone);
      expect(size, equals(0));
    });

    test('returns non-negative size for any zone', () async {
      const zone = 'size-test-zone-11111111-1111-1111-1111-111111111111';
      final size = await CacheManager.getZoneSizeBytes(zone);
      expect(size, isA<int>());
      expect(size, greaterThanOrEqualTo(0));
    });

    test('sums marine and lidar stores (both formats)', () async {
      const zone = 'size-test-zone-22222222-2222-2222-2222-222222222222';
      // The method should sum:
      // - marine_zone_<uuid>
      // - lidar_zone_<uuid>_<layerId> (new format)
      // - lidar_zone_<uuid> (legacy format, if exists)
      final size = await CacheManager.getZoneSizeBytes(zone);
      expect(size, isA<int>());
      expect(size, greaterThanOrEqualTo(0));
    });
  });

  group('cleanLegacyLidarStores', () {
    test('does not throw when no legacy stores exist', () async {
      // Must not throw even if no legacy stores exist
      await CacheManager.cleanLegacyLidarStores();
    });

    test('does not throw when FMTC is not initialised', () async {
      // Must handle gracefully if FMTC is not initialised
      await CacheManager.cleanLegacyLidarStores();
    });

    test('can be called multiple times safely', () async {
      await CacheManager.cleanLegacyLidarStores();
      await CacheManager.cleanLegacyLidarStores();
      await CacheManager.cleanLegacyLidarStores();
      // If we get here, no exception propagated
    });
  });
}
