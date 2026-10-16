import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/services/mushroom/bounded_lru_cache.dart';
import 'package:my_spots/services/mushroom/point_key.dart';
import 'package:my_spots/services/mushroom/terrain_service.dart';

/// Implémentation V1 de [TerrainService].
///
/// - Source primaire : IGN Géoplateforme BD Alti® (métropole)
///   POST `https://data.geopf.fr/altimetrie/1.0/calcul/alti/rest/elevation.json`
/// - Fallback : Open-Elevation SRTM 30m (mondial)
///   POST `https://api.open-elevation.com/api/v1/lookup`
///
/// Pour chaque (lat,lng) on requête un patch 3×3 de points afin de calculer
/// localement la pente et l'exposition avec la méthode Horn.
///
/// Les calculs se font en local :
/// - pente (degrés) : `atan(sqrt(dzDx² + dzDy²)) * 180/π`
/// - aspect (degrés 0=Nord → 360°) : `atan2(-dzDx, dzDy)` converti en 0..360
/// - aspect = null si `slope < 1°` (terrain quasi plat, pas d'orientation signifiante)
///
/// Si un ou plusieurs points du patch 3×3 manquent (null / hors territoire)
/// ET que le manque empêche le calcul Horn, les champs `slope` et `aspect`
/// restent `null`. L'altitude centrale est quant à elle retournée si dispo.
class IgnOpenElevationTerrainService implements TerrainService {
  IgnOpenElevationTerrainService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _ignSource = 'ign_rge_alti_wld';
  static const _ignNoDataValue = -99999.0;
  static const _openElevationSource = 'srtm_open_elevation_30m';

  static const _ignBaseUrl =
      'https://data.geopf.fr/altimetrie/1.0/calcul/alti/rest/elevation.json';
  static const _openElevationUrl =
      'https://api.open-elevation.com/api/v1/lookup';

  /// Espacement du patch 3×3 en degrés.
  /// 0.00025° ≈ 27,8 m N-S, soit un voisinage cohérent entre SRTM 30 m
  /// et BD Alti 5 m pour une dérivée locale robuste.
  static const _cellSpacingDeg = 0.00025;

  /// Seuil sous lequel l'exposition est indéfinie (terrain plat).
  static const _flatSlopeThresholdDeg = 1.0;

  static const _cacheTtl = Duration(days: 30);
  static const _coordPrecision = 4; // ~11 m
  static const _maxPointsPerRequest = 5000;
  static const _maxSrtmPointsPerRequest = 100;
  static const _maxRequestsPerSecond = 4;
  static const _requestDelayMs = 1000 ~/ _maxRequestsPerSecond;
  static const _requestTimeout = Duration(seconds: 15);

  final BoundedLruCache<String, _CachedTerrain> _cache = BoundedLruCache(2000);
  Future<void>? _rateLimitQueue;

  String _cacheKey(double lat, double lng) {
    final latR = lat.toStringAsFixed(_coordPrecision);
    final lngR = lng.toStringAsFixed(_coordPrecision);
    return '$latR|$lngR';
  }

  /// Génère les 9 coordonnées du patch 3×3 autour de (lat,lng).
  /// Ordre en lecture (0→8) :
  ///   a(0) b(1) c(2)
  ///   d(3) e(4) f(5)
  ///   g(6) h(7) i(8)
  static List<(double lat, double lng)> patch3x3(double lat, double lng) {
    const s = _cellSpacingDeg;
    return [
      (lat + s, lng - s), // a
      (lat + s, lng), // b
      (lat + s, lng + s), // c
      (lat, lng - s), // d
      (lat, lng), // e (centre)
      (lat, lng + s), // f
      (lat - s, lng - s), // g
      (lat - s, lng), // h
      (lat - s, lng + s), // i
    ];
  }

