import 'package:flutter_map/flutter_map.dart';

/// Repository interface for tile cache operations
/// Abstracts FMTC internal dependencies behind a clean API
abstract class TileCacheRepository {
  /// Deletes tiles within the specified bounds from a store
  ///
  /// Parameters:
  /// - storeName: The FMTC store name
  /// - bounds: Geographic bounds to delete tiles within
  /// - minZoom: Minimum zoom level to delete
  /// - maxZoom: Maximum zoom level to delete
  /// - urlForTile: Function that generates tile URLs for given z, x, y coordinates
  /// - tileDimension: Tile size in pixels (default 256)
  ///
  /// Returns the number of tiles deleted
  Future<int> purgeTilesInBounds({
    required String storeName,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required String Function(int z, int x, int y) urlForTile,
    int tileDimension = 256,
  });

  /// Clears all tiles from a specific store
  Future<void> clearLayerCache(String storeName);
}
