import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/services/mushroom/forest_service.dart';
import 'package:path_provider/path_provider.dart';

/// Données OSM par tuile, sans extrapoler les attributs forestiers absents.
class OverpassForestService implements ForestService {
  OverpassForestService({
    http.Client? client,
    Directory? cacheDirectory,
    Uri? endpoint,
    Uri? fallbackEndpoint,
    this.requestTimeout = const Duration(seconds: 25),
    this.retryBackoff = const [Duration(seconds: 1), Duration(seconds: 2)],
  }) : _client = client ?? http.Client(),
       _cacheDirectory = cacheDirectory,
       endpoint = endpoint ?? defaultEndpoint,
       fallbackEndpoint = fallbackEndpoint ?? defaultFallbackEndpoint;

  static const tileSizeDegrees = 0.05;

  /// Tolérance placeholder pour les lisières forestières et arbres isolés.
  static const forestEdgeToleranceMeters = 50.0;

  static final Uri defaultEndpoint = Uri.https(
    'overpass-api.de',
    '/api/interpreter',
  );
  static final Uri defaultFallbackEndpoint = Uri.https(
    'overpass.kumi.systems',
    '/api/interpreter',
  );

  static const _cacheTtl = Duration(days: 30);
  static const _userAgent = 'my_spots/1.0 (Flutter; mushroom habitat forecast)';

  final http.Client _client;
  final Directory? _cacheDirectory;
  final Uri endpoint;
  final Uri? fallbackEndpoint;
  final Duration requestTimeout;
  final List<Duration> retryBackoff;
  final Map<String, _TileRecord> _memoryCache = {};
  final Map<String, List<_Area>> _parsedCache = {};
  final Map<String, Future<_TileRecord?>> _inFlight = {};
  Future<void> _requestQueue = Future<void>.value();

  @override
  Future<ForestData> getForestData({
    required double lat,
    required double lng,
  }) async {
    final tile = _Tile.forPoint(lat, lng);
    try {
      final record = await _loadTile(tile);
      if (record == null) return _unknown(lat, lng);
      final parsed = _parsedCache.putIfAbsent(
        tile.key,
        () => _parseTile(record.body),
      );
      return _resolvePoint(lat, lng, parsed);
    } catch (_) {
      return _unknown(lat, lng);
    }
  }