  @override
  Future<TerrainData> getTerrainData({
    required double lat,
    required double lng,
  }) async {
    final key = _cacheKey(lat, lng);
    final now = DateTime.now();
    final cached = _cache[key];
    if (cached != null && now.difference(cached.fetchedAt) < _cacheTtl) {
      return cached.data;
    }

    final patch = patch3x3(lat, lng);
    final lats = patch.map((p) => p.$1).toList();
    final lngs = patch.map((p) => p.$2).toList();

    List<double?> elevations9;
    var noElevationData = false;
    String source;

    try {
      final ign = await _fetchIgn(lats, lngs);
      elevations9 = ign.elevations;
      source = _ignSource;
      if (ign.noElevationData[4]) {
        // IGN's sentinel can also mean outside its coverage. Confirm sea
        // level with SRTM before marking this location as having no data.
        try {
          final srtmElevations = await _fetchOpenElevation(lats, lngs);
          final srtmCenter = srtmElevations[4];
          if (srtmCenter == null) {
            elevations9[4] = null;
          } else {
            elevations9 = srtmElevations;
            source = _openElevationSource;
            if (srtmCenter <= 0) {
              elevations9[4] = 0;
              noElevationData = true;
            }
          }
        } catch (_) {
          // An unavailable confirmation source leaves altitude unknown.
          elevations9[4] = null;
        }
      }
    } on _ProviderUnavailableException {
      elevations9 = await _fetchOpenElevation(lats, lngs);
      source = _openElevationSource;
    }

    final centralElevation = elevations9[4];
    final derived = _deriveSlopeAspect(
      elevations9: elevations9,
      centerLat: lat,
    );

    final data = TerrainData(
      latitude: lat,
      longitude: lng,
      elevation: centralElevation,
      noElevationData: noElevationData,
      slope: derived.slopeDeg,
      aspect: derived.aspectDeg,
      source: source,
    );

    // Ne mettre en cache que si elevation != null ou noElevationData == true
    // (un échec réseau ne doit pas rester 30 jours en cache)
    if (centralElevation != null || noElevationData) {
      _cache[key] = _CachedTerrain(fetchedAt: now, data: data);
    }
    return data;
  }

