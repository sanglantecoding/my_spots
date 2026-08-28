import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/shom_10k_catalog.dart';
import 'package:my_spots/models/shom_offline_region_state.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/services/marine_map_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Téléchargement hors-ligne RasterMarine 1:10 000 + relief LiDAR ombré (FMTC).
class ShomDownloadService {
  ShomDownloadService._();

  static const String wfsBaseUrl = 'https://services.data.shom.fr/netpub/wfs';
  static const String wfsLayer10k =
      'GRILLE_RASTER_MARINE:grille_assemblage_rm_10';

  static const int minDownloadZoom = 14;
  static const int maxDownloadZoom = 18;
  static const int avgTileBytesEstimate = 20 * 1024;

  static const Object marineDownloadInstanceId = 'shom10kOffline_marine';
  static const Object lidarDownloadInstanceId = 'shom10kOffline_lidar';

  static final Set<Object> _cancelRequestedIds = {};

  static const String _downloadedMarineIdsKey = 'shom10k_downloaded_region_ids';
  static const String _downloadedLidarIdsKey = 'shom10k_downloaded_lidar_ids';
  static const String _cacheSizesKey = 'shom10k_region_cache_sizes';

  static const String _inspireWmtsBase =
      'https://services.data.shom.fr/INSPIRE/wmts'
      '?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0'
      '&STYLE=normal'
      '&FORMAT=image/png'
      '&TILEMATRIXSET=3857'
      '&TILEMATRIX={z}&TILECOL={x}&TILEROW={y}';

  static String get _marineStoreName =>
      MapTileCacheService.marineStoreForLayer(MarineMapService.layer10k);

  static String get _lidarStoreName => MapTileCacheService.lidarOmbrageStore;

