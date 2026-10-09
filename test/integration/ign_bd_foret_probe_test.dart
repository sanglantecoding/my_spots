import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Probe manuelle uniquement : RUN_LIVE_BDFORET_PROBE=1 flutter test
/// --plain-name "Sonde BD Forêt V2" test/integration/ign_bd_foret_probe_test.dart
void main() {
  test(
    'Sonde BD Forêt V2 : couche et ordre des axes WFS 2.0',
    () async {
      const latitude = 43.57158;
      const longitude = 2.71777;
      final client = http.Client();
      try {
        final capabilitiesUri = Uri.https('data.geopf.fr', '/wfs/ows', {
          'SERVICE': 'WFS',
          'VERSION': '2.0.0',
          'REQUEST': 'GetCapabilities',
        });
        final capabilities = await client.get(capabilitiesUri);
        expect(capabilities.statusCode, 200);
        final names = RegExp(
          r'<(?:\w+:)?Name>([^<]+)</(?:\w+:)?Name>',
        ).allMatches(capabilities.body).map((match) => match[1]!).toList();
        final forestLayers = names
            .where(
              (name) =>
                  name.toUpperCase().contains('FORET') ||
                  name.toUpperCase().contains('BDFORET'),
            )
            .toList();
        final layer = names.firstWhere(
          (name) => name == 'LANDCOVER.FORESTINVENTORY.V2:formation_vegetale',
          orElse: () => '',
        );
        // ignore: avoid_print
        print('BDFORET_CAPABILITIES_HTTP=${capabilities.statusCode}');
        // ignore: avoid_print
        print('BDFORET_RELATED_LAYERS=$forestLayers');
        // ignore: avoid_print
        print('BDFORET_FORMATION_LAYER=$layer');
        expect(layer, isNotEmpty, reason: 'Couche formation_vegetale absente');

        final correctWatch = Stopwatch()..start();
        final correct = await client.get(
          _pointQuery(layer, latitude: latitude, longitude: longitude),
        );
        correctWatch.stop();
        expect(correct.statusCode, 200, reason: correct.body);
        final correctFeatures = _features(correct.body);
        // ignore: avoid_print
        print(
          'BDFORET_POINT_HTTP=${correct.statusCode} '
          'axisOrder=latitude,longitude '
          'latencyMs=${correctWatch.elapsedMilliseconds} '
          'url=${_pointQuery(layer, latitude: latitude, longitude: longitude)}',
        );
        // ignore: avoid_print
        print('BDFORET_POINT_ATTRIBUTES=${_attributes(correctFeatures)}');
        expect(
          correctFeatures,
          isNotEmpty,
          reason:
              'Aucune entité au point connu avec axes lat,lon: ${correct.body}',
        );

        final reversedWatch = Stopwatch()..start();
        final reversed = await client.get(
          _pointQuery(layer, latitude: longitude, longitude: latitude),
        );
        reversedWatch.stop();
        expect(reversed.statusCode, 200, reason: reversed.body);
        final reversedFeatures = _features(reversed.body);
        // ignore: avoid_print
        print(
          'BDFORET_REVERSED_AXES_HTTP=${reversed.statusCode} '
          'features=${reversedFeatures.length} '
          'latencyMs=${reversedWatch.elapsedMilliseconds}',
        );
        expect(
          reversedFeatures,
          isEmpty,
          reason:
              'Le test témoin confirme que l’ordre lat,lon est significatif.',
        );
      } finally {
        client.close();
      }
    },
    skip: Platform.environment['RUN_LIVE_BDFORET_PROBE'] != '1',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

Uri _pointQuery(
  String layer, {
  required double latitude,
  required double longitude,
}) {
  // EPSG:4326 axis order in WFS 2.0 is latitude, longitude.
  final filter =
      '<fes:Filter xmlns:fes="http://www.opengis.net/fes/2.0" '
      'xmlns:gml="http://www.opengis.net/gml/3.2">'
      '<fes:Intersects><fes:ValueReference>geom</fes:ValueReference>'
      '<gml:Point srsName="urn:ogc:def:crs:EPSG::4326">'
      '<gml:pos>$latitude $longitude</gml:pos>'
      '</gml:Point></fes:Intersects></fes:Filter>';
  return Uri.https('data.geopf.fr', '/wfs/ows', {
    'SERVICE': 'WFS',
    'VERSION': '2.0.0',
    'REQUEST': 'GetFeature',
    'TYPENAMES': layer,
    'OUTPUTFORMAT': 'application/json',
    'SRSNAME': 'urn:ogc:def:crs:EPSG::4326',
    'COUNT': '10',
    'FILTER': filter,
  });
}

List<dynamic> _features(String body) {
  final decoded = jsonDecodeOrNull(body);
  if (decoded is! Map<String, dynamic>) return const [];
  final features = decoded['features'];
  return features is List ? features : const [];
}

Object? jsonDecodeOrNull(String body) {
  try {
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}

List<Map<String, dynamic>> _attributes(List<dynamic> features) =>
    features.map((feature) {
      final properties = (feature as Map)['properties'];
      if (properties is! Map) return <String, dynamic>{};
      return <String, dynamic>{
        'tfv': properties['tfv'],
        'code_tfv': properties['code_tfv'],
        'essence': properties['essence'],
      };
    }).toList();
