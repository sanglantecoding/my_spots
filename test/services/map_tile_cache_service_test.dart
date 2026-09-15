// Unit tests for MapTileCacheService — zone-scoped FMTC store management.
//
// Coverage:
// - Store naming per zone (marine + LiDAR)
// - deleteStoresForZone uses only public FMTC API
// - Graceful handling of absent stores (no throw on delete)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';

void main() {
  group("Zone store naming — marine", () {
    test("store name follows pattern marine_zone_\$uuid", () {
      const zoneUuid = "550e8400-e29b-41d4-a716-446655440000";
      final store = MapTileCacheService.marineStoreForZone(zoneUuid);
      expect(
        store.storeName,
        "marine_zone_550e8400-e29b-41d4-a716-446655440000",
      );
    });

    test("different uuids produce different store names", () {
      final s1 = MapTileCacheService.marineStoreForZone("zone-aaaa");
      final s2 = MapTileCacheService.marineStoreForZone("zone-bbbb");
      expect(s1.storeName, isNot(s2.storeName));
      expect(s1.storeName, endsWith("zone-aaaa"));
      expect(s2.storeName, endsWith("zone-bbbb"));
    });

    test("uuid with special characters is embedded verbatim", () {
      final store = MapTileCacheService.marineStoreForZone("my-map-01");
      expect(store.storeName, "marine_zone_my-map-01");
    });

    test("returned object is an FMTCStore instance", () {
      final store = MapTileCacheService.marineStoreForZone("test-zone");
      expect(store, isA<FMTCStore>());
    });
  });

  group("Zone store naming — lidar", () {
    test("store name follows pattern lidar_zone_\$uuid (legacy format)", () {
      const zoneUuid = "660e8400-e29b-41d4-a716-446655440001";
      final store = MapTileCacheService.lidarStoreForZone(zoneUuid);
      expect(
        store.storeName,
        "lidar_zone_660e8400-e29b-41d4-a716-446655440001",
      );
    });

    test("marine and lidar stores for same zone are distinct", () {
      const zoneUuid = "same-zone-uuid";
      final marine = MapTileCacheService.marineStoreForZone(zoneUuid);
      final lidar = MapTileCacheService.lidarStoreForZone(zoneUuid);
      expect(marine.storeName, isNot(lidar.storeName));
      expect(marine.storeName, startsWith("marine_zone_"));
      expect(lidar.storeName, startsWith("lidar_zone_"));
    });

    test("returned object is an FMTCStore instance", () {
      final store = MapTileCacheService.lidarStoreForZone("test-zone");
      expect(store, isA<FMTCStore>());
    });
  });

  group("deleteStoresForZone — public FMTC API compliance", () {
    // NOTE: We test that the method does NOT throw on absent stores.
    // This validates the try/catch around manage.delete() — the public
    // FMTC API. We use a guaranteed-unique store name so there is zero
    // risk of accidentally deleting real data.
    //
    // Even if FMTC is not initialised, manage.delete() throws
    // RootUnavailable, which our catch-all block handles silently.

    test("does not throw when called on non-existent zone", () async {
      // Use a uuid that has zero chance of existing
      const nonExistentZone =
          "delete-test-zone-00000000-0000-0000-0000-000000000000";
      // Must not throw
      await MapTileCacheService.deleteStoresForZone(nonExistentZone);
    });

    test("calling twice on same zone does not throw", () async {
      const zone = "delete-test-zone-11111111-1111-1111-1111-111111111111";
      await MapTileCacheService.deleteStoresForZone(zone);
      await MapTileCacheService.deleteStoresForZone(zone);
      // If we get here, no exception propagated
    });
  });

  group("offlineMarineTileProvider — strict zone-first fallback", () {
    // Regression test: the implementation uses cacheOnly for strict offline mode.
    // The general stores are never read (otherStoresStrategy: null).
    test("uses cacheOnly loading with no fallback for non-empty zones", () {
      final provider =
          MapTileCacheService.offlineMarineTileProvider(const ['zone-1'])
              as FMTCTileProvider;
      expect(provider.loadingStrategy, BrowseLoadingStrategy.cacheOnly);
      expect(provider.otherStoresStrategy, isNull);
      expect(provider.stores.keys, contains('marine_zone_zone-1'));
    });

    test("supports multiple zones simultaneously", () {
      final provider =
          MapTileCacheService.offlineMarineTileProvider(const [
                'zone-a',
                'zone-b',
                'zone-c',
              ])
              as FMTCTileProvider;
      expect(
        provider.stores.keys,
        containsAll([
          'marine_zone_zone-a',
          'marine_zone_zone-b',
          'marine_zone_zone-c',
        ]),
      );
      // Only the requested zones are listed as "explicit" stores.
      expect(provider.stores.length, 3);
    });

    test("empty zone list still returns a provider (legacy cache path)", () {
      // The non-zone path is a single-store provider for the legacy
      // 50K cache. We just verify it does not throw and is a FMTCTileProvider.
      final provider = MapTileCacheService.offlineMarineTileProvider(const []);
      expect(provider, isA<FMTCTileProvider>());
    });
  });

  group("offlineLidarTileProvider — strict zone-first fallback", () {
    test("uses cacheOnly loading with no fallback for non-empty zones", () {
      final provider =
          MapTileCacheService.offlineLidarTileProvider(const ['zone-1'])
              as FMTCTileProvider;
      expect(provider.loadingStrategy, BrowseLoadingStrategy.cacheOnly);
      expect(provider.otherStoresStrategy, isNull);
      expect(provider.stores.keys, contains('zone-1'));
    });

    test("empty zone list still returns a provider (single legacy store)", () {
      final provider = MapTileCacheService.offlineLidarTileProvider(const []);
      expect(provider, isA<FMTCTileProvider>());
    });
  });
}