  Future<_TileRecord?> _loadTile(_Tile tile) async {
    final key = tile.key;
    final cached = await _readCache(key);
    if (cached != null) return cached;
    if (AppSettings.offlineModeEnabled) return null;

    final pending = _inFlight[key];
    if (pending != null) return pending;
    final future = _downloadTile(tile);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }
  }

  Future<_TileRecord?> _readCache(String key) async {
    final now = DateTime.now();
    final memory = _memoryCache[key];
    if (memory != null && now.difference(memory.fetchedAt) <= _cacheTtl) {
      return memory;
    }
    _memoryCache.remove(key);
    _parsedCache.remove(key);

    try {
      final file = File(
        '${(await _getCacheDirectory()).path}${Platform.pathSeparator}$key.json',
      );
      if (!await file.exists()) return null;
      final modified = await file.lastModified();
      if (now.difference(modified) > _cacheTtl) {
        await file.delete();
        _parsedCache.remove(key);
        return null;
      }
      final record = _TileRecord(await file.readAsString(), modified);
      _memoryCache[key] = record;
      return record;
    } catch (_) {
      return null;
    }
  }

  Future<_TileRecord?> _downloadTile(_Tile tile) async {
    try {
      final body = await _withRequestLock(() => _fetchTile(tile));
      final record = _TileRecord(body, DateTime.now());
      _memoryCache[tile.key] = record;
      try {
        final directory = await _getCacheDirectory();
        final file = File(
          '${directory.path}${Platform.pathSeparator}${tile.key}.json',
        );
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(body, flush: true);
        if (await file.exists()) await file.delete();
        await temporary.rename(file.path);
      } catch (_) {
        // Un cache disque indisponible ne rend pas la réponse réseau inutilisable.
      }
      return record;
    } catch (_) {
      return null;
    }
  }

  Future<String> _fetchTile(_Tile tile) async {
    final endpoints = <Uri>[
      endpoint,
      if (fallbackEndpoint != null && fallbackEndpoint != endpoint)
        fallbackEndpoint!,
    ];
    final query = _buildQuery(tile);
    for (final uri in endpoints) {
      for (var attempt = 0; attempt <= retryBackoff.length; attempt++) {
        try {
          final response = await _client
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'User-Agent': _userAgent,
                  'Accept': 'application/json',
                },
                body: {'data': query},
              )
              .timeout(requestTimeout);
          if (response.statusCode == 200) {
            // Overpass peut renvoyer un JSON valide avec un champ `remark`
            // signalant une réponse partielle ou en échec. Ne jamais le
            // confondre avec une tuile vide ni la conserver en cache.
            final decoded = jsonDecode(response.body);
            if (decoded is! Map<String, dynamic> ||
                decoded.containsKey('remark') ||
                decoded['elements'] is! List) {
              throw const FormatException('Réponse Overpass incomplète');
            }
            return response.body;
          }
          if ((response.statusCode == 429 || response.statusCode == 504) &&
              attempt < retryBackoff.length) {
            await Future<void>.delayed(retryBackoff[attempt]);
            continue;
          }
          break;
        } catch (_) {
          break;
        }
      }
    }
    throw const HttpException(
      'Tous les endpoints Overpass sont indisponibles.',
    );
  }

  Future<T> _withRequestLock<T>(Future<T> Function() request) async {
    final previous = _requestQueue;
    final release = Completer<void>();
    _requestQueue = release.future;
    await previous;
    try {
      return await request();
    } finally {
      release.complete();
    }
  }

  String _buildQuery(_Tile tile) {
    final bbox = '${tile.south},${tile.west},${tile.north},${tile.east}';
    final selectors = <String>[
      for (final value in const [
        'forest',
        'residential',
        'industrial',
        'commercial',
        'retail',
      ]) ...[
        'way["landuse"="$value"]($bbox);',
        'relation["type"="multipolygon"]["landuse"="$value"]($bbox);',
      ],
      for (final value in const [
        'wood',
        'water',
        'beach',
        'sand',
        'desert',
        'glacier',
        'bare_rock',
        'scree',
      ]) ...[
        'way["natural"="$value"]($bbox);',
        'relation["type"="multipolygon"]["natural"="$value"]($bbox);',
      ],
    ];
    return '[out:json][timeout:20];(${selectors.join()});out geom tags;';
  }

  Future<Directory> _getCacheDirectory() async {
    final root =
        _cacheDirectory ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}mushroom_forest_tiles',
        );
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  static List<_Area> _parseTile(String body) {
    final document = jsonDecode(body) as Map<String, dynamic>;
    final elements = document['elements'] as List<dynamic>? ?? const [];
    final areas = <_Area>[];
    for (final raw in elements) {
      if (raw is! Map<String, dynamic>) continue;
      final tags = raw['tags'];
      if (tags is! Map) continue;
      final normalizedTags = tags.map(
        (key, value) => MapEntry('$key', '$value'),
      );
      if (raw['type'] == 'way') {
        final ring = _parseGeometry(raw['geometry']);
        if (_isClosed(ring)) {
          areas.add(_Area(normalizedTags, [_Polygon(ring, const [])]));
        }
      } else if (raw['type'] == 'relation' &&
          normalizedTags['type'] == 'multipolygon') {
        final members = raw['members'];
        areas.addAll(
          _parseMultipolygon(
            normalizedTags,
            members is List ? members : const [],
            relationId: '${raw['id'] ?? 'inconnu'}',
          ),
        );
      }
    }
    return areas;
  }

  static List<_Area> _parseMultipolygon(
    Map<String, String> tags,
    List<dynamic> members, {
    required String relationId,
  }) {
    final outerSegments = <List<_Coordinate>>[];
    final innerSegments = <List<_Coordinate>>[];
    var outerMemberCount = 0;
    var innerMemberCount = 0;
    for (final raw in members) {
      if (raw is! Map<String, dynamic>) continue;
      if (raw['role'] == 'outer') outerMemberCount++;
      if (raw['role'] == 'inner') innerMemberCount++;
      final geometry = _parseGeometry(raw['geometry']);
      if (geometry.length < 2) continue;
      if (raw['role'] == 'inner') {
        innerSegments.add(geometry);
      } else if (raw['role'] == 'outer') {
        outerSegments.add(geometry);
      }
    }
    final outerAssembly = _stitchRings(outerSegments);
    final innerAssembly = _stitchRings(innerSegments);
    final outers = outerAssembly.rings;
    final inners = innerAssembly.rings;
    final incompleteOuterCount =
        outerMemberCount -
        outerSegments.length +
        outerAssembly.incompleteSegments;
    final incompleteInnerCount =
        innerMemberCount -
        innerSegments.length +
        innerAssembly.incompleteSegments;
    if (outers.isEmpty ||
        incompleteOuterCount > 0 ||
        incompleteInnerCount > 0) {
      developer.log(
        'Relation multipolygon forestière incomplète: id=$relationId, '
        'outerMembers=$outerMemberCount, innerMembers=$innerMemberCount, '
        'outerRingsClosed=${outers.length}, innerRingsClosed=${inners.length}, '
        'outerSegmentsIncomplets=$incompleteOuterCount, '
        'innerSegmentsIncomplets=$incompleteInnerCount',
        name: 'OverpassForestService',
        level: 900,
      );
    }
    final polygons = <_Polygon>[];
    for (final outer in outers) {
      final holes = inners.where((inner) => _insideRing(inner.first, outer));
      polygons.add(_Polygon(outer, holes.toList()));
    }
    return polygons.isEmpty ? [] : [_Area(tags, polygons)];
  }

  static ({List<List<_Coordinate>> rings, int incompleteSegments}) _stitchRings(
    List<List<_Coordinate>> input,
  ) {
    final segments = input.map(List<_Coordinate>.from).toList();
    final rings = <List<_Coordinate>>[];
    var incompleteSegments = 0;
    while (segments.isNotEmpty) {
      final ring = segments.removeAt(0);
      var changed = true;
      while (!_samePoint(ring.first, ring.last) && changed) {
        changed = false;
        for (var i = 0; i < segments.length; i++) {
          final candidate = segments[i];
          if (_samePoint(ring.last, candidate.first)) {
            ring.addAll(candidate.skip(1));
          } else if (_samePoint(ring.last, candidate.last)) {
            final reversed = candidate.reversed.toList();
            ring.addAll(reversed.skip(1));
          } else if (_samePoint(ring.first, candidate.last)) {
            ring.insertAll(0, candidate.take(candidate.length - 1));
          } else if (_samePoint(ring.first, candidate.first)) {
            final reversed = candidate.reversed.toList();
            ring.insertAll(0, reversed.take(reversed.length - 1));
          } else {
            continue;
          }
          segments.removeAt(i);
          changed = true;
          break;
        }
      }
      if (_isClosed(ring)) {
        rings.add(ring);
      } else {
        incompleteSegments++;
      }
    }
    return (rings: rings, incompleteSegments: incompleteSegments);
  }

  static List<_Coordinate> _parseGeometry(dynamic raw) {
    if (raw is! List) return [];
    final points = <_Coordinate>[];
    for (final point in raw) {
      if (point is! Map<String, dynamic>) continue;
      final lat = point['lat'];
      final lon = point['lon'];
      if (lat is num && lon is num) {
        points.add(_Coordinate(lat.toDouble(), lon.toDouble()));
      }
    }
    return points;
  }

  static bool _isClosed(List<_Coordinate> ring) =>
      ring.length >= 4 && _samePoint(ring.first, ring.last);

  static bool _samePoint(_Coordinate a, _Coordinate b) =>
      (a.lat - b.lat).abs() < 1e-9 && (a.lon - b.lon).abs() < 1e-9;

  static ForestData _resolvePoint(double lat, double lng, List<_Area> areas) {
    final point = _Coordinate(lat, lng);
    var forest = false;
    String? forestType;
    final coversAtPoint = <String>{};
    var urbanAtPoint = false;

    for (final area in areas) {
      final cover = _landCover(area.tags);
      final isForestArea = _isForest(area.tags);
      final contains = area.polygons.any((polygon) => polygon.contains(point));
      if (cover != null && cover != 'urban' && contains) {
        coversAtPoint.add(cover);
      }
      if (isForestArea) {
        final inForest = area.polygons.any(
          (polygon) => polygon.contains(point),
        );
        final nearEdge = area.polygons.any(
          (polygon) => polygon.nearOuterEdge(point, forestEdgeToleranceMeters),
        );
        if (inForest || nearEdge) {
          forest = true;
          forestType ??= _mapLeafType(area.tags['leaf_type']);
        }
      }
      if (cover == 'urban' && contains) urbanAtPoint = true;
    }

    String? prioritizedCover;
    for (final cover in const [
      'water',
      'beach',
      'desert',
      'glacier',
      'bare_rock',
    ]) {
      if (coversAtPoint.contains(cover)) {
        prioritizedCover = cover;
        break;
      }
    }

    return ForestData(
      latitude: lat,
      longitude: lng,
      isForest: forest,
      forestType: forestType,
      treeDensity: null,
      canopyCover: null,
      landCover: prioritizedCover ?? (urbanAtPoint && !forest ? 'urban' : null),
      source: 'osm_overpass',
    );
  }

  static bool _isForest(Map<String, String> tags) =>
      tags['landuse'] == 'forest' || tags['natural'] == 'wood';

  static String? _mapLeafType(String? leafType) => switch (leafType) {
    'broadleaved' => 'feuillu',
    'needleleaved' => 'conifère',
    'mixed' => 'mixte',
    _ => null,
  };

  static String? _landCover(Map<String, String> tags) {
    final natural = tags['natural'];
    if (natural == 'water') return 'water';
    if (natural == 'beach' || natural == 'sand') return 'beach';
    if (natural == 'desert') return 'desert';
    if (natural == 'glacier') return 'glacier';
    if (natural == 'bare_rock' || natural == 'scree') return 'bare_rock';
    if (const {
      'residential',
      'industrial',
      'commercial',
      'retail',
    }.contains(tags['landuse'])) {
      return 'urban';
    }
    return null;
  }

  static ForestData _unknown(double lat, double lng) => ForestData(
    latitude: lat,
    longitude: lng,
    isForest: null,
    forestType: null,
    treeDensity: null,
    canopyCover: null,
    landCover: null,
    source: null,
  );
}

