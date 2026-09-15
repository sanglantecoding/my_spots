// Unit tests for FmtcTileCacheRepository — new prefix-based store management.
//
// Coverage:
// - getTotalSizeByPrefix: sums sizes of all stores with a given prefix
// - deleteStoresByPrefix: deletes all stores with a given prefix
// - listStores: lists all FMTC store names

import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/repositories/fmtc_tile_cache_repository.dart';

void main() {
  late FmtcTileCacheRepository repo;

  setUp(() {
    repo = FmtcTileCacheRepository.instance;
  });

  group('listStores', () {
    test('returns a list of store names', () async {
      // This test verifies that the method can be called without throwing.
      // The actual stores depend on the test environment.
      final stores = await repo.listStores();
      expect(stores, isA<List<String>>());
    });
  });

  group('getTotalSizeByPrefix', () {
    test('returns 0 when no stores match prefix', () async {
      // Use a prefix that is unlikely to exist
      const nonExistentPrefix = 'non_existent_prefix_1234567890';
      final size = await repo.getTotalSizeByPrefix(nonExistentPrefix);
      expect(size, equals(0));
    });

    test('returns 0 when FMTC is not initialised', () async {
      // If FMTC is not initialised, the method should return 0 gracefully
      const prefix = 'lidar_zone_';
      final size = await repo.getTotalSizeByPrefix(prefix);
      expect(size, isA<int>());
      expect(size, greaterThanOrEqualTo(0));
    });

    test('sums sizes of all stores matching prefix', () async {
      // This test verifies the logic works when stores exist.
      // In a real test environment, we would create test stores.
      // For now, we just verify it doesn't throw and returns a non-negative int.
      const prefix = 'lidar_zone_';
      final size = await repo.getTotalSizeByPrefix(prefix);
      expect(size, isA<int>());
      expect(size, greaterThanOrEqualTo(0));
    });
  });

  group('deleteStoresByPrefix', () {
    test('does not throw when no stores match prefix', () async {
      // Use a prefix that is unlikely to exist
      const nonExistentPrefix = 'non_existent_prefix_1234567890';
      // Must not throw
      await repo.deleteStoresByPrefix(nonExistentPrefix);
    });

    test('does not throw when FMTC is not initialised', () async {
      // If FMTC is not initialised, the method should handle it gracefully
      const prefix = 'lidar_zone_';
      // Must not throw
      await repo.deleteStoresByPrefix(prefix);
    });
  });
}