  static Future<Set<String>> loadDownloadedMarineIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_downloadedMarineIdsKey)?.toSet() ?? {};
  }

  static Future<Set<String>> loadDownloadedLidarIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_downloadedLidarIdsKey)?.toSet() ?? {};
  }

  static Future<Map<String, ShomRegionLayerSizes>> loadCacheSizes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheSizesKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((id, value) {
        final map = value as Map<String, dynamic>;
        return MapEntry(
          id,
          ShomRegionLayerSizes(
            marineBytes: (map['marine'] as num?)?.toInt() ?? 0,
            lidarBytes: (map['lidar'] as num?)?.toInt() ?? 0,
          ),
        );
      });
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveCacheSizes(
    Map<String, ShomRegionLayerSizes> sizes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = sizes.map(
      (id, s) => MapEntry(id, {'marine': s.marineBytes, 'lidar': s.lidarBytes}),
    );
    await prefs.setString(_cacheSizesKey, jsonEncode(payload));
  }

  static Future<Map<String, ShomRegionCacheStatus>> loadAllCacheStatuses(
    Iterable<String> regionIds,
  ) async {
    final marineIds = await loadDownloadedMarineIds();
    final lidarIds = await loadDownloadedLidarIds();
    final sizes = await loadCacheSizes();
    return {
      for (final id in regionIds)
        id: ShomRegionCacheStatus(
          marineDownloaded: marineIds.contains(id),
          lidarDownloaded: lidarIds.contains(id),
          marineBytes: sizes[id]?.marineBytes ?? 0,
          lidarBytes: sizes[id]?.lidarBytes ?? 0,
        ),
    };
  }

  static Future<void> _markMarineDownloaded(String regionId, int bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await loadDownloadedMarineIds()
      ..add(regionId);
    await prefs.setStringList(_downloadedMarineIdsKey, ids.toList());
    final sizes = await loadCacheSizes();
    sizes[regionId] = (sizes[regionId] ?? const ShomRegionLayerSizes())
        .copyWith(marineBytes: bytes);
    await _saveCacheSizes(sizes);
  }

  static Future<void> _markLidarDownloaded(String regionId, int bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await loadDownloadedLidarIds()
      ..add(regionId);
    await prefs.setStringList(_downloadedLidarIdsKey, ids.toList());
    final sizes = await loadCacheSizes();
    sizes[regionId] = (sizes[regionId] ?? const ShomRegionLayerSizes())
        .copyWith(lidarBytes: bytes);
    await _saveCacheSizes(sizes);
  }

  static Future<void> _unmarkMarineDownloaded(String regionId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await loadDownloadedMarineIds()
      ..remove(regionId);
    await prefs.setStringList(_downloadedMarineIdsKey, ids.toList());
    final sizes = await loadCacheSizes();
    final current = sizes[regionId];
    if (current != null) {
      sizes[regionId] = current.copyWith(marineBytes: 0);
      await _saveCacheSizes(sizes);
    }
  }

  static Future<void> _unmarkLidarDownloaded(String regionId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await loadDownloadedLidarIds()
      ..remove(regionId);
    await prefs.setStringList(_downloadedLidarIdsKey, ids.toList());
    final sizes = await loadCacheSizes();
    final current = sizes[regionId];
    if (current != null) {
      sizes[regionId] = current.copyWith(lidarBytes: 0);
      await _saveCacheSizes(sizes);
    }
  }

  static String _marineTileUrl(int z, int x, int y) {
    return MarineMapService.clevisuWmtsUrl(
      MarineMapService.layer10k,
    ).replaceAll('{z}', '$z').replaceAll('{x}', '$x').replaceAll('{y}', '$y');
  }

  static String _lidarTileUrl(int z, int x, int y) {
    return '$_inspireWmtsBase&LAYER=${MapTileCacheService.lidarOmbrageLayerName}'
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
  }

  static Future<int> purgeMarineCacheForRegion(Shom10kRegion region) async {
    final removed = await MapTileCacheService.purgeTilesInBounds(
      storeName: _marineStoreName,
      bounds: region.bounds,
      minZoom: minDownloadZoom,
      maxZoom: maxDownloadZoom,
      urlForTile: _marineTileUrl,
    );
    await _unmarkMarineDownloaded(region.id);
    return removed;
  }

  static Future<int> deleteLidarCacheForRegion(Shom10kRegion region) async {
    final removed = await MapTileCacheService.purgeTilesInBounds(
      storeName: _lidarStoreName,
      bounds: region.bounds,
      minZoom: minDownloadZoom,
      maxZoom: maxDownloadZoom,
      urlForTile: _lidarTileUrl,
    );
    await _unmarkLidarDownloaded(region.id);
    return removed;
  }

  static Future<int> estimateMarineBytes(Shom10kRegion region) async {
    final tiles = await estimateMarineTileCount(region);
    return tiles * avgTileBytesEstimate;
  }

  static Future<int> estimateLidarBytes(Shom10kRegion region) async {
    final tiles = await estimateLidarTileCount(region);
    return tiles * avgTileBytesEstimate;
  }

  static Future<int> estimateMarineTileCount(Shom10kRegion region) {
    return FMTCStore(
      _marineStoreName,
    ).download.countTiles(_downloadableFor(region, ShomOfflineLayer.marine));
  }

  static Future<int> estimateLidarTileCount(Shom10kRegion region) {
    return FMTCStore(
      _lidarStoreName,
    ).download.countTiles(_downloadableFor(region, ShomOfflineLayer.lidar));
  }

  static TileLayer _tileLayerOptions(ShomOfflineLayer layer) {
    return switch (layer) {
      ShomOfflineLayer.marine => TileLayer(
        urlTemplate: MarineMapService.clevisuWmtsUrl(MarineMapService.layer10k),
        userAgentPackageName: MapTileCacheService.packageName,
        minZoom: minDownloadZoom.toDouble(),
        maxZoom: maxDownloadZoom.toDouble(),
        minNativeZoom: 14,
        maxNativeZoom: 18,
        tileProvider: MapTileCacheService.marineTileProviderFor(
          MarineMapService.layer10k,
        ),
      ),
      ShomOfflineLayer.lidar => TileLayer(
        urlTemplate:
            '$_inspireWmtsBase&LAYER=${MapTileCacheService.lidarOmbrageLayerName}',
        userAgentPackageName: MapTileCacheService.packageName,
        minZoom: minDownloadZoom.toDouble(),
        maxZoom: maxDownloadZoom.toDouble(),
        minNativeZoom: 14,
        maxNativeZoom: 18,
        tileProvider: MapTileCacheService.lidarOmbrageTileProvider(),
      ),
    };
  }

  static DownloadableRegion _downloadableFor(
    Shom10kRegion region,
    ShomOfflineLayer layer,
  ) {
    return RectangleRegion(region.bounds).toDownloadable(
      minZoom: minDownloadZoom,
      maxZoom: maxDownloadZoom,
      options: _tileLayerOptions(layer),
    );
  }

  static int _bytesFromProgress(DownloadProgress progress) {
    return (progress.flushedTilesSize * 1024).round();
  }

  static Future<ShomDownloadResult> downloadPlans(
    List<ShomRegionDownloadPlan> plans, {
    void Function(
      Shom10kRegion region,
      ShomOfflineLayer layer,
      DownloadProgress progress,
    )?
    onProgress,
    void Function(Shom10kRegion region, ShomOfflineLayer layer)? onLayerStarted,
    void Function(Shom10kRegion region, ShomOfflineLayer layer)?
    onLayerCompleted,
    void Function(Shom10kRegion region, ShomOfflineLayer layer)? onLayerSkipped,
    void Function(Shom10kRegion region, ShomOfflineLayer layer, Object error)?
    onLayerFailed,
    bool Function(Shom10kRegion region, ShomOfflineLayer layer)?
    shouldDownloadLayer,
    bool skipExistingTiles = true,
    int rateLimit = 4,
  }) async {
    if (plans.isEmpty) return ShomDownloadResult.success;
    await MapTileCacheService.initialise();

    final keepLayer = shouldDownloadLayer ?? (_, _) => true;

    for (final plan in plans) {
      if (!plan.hasWork) continue;

      if (plan.downloadMarine &&
          keepLayer(plan.region, ShomOfflineLayer.marine)) {
        final result = await _downloadLayerForRegion(
          region: plan.region,
          layer: ShomOfflineLayer.marine,
          keepLayer: keepLayer,
          onProgress: onProgress,
          onLayerStarted: onLayerStarted,
          onLayerCompleted: onLayerCompleted,
          onLayerSkipped: onLayerSkipped,
          onLayerFailed: onLayerFailed,
          skipExistingTiles: skipExistingTiles,
          rateLimit: rateLimit,
        );
        if (!result.isSuccess) return result;
      } else if (plan.downloadMarine &&
          !keepLayer(plan.region, ShomOfflineLayer.marine)) {
        return ShomDownloadResult.cancelled;
      }

      if (plan.downloadLidar &&
          keepLayer(plan.region, ShomOfflineLayer.lidar)) {
        final result = await _downloadLayerForRegion(
          region: plan.region,
          layer: ShomOfflineLayer.lidar,
          keepLayer: keepLayer,
          onProgress: onProgress,
          onLayerStarted: onLayerStarted,
          onLayerCompleted: onLayerCompleted,
          onLayerSkipped: onLayerSkipped,
          onLayerFailed: onLayerFailed,
          skipExistingTiles: skipExistingTiles,
          rateLimit: rateLimit,
        );
        if (!result.isSuccess) return result;
      } else if (plan.downloadLidar &&
          !keepLayer(plan.region, ShomOfflineLayer.lidar)) {
        return ShomDownloadResult.cancelled;
      }
    }

    return ShomDownloadResult.success;
  }

  static Future<ShomDownloadResult> _downloadLayerForRegion({
    required Shom10kRegion region,
    required ShomOfflineLayer layer,
    required bool Function(Shom10kRegion region, ShomOfflineLayer layer)
    keepLayer,
    void Function(
      Shom10kRegion region,
      ShomOfflineLayer layer,
      DownloadProgress progress,
    )?
    onProgress,
    void Function(Shom10kRegion region, ShomOfflineLayer layer)? onLayerStarted,
    void Function(Shom10kRegion region, ShomOfflineLayer layer)?
    onLayerCompleted,
    void Function(Shom10kRegion region, ShomOfflineLayer layer)? onLayerSkipped,
    void Function(Shom10kRegion region, ShomOfflineLayer layer, Object error)?
    onLayerFailed,
    required bool skipExistingTiles,
    required int rateLimit,
  }) async {
    onLayerStarted?.call(region, layer);
    final storeName = layer == ShomOfflineLayer.marine
        ? _marineStoreName
        : _lidarStoreName;
    final instanceId = layer == ShomOfflineLayer.marine
        ? marineDownloadInstanceId
        : lidarDownloadInstanceId;

    if (_cancelRequestedIds.contains(instanceId) || !keepLayer(region, layer)) {
      await _purgePartialLayer(region, layer);
      onLayerSkipped?.call(region, layer);
      return ShomDownloadResult.cancelled;
    }

    try {
      final store = FMTCStore(storeName);
      final streams = store.download.startForeground(
        region: _downloadableFor(region, layer),
        skipExistingTiles: skipExistingTiles,
        skipSeaTiles: layer == ShomOfflineLayer.marine,
        rateLimit: rateLimit,
        instanceId: instanceId,
      );

      DownloadProgress? lastProgress;
      var cancelledByKeepLayer = false;

      await for (final progress in streams.downloadProgress) {
        if (!keepLayer(region, layer) ||
            _cancelRequestedIds.contains(instanceId)) {
          cancelledByKeepLayer = true;
          await cancelDownload(layer: layer);
          break;
        }
        lastProgress = progress;
        onProgress?.call(region, layer, progress);
      }

      final cancelled =
          cancelledByKeepLayer ||
          !keepLayer(region, layer) ||
          _cancelRequestedIds.contains(instanceId);

      if (cancelled) {
        await _purgePartialLayer(region, layer);
        onLayerSkipped?.call(region, layer);
        return ShomDownloadResult.cancelled;
      }

      final incomplete =
          lastProgress != null &&
          (lastProgress.remainingTilesCount > 0 ||
              lastProgress.failedTilesCount > 0 ||
              lastProgress.retryTilesQueuedCount > 0);
      if (lastProgress == null || incomplete) {
        final message = lastProgress == null
            ? 'Aucune progression de téléchargement reçue.'
            : lastProgress.failedTilesCount > 0
            ? 'Échec du téléchargement de ${lastProgress.failedTilesCount} tuile(s).'
            : 'Téléchargement incomplet (${lastProgress.remainingTilesCount} tuile(s) restante(s)).';
        await _purgePartialLayer(region, layer);
        onLayerFailed?.call(region, layer, message);
        return ShomDownloadResult.failed(message);
      }

      final bytes = _bytesFromProgress(lastProgress);

      if (layer == ShomOfflineLayer.marine) {
        await _markMarineDownloaded(region.id, bytes);
      } else {
        await _markLidarDownloaded(region.id, bytes);
      }
      onLayerCompleted?.call(region, layer);
      return ShomDownloadResult.success;
    } catch (error) {
      if (_cancelRequestedIds.contains(instanceId) ||
          _isCancellationError(error)) {
        await _purgePartialLayer(region, layer);
        onLayerSkipped?.call(region, layer);
        return ShomDownloadResult.cancelled;
      }
      await _purgePartialLayer(region, layer);
      onLayerFailed?.call(region, layer, error);
      return ShomDownloadResult.failed(error.toString());
    } finally {
      _cancelRequestedIds.remove(instanceId);
    }
  }

  static bool _isCancellationError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('cancelled') ||
        text.contains('canceled') ||
        text.contains('queuecancelledexception');
  }

  static Future<void> _purgePartialLayer(
    Shom10kRegion region,
    ShomOfflineLayer layer,
  ) async {
    try {
      if (layer == ShomOfflineLayer.marine) {
        await purgeMarineCacheForRegion(region);
      } else {
        await deleteLidarCacheForRegion(region);
      }
    } catch (_) {
      // Best-effort cleanup of an incomplete cache.
    }
  }

  static Future<void> cancelDownload({ShomOfflineLayer? layer}) async {
    if (layer == null || layer == ShomOfflineLayer.marine) {
      _cancelRequestedIds.add(marineDownloadInstanceId);
      await FMTCStore(
        _marineStoreName,
      ).download.cancel(instanceId: marineDownloadInstanceId);
    }
    if (layer == null || layer == ShomOfflineLayer.lidar) {
      _cancelRequestedIds.add(lidarDownloadInstanceId);
      await FMTCStore(
        _lidarStoreName,
      ).download.cancel(instanceId: lidarDownloadInstanceId);
    }
  }

  static Future<List<Shom10kRegion>> fetchOfficialShom10kCatalog({
    String? apiKey,
  }) async {
    try {
      final uri = Uri.parse(wfsBaseUrl).replace(
        queryParameters: {
          'service': 'WFS',
          'version': '2.0.0',
          'request': 'GetFeature',
          'typeNames': wfsLayer10k,
          'outputFormat': 'application/json',
          if (apiKey != null && apiKey.isNotEmpty) 'key': apiKey,
        },
      );

      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        request.headers.set(
          'User-Agent',
          MapTileCacheService.shomTileHeaders['User-Agent']!,
        );
        request.headers.set(
          'Referer',
          MapTileCacheService.shomTileHeaders['Referer']!,
        );
        request.headers.set('Accept', 'application/json');

        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('WFS HTTP ${response.statusCode}', uri: uri);
        }
        if (body.contains('ExceptionReport') || body.contains('Exception')) {
          throw FormatException('Réponse WFS invalide (clé API requise ?)');
        }

        final parsed = jsonDecode(body) as Map<String, dynamic>;
        final features = parsed['features'] as List<dynamic>? ?? [];
        final regions = <Shom10kRegion>[];

        for (var i = 0; i < features.length; i++) {
          final feature = features[i] as Map<String, dynamic>;
          final region = _regionFromGeoJsonFeature(feature, index: i);
          if (region != null) regions.add(region);
        }

        if (regions.isEmpty) {
          return Shom10kCatalog.allRegions;
        }

        return _mergeWithStaticCatalog(regions);
      } finally {
        client.close();
      }
    } catch (_) {
      return Shom10kCatalog.allRegions;
    }
  }

  static List<Shom10kRegion> _mergeWithStaticCatalog(
    List<Shom10kRegion> official,
  ) {
    final merged = <Shom10kRegion>[];

    for (final staticRegion in Shom10kCatalog.allRegions) {
      Shom10kRegion? match;
      for (final candidate in official) {
        if (_namesLikelyMatch(staticRegion.name, candidate.name)) {
          match = candidate;
          break;
        }
      }
      merged.add(
        Shom10kRegion(
          id: staticRegion.id,
          name: staticRegion.name,
          facade: staticRegion.facade,
          bounds: match?.bounds ?? staticRegion.bounds,
          shomGridId: match?.shomGridId ?? staticRegion.shomGridId,
          searchTerms: staticRegion.searchTerms,
        ),
      );
    }

    return merged;
  }

  static bool _namesLikelyMatch(String a, String b) {
    final na = a.toLowerCase().trim();
    final nb = b.toLowerCase().trim();
    return na.contains(nb) || nb.contains(na);
  }

  static Shom10kRegion? _regionFromGeoJsonFeature(
    Map<String, dynamic> feature, {
    required int index,
  }) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    if (geometry == null) return null;

    final bounds = _boundsFromGeometry(geometry);
    if (bounds == null) return null;

    final name =
        _firstNonEmptyString(properties, [
          'nom',
          'NOM',
          'name',
          'NAME',
          'titre',
          'TITRE',
          'libelle',
          'LIBELLE',
        ]) ??
        'Carte 1:10 000 ${index + 1}';

    final gridId = _firstNonEmptyString(properties, [
      'id',
      'ID',
      'id_grille',
      'ID_GRILLE',
      'numero',
      'NUMERO',
      'feuille',
      'FEUILLE',
    ]);

    return Shom10kRegion(
      id: 'wfs_${gridId ?? index}',
      name: name,
      facade: _guessFacade(bounds),
      bounds: bounds,
      shomGridId: gridId,
    );
  }

  static String? _firstNonEmptyString(
    Map<String, dynamic> properties,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = properties[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  static LatLngBounds? _boundsFromGeometry(Map<String, dynamic> geometry) {
    final type = geometry['type'] as String?;
    final coordinates = geometry['coordinates'];
    if (type == null || coordinates == null) return null;

    switch (type) {
      case 'Polygon':
        return _boundsFromPolygonCoordinates(coordinates);
      case 'MultiPolygon':
        if (coordinates is List && coordinates.isNotEmpty) {
          return _boundsFromPolygonCoordinates(coordinates.first);
        }
      case 'Point':
        if (coordinates is List && coordinates.length >= 2) {
          final lng = (coordinates[0] as num).toDouble();
          final lat = (coordinates[1] as num).toDouble();
          return LatLngBounds(
            LatLng(lat - 0.05, lng - 0.07),
            LatLng(lat + 0.05, lng + 0.07),
          );
        }
    }
    return null;
  }

  static LatLngBounds? _boundsFromPolygonCoordinates(Object coordinates) {
    if (coordinates is! List || coordinates.isEmpty) return null;
    final ring = coordinates.first;
    if (ring is! List) return null;

    var minLat = 90.0;
    var maxLat = -90.0;
    var minLng = 180.0;
    var maxLng = -180.0;

    for (final point in ring) {
      if (point is! List || point.length < 2) continue;
      final lng = (point[0] as num).toDouble();
      final lat = (point[1] as num).toDouble();
      minLat = lat < minLat ? lat : minLat;
      maxLat = lat > maxLat ? lat : maxLat;
      minLng = lng < minLng ? lng : minLng;
      maxLng = lng > maxLng ? lng : maxLng;
    }

    if (minLat >= maxLat || minLng >= maxLng) return null;
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  static Shom10kFacade _guessFacade(LatLngBounds bounds) {
    final lat = bounds.center.latitude;
    final lng = bounds.center.longitude;

    if (lat < 44.5 && lng > -2.0) {
      return Shom10kFacade.mediterraneeCorse;
    }
    if (lng < -1.5 && lat < 48.0) {
      return Shom10kFacade.atlantiqueSud;
    }
    if (lng < -3.5 && lat >= 47.0 && lat < 49.0) {
      return Shom10kFacade.bretagneSudPonant;
    }
    return Shom10kFacade.bretagneNordManche;
  }
}