class _Tile {
  const _Tile(this.southIndex, this.westIndex);

  factory _Tile.forPoint(double lat, double lng) => _Tile(
    (lat / OverpassForestService.tileSizeDegrees).floor(),
    (lng / OverpassForestService.tileSizeDegrees).floor(),
  );

  final int southIndex;
  final int westIndex;
  double get south => southIndex * OverpassForestService.tileSizeDegrees;
  double get west => westIndex * OverpassForestService.tileSizeDegrees;
  double get north => south + OverpassForestService.tileSizeDegrees;
  double get east => west + OverpassForestService.tileSizeDegrees;
  String get key => '${southIndex}_$westIndex';
}

class _TileRecord {
  const _TileRecord(this.body, this.fetchedAt);
  final String body;
  final DateTime fetchedAt;
}

class _Coordinate {
  const _Coordinate(this.lat, this.lon);
  final double lat;
  final double lon;
}

class _Area {
  const _Area(this.tags, this.polygons);
  final Map<String, String> tags;
  final List<_Polygon> polygons;
}

class _Polygon {
  const _Polygon(this.outer, this.holes);
  final List<_Coordinate> outer;
  final List<List<_Coordinate>> holes;

  bool contains(_Coordinate point) =>
      _insideRing(point, outer) &&
      !holes.any((hole) => _insideRing(point, hole));