  /// Charge les données de terrain pour plusieurs centres de cellules en batch.
  ///
  /// Construit tous les patchs 3×3, envoie des requêtes POST groupées (max 5000 points),
  /// respecte la limite de 4 requêtes/s, calcule pente/exposition localement, utilise
  /// le cache existant, et retente une fois les échecs via Open-Elevation.
  /// Pour les cellules où le point central n'a pas de données (code -99999),
  /// confirme avec SRTM en lot.
  @override
  Future<Map<String, TerrainData>> getTerrainBatch(
    List<LatLng> centers,
    double spacingMetres,
  ) async {
    final result = <String, TerrainData>{};
    final uncached = <(LatLng, String)>[]; // (center, outputKey)
    final now = DateTime.now();

    for (final center in centers) {
      final outputKey = mushroomViewportPointKey(center);
      final cacheKey = _cacheKey(center.latitude, center.longitude);
      final cached = _cache[cacheKey];
      if (cached != null && now.difference(cached.fetchedAt) < _cacheTtl) {
        result[outputKey] = cached.data;
      } else {
        uncached.add((center, outputKey));
      }
    }

    if (uncached.isEmpty) return result;

    final allPoints = <(double lat, double lng)>[];
    final centerToOutputKey = <LatLng, String>{};

    for (final (center, outputKey) in uncached) {
      centerToOutputKey[center] = outputKey;
      final patch = patch3x3(center.latitude, center.longitude);
      for (final point in patch) {
        allPoints.add(point);
      }
    }

    final batches = <List<(double lat, double lng)>>[];
    var currentBatch = <(double lat, double lng)>[];
    for (final point in allPoints) {
      currentBatch.add(point);
      if (currentBatch.length >= _maxPointsPerRequest) {
        batches.add(currentBatch);
        currentBatch = [];
      }
    }
    if (currentBatch.isNotEmpty) batches.add(currentBatch);

    final elevationsByPoint = <(double lat, double lng), double?>{};
    final noDataByPoint = <(double lat, double lng), bool>{};

    for (final batch in batches) {
      await _enforceRateLimit();
      try {
        final lats = batch.map((p) => p.$1).toList();
        final lngs = batch.map((p) => p.$2).toList();
        final ign = await _fetchIgn(lats, lngs);
        for (var i = 0; i < batch.length; i++) {
          elevationsByPoint[batch[i]] = ign.elevations[i];
          noDataByPoint[batch[i]] = ign.noElevationData[i];
        }
      } on _ProviderUnavailableException {
        final failedPoints = batch
            .where((p) => !elevationsByPoint.containsKey(p))
            .toList();
        if (failedPoints.isNotEmpty) {
          await _enforceRateLimit();
          try {
            final lats = failedPoints.map((p) => p.$1).toList();
            final lngs = failedPoints.map((p) => p.$2).toList();
            final srtm = await _fetchOpenElevation(lats, lngs);
            for (var i = 0; i < failedPoints.length; i++) {
              elevationsByPoint[failedPoints[i]] = srtm[i];
              noDataByPoint[failedPoints[i]] = false;
            }
          } catch (_) {
            for (final p in failedPoints) {
              elevationsByPoint.putIfAbsent(p, () => null);
              noDataByPoint.putIfAbsent(p, () => false);
            }
          }
        }
      } catch (_) {
        for (final p in batch) {
          elevationsByPoint.putIfAbsent(p, () => null);
          noDataByPoint.putIfAbsent(p, () => false);
        }
      }
    }

    final centersNeedingSrtm = <LatLng>[];
    for (final (center, _) in uncached) {
      final patch = patch3x3(center.latitude, center.longitude);
      final centralPoint = patch[4];
      final centralNoData = noDataByPoint[centralPoint] ?? false;
      if (centralNoData || elevationsByPoint[centralPoint] == null) {
        centersNeedingSrtm.add(center);
      }
    }

    if (centersNeedingSrtm.isNotEmpty) {
      final srtmBatches = <List<LatLng>>[];
      var currentSrtmBatch = <LatLng>[];
      for (final center in centersNeedingSrtm) {
        currentSrtmBatch.add(center);
        if (currentSrtmBatch.length >= _maxSrtmPointsPerRequest) {
          srtmBatches.add(currentSrtmBatch);
          currentSrtmBatch = [];
        }
      }
      if (currentSrtmBatch.isNotEmpty) srtmBatches.add(currentSrtmBatch);

      for (final srtmBatch in srtmBatches) {
        await _enforceRateLimit();
        try {
          final lats = srtmBatch.map((c) => c.latitude).toList();
          final lngs = srtmBatch.map((c) => c.longitude).toList();
          final srtm = await _fetchOpenElevation(lats, lngs);
          for (var i = 0; i < srtmBatch.length; i++) {
            final center = srtmBatch[i];
            final patch = patch3x3(center.latitude, center.longitude);
            final centralPoint = patch[4];
            elevationsByPoint[centralPoint] = srtm[i];
            noDataByPoint[centralPoint] = false;
          }
        } catch (_) {
          for (final center in srtmBatch) {
            final patch = patch3x3(center.latitude, center.longitude);
            final centralPoint = patch[4];
            elevationsByPoint.putIfAbsent(centralPoint, () => null);
            noDataByPoint.putIfAbsent(centralPoint, () => false);
          }
        }
      }
    }

    for (final (center, outputKey) in uncached) {
      try {
        final patch = patch3x3(center.latitude, center.longitude);
        final elevations9 = patch.map((p) => elevationsByPoint[p]).toList();
        final centralPoint = patch[4];
        final centralElevation = elevations9[4];
        final centralNoData = noDataByPoint[centralPoint] ?? false;
        final derived = _deriveSlopeAspect(
          elevations9: elevations9,
          centerLat: center.latitude,
        );

        String? source;
        bool noElevationData;

        if (centralElevation == null) {
          source = null;
          noElevationData = false;
        } else if (centralNoData) {
          if (centralElevation <= 0) {
            source = 'srtm_open_elevation_30m';
            noElevationData = true;
          } else {
            source = 'srtm_open_elevation_30m';
            noElevationData = false;
          }
        } else {
          source = 'ign_rge_alti_wld';
          noElevationData = false;
        }

        final data = TerrainData(
          latitude: center.latitude,
          longitude: center.longitude,
          elevation: centralElevation,
          noElevationData: noElevationData,
          slope: derived.slopeDeg,
          aspect: derived.aspectDeg,
          source: source,
        );
        final cacheKey = _cacheKey(center.latitude, center.longitude);
        // Ne mettre en cache que si elevation != null ou noElevationData == true
        if (centralElevation != null || noElevationData) {
          _cache[cacheKey] = _CachedTerrain(fetchedAt: now, data: data);
        }
        result[outputKey] = data;
      } catch (_) {
        final data = TerrainData(
          latitude: center.latitude,
          longitude: center.longitude,
          elevation: null,
          noElevationData: false,
          slope: null,
          aspect: null,
          source: null,
        );
        // Ne pas mettre en cache les échecs (elevation == null et noElevationData == false)
        result[outputKey] = data;
      }
    }

    return result;
  }

