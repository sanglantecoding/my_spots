import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:my_spots/models/mushroom/terrain_data.dart';
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
/// - aspect (degrés 0=Nord → 360°) : `atan2(dzDx, -dzDy)` converti en 0..360
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

  final Map<String, _CachedTerrain> _cache = {};

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

    _cache[key] = _CachedTerrain(fetchedAt: now, data: data);
    return data;
  }

  @override
  Future<double> getElevation({
    required double lat,
    required double lng,
  }) async {
    final data = await getTerrainData(lat: lat, lng: lng);
    final e = data.elevation;
    if (e == null) {
      throw StateError('Elevation unavailable at ($lat, $lng)');
    }
    return e;
  }

  // ────────────────── Appels HTTP ──────────────────

  /// Retourne 9 altitudes [double?] correspondant à l'ordre du patch 3×3,
  /// dans le même ordre que [lats]/[lngs].
  /// Lève [_ProviderUnavailableException] si le provider est indisponible
  /// (HTTP 4xx/5xx, timeout, parsing impossible).
  Future<_ParsedIgnResponse> _fetchIgn(
    List<double> lats,
    List<double> lngs,
  ) async {
    assert(lats.length == 9 && lngs.length == 9);
    final uri = Uri.parse(_ignBaseUrl);
    final body = jsonEncode(<String, dynamic>{
      'lon': lngs.join('|'),
      'lat': lats.join('|'),
      'resource': 'ign_rge_alti_wld',
      'delimiter': '|',
    });
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'my_spots/1.0 (Flutter)',
        'Accept': 'application/json',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw const _ProviderUnavailableException();
    }
    return _parseIgnResponseDetails(response.body, expectedPoints: 9);
  }

  Future<List<double?>> _fetchOpenElevation(
    List<double> lats,
    List<double> lngs,
  ) async {
    assert(lats.length == 9 && lngs.length == 9);
    final uri = Uri.parse(_openElevationUrl);
    final locations = List<Map<String, double>>.generate(
      9,
      (i) => {'latitude': lats[i], 'longitude': lngs[i]},
    );
    final body = jsonEncode(<String, dynamic>{'locations': locations});
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'my_spots/1.0 (Flutter)',
        'Accept': 'application/json',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw _ProviderUnavailableException(
        inner: http.ClientException(
          'Open-Elevation HTTP ${response.statusCode}',
          uri,
        ),
      );
    }
    return parseOpenElevationResponse(response.body, expectedPoints: 9);
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