  bool nearOuterEdge(_Coordinate point, double toleranceMeters) {
    if (holes.any((hole) => _insideRing(point, hole))) return false;
    return _distanceToRingMeters(point, outer) <= toleranceMeters;
  }
}

bool _insideRing(_Coordinate point, List<_Coordinate> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    final crosses =
        (a.lat > point.lat) != (b.lat > point.lat) &&
        point.lon <
            (b.lon - a.lon) * (point.lat - a.lat) / (b.lat - a.lat) + a.lon;
    if (crosses) inside = !inside;
  }
  return inside;
}

double _distanceToRingMeters(_Coordinate point, List<_Coordinate> ring) {
  const metersPerLatitudeDegree = 111320.0;
  final metersPerLongitudeDegree =
      metersPerLatitudeDegree * math.cos(point.lat * math.pi / 180).abs();
  var minimum = double.infinity;
  for (var i = 0; i < ring.length - 1; i++) {
    final a = ring[i];
    final b = ring[i + 1];
    final ax = (a.lon - point.lon) * metersPerLongitudeDegree;
    final ay = (a.lat - point.lat) * metersPerLatitudeDegree;
    final bx = (b.lon - point.lon) * metersPerLongitudeDegree;
    final by = (b.lat - point.lat) * metersPerLatitudeDegree;
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0).toDouble();
    final x = ax + t * dx;
    final y = ay + t * dy;
    minimum = math.min(minimum, math.sqrt(x * x + y * y));
  }
  return minimum;
}