  Future<void> _enforceRateLimit() async {
    _rateLimitQueue = (_rateLimitQueue ?? Future.value()).then((_) async {
      await Future.delayed(Duration(milliseconds: _requestDelayMs));
    });
    await _rateLimitQueue;
  }

  // ────────────────── Appels HTTP ──────────────────

  /// Retourne N altitudes [double?] correspondant à l'ordre des points,
  /// dans le même ordre que [lats]/[lngs].
  /// Lève [_ProviderUnavailableException] si le provider est indisponible
  /// (HTTP 4xx/5xx, timeout, parsing impossible).
  Future<_ParsedIgnResponse> _fetchIgn(
    List<double> lats,
    List<double> lngs,
  ) async {
    final uri = Uri.parse(_ignBaseUrl);
    final body = jsonEncode(<String, dynamic>{
      'lon': lngs.join('|'),
      'lat': lats.join('|'),
      'resource': 'ign_rge_alti_wld',
      'delimiter': '|',
    });
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'my_spots/1.0 (Flutter)',
            'Accept': 'application/json',
          },
          body: body,
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw const _ProviderUnavailableException();
    }
    return _parseIgnResponseDetails(response.body, expectedPoints: lats.length);
  }

  Future<List<double?>> _fetchOpenElevation(
    List<double> lats,
    List<double> lngs,
  ) async {
    final uri = Uri.parse(_openElevationUrl);
    final locations = List<Map<String, double>>.generate(
      lats.length,
      (i) => {'latitude': lats[i], 'longitude': lngs[i]},
    );
    final body = jsonEncode(<String, dynamic>{'locations': locations});
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'my_spots/1.0 (Flutter)',
            'Accept': 'application/json',
          },
          body: body,
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw _ProviderUnavailableException(
        inner: http.ClientException(
          'Open-Elevation HTTP ${response.statusCode}',
          uri,
        ),
      );
    }
    return parseOpenElevationResponse(
      response.body,
      expectedPoints: lats.length,
    );
  }

  // ────────────────── Parsers publics (testables) ──────────────────

  /// Parse une réponse IGN et retourne les altitudes dans l'ordre de
  /// la requête d'entrée. Un point non retourné / z=null → `null`.
  static List<double?> parseIgnResponse(
    String body, {
    required int expectedPoints,
  }) {
    return _parseIgnResponseDetails(
      body,
      expectedPoints: expectedPoints,
    ).elevations;
  }

  static _ParsedIgnResponse _parseIgnResponseDetails(
    String body, {
    required int expectedPoints,
  }) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final elevations = json['elevations'] as List<dynamic>?;
    if (elevations == null) {
      return _ParsedIgnResponse(
        List<double?>.filled(expectedPoints, null),
        List<bool>.filled(expectedPoints, false),
      );
    }
    final result = List<double?>.filled(expectedPoints, null);
    final noData = List<bool>.filled(expectedPoints, false);
    final len = min(elevations.length, expectedPoints);
    for (var i = 0; i < len; i++) {
      final e = elevations[i];
      if (e is! Map<String, dynamic>) continue;
      final z = e['z'];
      if (z == null) continue;
      final value = (z as num).toDouble();
      if (value == _ignNoDataValue) {
        noData[i] = true;
      } else {
        result[i] = value;
      }
    }
    return _ParsedIgnResponse(result, noData);
  }

  /// Parse une réponse Open-Elevation en respectant l'ordre du patch
  /// fourni dans la requête (l'API renvoie un tableau `results` dans
  /// le même ordre que `locations`).
  static List<double?> parseOpenElevationResponse(
    String body, {
    required int expectedPoints,
  }) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>?;
    if (results == null) {
      return List<double?>.filled(expectedPoints, null);
    }
    final output = <double?>[];
    for (var i = 0; i < expectedPoints; i++) {
      final raw = i < results.length ? results[i] : null;
      if (raw is! Map<String, dynamic>) {
        output.add(null);
        continue;
      }
      final elev = raw['elevation'];
      output.add(elev == null ? null : (elev as num).toDouble());
    }
    return output;
  }

  // ────────────────── Calcul pente + aspect (Horn) ──────────────────

  static ({double? slopeDeg, double? aspectDeg}) _deriveSlopeAspect({
    required List<double?> elevations9,
    required double centerLat,
  }) {
    final a = elevations9[0];
    final b = elevations9[1];
    final c = elevations9[2];
    final d = elevations9[3];
    // e = centre, pas utilisé dans les gradients Horn
    final f = elevations9[5];
    final g = elevations9[6];
    final h = elevations9[7];
    final i = elevations9[8];

    if (a == null ||
        b == null ||
        c == null ||
        d == null ||
        f == null ||
        g == null ||
        h == null ||
        i == null) {
      return const (slopeDeg: null, aspectDeg: null);
    }

    // Tailles de cellule en mètres, localisées autour de centerLat.
    // 1° de latitude ≈ 111319,9 m (WGS84)
    const metersPerLatDeg = 111319.9;
    final metersPerLngDeg = metersPerLatDeg * cos(centerLat * pi / 180.0).abs();

    final cellSizeX = _cellSpacingDeg * metersPerLngDeg; // dimension E-W
    final cellSizeY = _cellSpacingDeg * metersPerLatDeg; // dimension N-S

    if (cellSizeX <= 0 || cellSizeY <= 0) {
      return const (slopeDeg: null, aspectDeg: null);
    }

    // Méthode Horn : poids 1 aux coins, 2 au centres des arêtes.
    final dzDx = ((c + 2 * f + i) - (a + 2 * d + g)) / (8 * cellSizeX);
    final dzDy = ((g + 2 * h + i) - (a + 2 * b + c)) / (8 * cellSizeY);

    final rise = sqrt(dzDx * dzDx + dzDy * dzDy);
    final slopeDeg = atan(rise) * (180.0 / pi);

    if (slopeDeg < _flatSlopeThresholdDeg) {
      return (slopeDeg: slopeDeg, aspectDeg: null);
    }

    // Aspect : 0 = Nord, 90 = Est, 180 = Sud, 270 = Ouest.
    // Formule standard : atan2(dzDx, -dzDy) dans [0, 360[.
    final aspectRad = atan2(dzDx, -dzDy);
    var aspectDeg = aspectRad * (180.0 / pi);
    if (aspectDeg < 0) aspectDeg += 360.0;
    if (aspectDeg >= 360.0) aspectDeg -= 360.0;

    return (slopeDeg: slopeDeg, aspectDeg: aspectDeg);
  }
}

class _CachedTerrain {
  _CachedTerrain({required this.fetchedAt, required this.data});
  final DateTime fetchedAt;
  final TerrainData data;
}

class _ParsedIgnResponse {
  const _ParsedIgnResponse(this.elevations, this.noElevationData);
  final List<double?> elevations;
  final List<bool> noElevationData;
}

class _ProviderUnavailableException implements Exception {
  const _ProviderUnavailableException({this.inner});
  final Object? inner;
}
