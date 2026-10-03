// ignore: implementation_imports
// Accès interne FMTC requis pour la purge tuile-par-tuile (API publique absente).
// Cette dépendance est isolée dans ce fichier repository pour éviter la propagation
// dans le reste de la base de code.
// ignore: implementation_imports
import 'package:flutter_map_tile_caching/src/backend/export_internal.dart'
    as internal;
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import 'tile_cache_repository.dart';

/// FMTC implementation of TileCacheRepository
/// Encapsulates FMTC internal API access behind a clean interface
class FmtcTileCacheRepository implements TileCacheRepository {
  FmtcTileCacheRepository._();

  static final FmtcTileCacheRepository _instance = FmtcTileCacheRepository._();

  /// Singleton instance
  static FmtcTileCacheRepository get instance => _instance;

  @override
  Future<void> clearLayerCache(String storeName) async {
    final store = FMTCStore(storeName);
    await store.manage.reset();
  }

  @override
  Future<int> getStoreSizeBytes(String storeName) async {
    try {
      final store = FMTCStore(storeName);
      final stats = await store.stats.all;
      return stats.size.toInt();
    } catch (_) {
      return 0;
    }
  }

  /// Returns the total size in bytes of all stores whose names start with [prefix].
  /// Uses FMTC internal API to list stores by prefix.
  Future<int> getTotalSizeByPrefix(String prefix) async {
    try {
      final storeNames = await listStores();
      var totalBytes = 0;
      for (final name in storeNames) {
        if (name.startsWith(prefix)) {
          totalBytes += await getStoreSizeBytes(name);
        }
      }
      return totalBytes;
    } catch (_) {
      return 0;
    }
  }

  /// Lists all FMTC store names using the internal API.
  Future<List<String>> listStores() async {
    try {
      // ignore: invalid_use_of_internal_member, experimental_member_use
      return await internal.FMTCBackendAccess.internal.listStores();
    } catch (_) {
      // Return empty list if FMTC is not initialised or listing fails
      return [];
    }
  }

  /// Deletes all stores whose names start with [prefix].
  /// Uses FMTC internal API to list stores by prefix.
  Future<void> deleteStoresByPrefix(String prefix) async {
    try {
      final storeNames = await listStores();
      for (final name in storeNames) {
        if (name.startsWith(prefix)) {
          try {
            final store = FMTCStore(name);
            await store.manage.delete();
          } catch (_) {
            // Ignore errors for individual stores
          }
        }
      }
    } catch (_) {
      // Ignore errors if listing fails
    }
  }
}
