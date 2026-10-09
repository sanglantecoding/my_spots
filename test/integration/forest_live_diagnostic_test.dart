import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_spots/services/mushroom/overpass_forest_service.dart';

/// Sondes réseau à lancer explicitement avec RUN_LIVE_FOREST_DIAGNOSTIC=1.
void main() {
  const latitude = 43.57168;
  const longitude = 2.71746;
  final enabled = Platform.environment['RUN_LIVE_FOREST_DIAGNOSTIC'] == '1';

  test('Diagnostic Overpass forestier à La Salvetat-sur-Agout', () async {
    final client = _RecordingClient();
    final cache = await Directory.systemTemp.createTemp('forest_live_');
    try {
      final service = OverpassForestService(
        client: client,
        cacheDirectory: cache,
        fallbackEndpoint: null,
      );
      final data = await service.getForestData(lat: latitude, lng: longitude);
      final raw = jsonDecode(client.body!) as Map<String, dynamic>;
      final elements = raw['elements'] as List<dynamic>;
      final forestElements = elements.where((rawElement) {
        if (rawElement is! Map<String, dynamic>) return false;
        final tags = rawElement['tags'];
        return tags is Map &&
            (tags['landuse'] == 'forest' || tags['natural'] == 'wood');
      }).toList();
      final ways = forestElements.where(
        (element) => (element as Map)['type'] == 'way',
      );
      final relations = forestElements.where(
        (element) => (element as Map)['type'] == 'relation',
      );
      final incomplete = relations.where(_relationIncomplete).toList();
      // ignore: avoid_print
      print(
        'OVERPASS ${client.statusCode}: forestWays=${ways.length}, '
        'forestRelations=${relations.length}, '
        'incompleteRelations=${incomplete.length} '
        '${incomplete.map((e) => (e as Map)['id']).toList()}, '
        'tileAreas=${data.forestAreasInTile}, '
        'nearestBoundaryMeters=${data.nearestForestDistanceMeters}, '
        'isForest=${data.isForest}',
      );
    } finally {
      client.close();
      await cache.delete(recursive: true);
    }
  }, skip: !enabled);

  test('Sonde BD Forêt WFS Géoplateforme (aucune intégration)', () async {
    final client = http.Client();
    try {
      final capabilitiesUri = Uri.https('data.geopf.fr', '/wfs/ows', {
        'SERVICE': 'WFS',
        'REQUEST': 'GetCapabilities',
      });
      final capabilities = await client.get(capabilitiesUri);
      expect(capabilities.statusCode, 200);
      final names = RegExp(
        r'<(?:\w+:)?Name>([^<]+)</(?:\w+:)?Name>',
      ).allMatches(capabilities.body).map((match) => match[1]!).toList();
      final forestNames = names
          .where(
            (name) =>
                name.toUpperCase().contains('FORET') ||
                name.toUpperCase().contains('BDFORET'),
          )
          .toList();
      final formationLayer = names.cast<String?>().firstWhere(
        (name) => name?.toLowerCase().contains('formation_vegetale') ?? false,
        orElse: () => null,
      );
      // ignore: avoid_print
      print('WFS forest layer names: $forestNames');
      expect(formationLayer, isNotNull, reason: 'Couche végétale absente');
      final layer = formationLayer!;

      final schemaUri = Uri.https('data.geopf.fr', '/wfs/ows', {
        'SERVICE': 'WFS',
        'VERSION': '2.0.0',
        'REQUEST': 'DescribeFeatureType',
        'TYPENAMES': layer,
      });
      final schema = await client.get(schemaUri);
      // ignore: avoid_print
      print(
        'WFS DescribeFeatureType HTTP ${schema.statusCode}: ${schema.body}',
      );

      final point = await _queryFeature(client, layer, longitude, latitude);
      final body = jsonDecode(point.body) as Map<String, dynamic>;
      final features = body['features'] as List<dynamic>? ?? const [];
      // ignore: avoid_print
      print('WFS exact layer: $layer');
      // ignore: avoid_print
      print('WFS working request: ${_featureUri(layer, longitude, latitude)}');
      // ignore: avoid_print
      print(
        'WFS point features=${features.length}; '
        'attributes=${features.map((f) => (f as Map)['properties']).toList()}',
      );
      if (features.isEmpty) {
        final unfilteredUri = Uri.https('data.geopf.fr', '/wfs/ows', {
          'SERVICE': 'WFS',
          'VERSION': '2.0.0',
          'REQUEST': 'GetFeature',
          'TYPENAMES': layer,
          'OUTPUTFORMAT': 'application/json',
          'COUNT': '1',
        });
        final unfiltered = await client.get(unfilteredUri);
        // ignore: avoid_print
        print(
          'WFS unfiltered sample HTTP ${unfiltered.statusCode}: ${unfiltered.body}',
        );
      }

      for (final sample in const [
        (name: 'Hérault', lat: 43.57168, lng: 2.71746),
        (name: 'Tarn / Lacaune', lat: 43.705, lng: 2.69),
      ]) {
        final response = await _queryFeature(
          client,
          layer,
          sample.lng,
          sample.lat,
        );
        final features =
            (jsonDecode(response.body) as Map<String, dynamic>)['features']
                as List<dynamic>? ??
            const [];
        // ignore: avoid_print
        print('WFS coverage ${sample.name}: ${features.length} feature(s)');
      }
    } finally {
      client.close();
    }
  }, skip: !enabled);
}

