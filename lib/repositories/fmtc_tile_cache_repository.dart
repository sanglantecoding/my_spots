// ignore: implementation_imports
// Accès interne FMTC requis pour la purge tuile-par-tuile (API publique absente).
// Cette dépendance est isolée dans ce fichier repository pour éviter la propagation
// dans le reste de la base de code.
import 'package:flutter_map_tile_caching/src/backend/export_internal.dart'
    as internal;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import 'tile_cache_repository.dart';

/// FMTC implementation of TileCacheRepository
/// Encapsulates FMTC internal API access behind a clean interface
class FmtcTileCacheRepository implements TileCacheRepository {
  FmtcTileCacheRepository._();

  static final FmtcTileCacheRepository _instance = FmtcTileCacheRepository._();

  /// Singleton instance
  static FmtcTileCacheRepository get instance => _instance;

  /// Concurrent `deleteTile` calls per batch — keeps ObjectBox responsive.
  static const int _purgeConcurrency = 8;

  @override
  Future<int> purgeTilesInBounds({
    required String storeName,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required String Function(int z, int x, int y) urlForTile,
    int tileDimension = 256,
  }) async {
    const crs = Epsg3857();
    final northWest = bounds.northWest;
    final southEast = bounds.southEast;
    var touched = 0;
    final pendingUrls = <String>[];

    Future<void> flushBatch() async {
      if (pendingUrls.isEmpty) return;
      final batch = List<String>.from(pendingUrls);
      pendingUrls.clear();
      final results = await Future.wait(
        batch.map((url) => _deleteTileSafely(storeName, url)),
        eagerError: false,
      );
      for (final removed in results) {
        if (removed) {
          touched++;
        }
      }
    }

    for (var zoom = minZoom; zoom <= maxZoom; zoom++) {
      final scale = zoom.toDouble();
      final nw = crs.latLngToXY(northWest, scale);
      final nwX = (nw.$1 / tileDimension).floor();
      final nwY = (nw.$2 / tileDimension).floor();
      final se = crs.latLngToXY(southEast, scale);
      final seX = (se.$1 / tileDimension).ceil() - 1;
      final seY = (se.$2 / tileDimension).ceil() - 1;

      for (var x = nwX; x <= seX; x++) {
        for (var y = nwY; y <= seY; y++) {
          pendingUrls.add(
            urlForTile(zoom, x, y),
          );
          if (pendingUrls.length >= _purgeConcurrency) {
            await flushBatch();
          }
        }
      }
    }

    await flushBatch();
    return touched;
  }

  /// API interne FMTC — seule méthode disponible pour une purge par emprise.
  Future<bool> _deleteTileSafely(String storeName, String url) async {
    try {
      // ignore: invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, experimental_member_use
      final removed = await internal.FMTCBackendAccess.internal.deleteTile(
        storeName: storeName,
        url: url,
      );
      return removed != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> clearLayerCache(String storeName) async {
    final store = FMTCStore(storeName);
    await store.manage.reset();
  }
}