Future<http.Response> _queryFeature(
  http.Client client,
  String layer,
  double longitude,
  double latitude,
) {
  return client.get(_featureUri(layer, longitude, latitude));
}

Uri _featureUri(String layer, double longitude, double latitude) {
  final (x, y) = _lambert93(longitude, latitude);
  final cql = 'INTERSECTS(geom,POINT($x $y))';
  return Uri.https('data.geopf.fr', '/wfs/ows', {
    'SERVICE': 'WFS',
    'VERSION': '2.0.0',
    'REQUEST': 'GetFeature',
    'TYPENAMES': layer,
    'OUTPUTFORMAT': 'application/json',
    'COUNT': '10',
    'CQL_FILTER': cql,
  });
}

// Conversion WGS84 → Lambert-93 (EPSG:2154), CRS native de la couche.
(double, double) _lambert93(double longitude, double latitude) {
  const n = 0.7256077650532670;
  const c = 11754255.426096;
  const xs = 700000.0;
  const ys = 12655612.049876;
  const eccentricity = 0.0818191910428158;
  const lambda0 = 3 * 3.141592653589793 / 180;
  final phi = latitude * 3.141592653589793 / 180;
  final lambda = longitude * 3.141592653589793 / 180;
  final sinPhi = math.sin(phi);
  final isometricLatitude =
      math.log(math.tan(3.141592653589793 / 4 + phi / 2)) -
      eccentricity *
          math.log((1 + eccentricity * sinPhi) / (1 - eccentricity * sinPhi)) /
          2;
  final radius = c * math.exp(-n * isometricLatitude);
  final angle = n * (lambda - lambda0);
  return (xs + radius * math.sin(angle), ys - radius * math.cos(angle));
}

bool _relationIncomplete(dynamic raw) {
  if (raw is! Map<String, dynamic> || raw['members'] is! List) return true;
  final members = raw['members'] as List;
  final outer = members.whereType<Map>().where(
    (member) => member['role'] == 'outer',
  );
  if (outer.isEmpty || outer.any((member) => member['geometry'] is! List)) {
    return true;
  }
  return false;
}

class _RecordingClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  String? body;
  int? statusCode;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    statusCode = response.statusCode;
    final bytes = await response.stream.toBytes();
    body = utf8.decode(bytes);
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      request: response.request,
      headers: response.headers,
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
