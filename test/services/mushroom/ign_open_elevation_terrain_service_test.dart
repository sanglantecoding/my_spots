import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:my_spots/services/mushroom/ign_open_elevation_terrain_service.dart';

void main() {
  group('parseIgnResponse', () {
    test('parse 9 altitudes dans le bon ordre', () {
      const body = '''
      {
        "elevations": [
          {"lon": 1.0, "lat": 44.0, "z": 100.0, "acc": 1.0},
          {"lon": 1.1, "lat": 44.0, "z": 110.0, "acc": 1.0},
          {"lon": 1.2, "lat": 44.0, "z": 120.0, "acc": 1.0},
          {"lon": 1.0, "lat": 44.1, "z": 130.0, "acc": 1.0},
          {"lon": 1.1, "lat": 44.1, "z": 140.0, "acc": 1.0},
          {"lon": 1.2, "lat": 44.1, "z": 150.0, "acc": 1.0},
          {"lon": 1.0, "lat": 44.2, "z": 160.0, "acc": 1.0},
          {"lon": 1.1, "lat": 44.2, "z": 170.0, "acc": 1.0},
          {"lon": 1.2, "lat": 44.2, "z": 180.0, "acc": 1.0}
        ]
      }
      ''';
      final out = IgnOpenElevationTerrainService.parseIgnResponse(
        body,
        expectedPoints: 9,
      );
      expect(out.length, 9);
      expect(out[0], 100.0);
      expect(out[4], 140.0);
      expect(out[8], 180.0);
    });

    test('points non retournés / z=null restent null', () {
      const body = '''
      {
        "elevations": [
          {"lon": 1.0, "lat": 44.0, "z": 100.0},
          {"lon": 1.1, "lat": 44.0},
          {"lon": 1.2, "lat": 44.0, "z": 120.0}
        ]
      }
      ''';
      final out = IgnOpenElevationTerrainService.parseIgnResponse(
        body,
        expectedPoints: 9,
      );
      expect(out.length, 9);
      expect(out[0], 100.0);
      expect(out[1], isNull);
      expect(out[2], 120.0);
      expect(out[3], isNull);
      expect(out[8], isNull);
    });

    test('code IGN -99999 est parsé comme pas de donnée, jamais altitude', () {
      const body = '{"elevations":[{"z":100},{"z":-99999},{"z":200}]}';
      final out = IgnOpenElevationTerrainService.parseIgnResponse(
        body,
        expectedPoints: 3,
      );
      expect(out, [100.0, isNull, 200.0]);
    });
  });

  group('parseOpenElevationResponse', () {
    test('parse results dans ordre, null sur manque', () {
      const body = '''
      {
        "results": [
          {"latitude": 44.0, "longitude": 1.0, "elevation": 100},
          {"latitude": 44.0, "longitude": 1.1, "elevation": null},
          {"latitude": 44.0, "longitude": 1.2, "elevation": 120}
        ]
      }
      ''';
      final out = IgnOpenElevationTerrainService.parseOpenElevationResponse(
        body,
        expectedPoints: 5,
      );
      expect(out.length, 5);
      expect(out[0], 100.0);
      expect(out[1], isNull);
      expect(out[2], 120.0);
      expect(out[3], isNull);
      expect(out[4], isNull);
    });
  });

  group('patch3x3', () {
    test('génère 9 points autour du centre, ordre a..i', () {
      final pts = IgnOpenElevationTerrainService.patch3x3(44.0, 1.0);
      expect(pts.length, 9);
      const s = 0.00025;
      expect(pts[4].$1, closeTo(44.0, 1e-9));
      expect(pts[4].$2, closeTo(1.0, 1e-9));
      expect(pts[0].$1, closeTo(44.0 + s, 1e-9));
      expect(pts[0].$2, closeTo(1.0 - s, 1e-9));
      expect(pts[2].$1, closeTo(44.0 + s, 1e-9));
      expect(pts[2].$2, closeTo(1.0 + s, 1e-9));
      expect(pts[6].$1, closeTo(44.0 - s, 1e-9));
      expect(pts[6].$2, closeTo(1.0 - s, 1e-9));
      expect(pts[8].$1, closeTo(44.0 - s, 1e-9));
      expect(pts[8].$2, closeTo(1.0 + s, 1e-9));
    });
  });

  group('calcul pente + aspect via getTerrainData (MockClient)', () {
    test(
      'sentinelle IGN centrale produit noElevationData sans altitude',
      () async {
        final vals = List<double?>.filled(9, 100.0);
        vals[4] = -99999.0;
        final data = await _terrainFromVals(vals);
        expect(data.elevation, isNull);
        expect(data.noElevationData, isTrue);
      },
    );

    test('terrain plat uniforme → aspect null, pente < 0.5°', () async {
      final r = await _terrainFromVals(List<double?>.filled(9, 200.0));
      expect(r.elevation, 200.0);
      expect(r.slope, lessThan(0.5));
      expect(r.aspect, isNull);
      expect(r.source, 'ign_bdalti_5m');
    });

    test('rampe Est pure (O→E) → aspect 90° ± 1, pente > 5°', () async {
      const vals = <double?>[100, 150, 200, 100, 150, 200, 100, 150, 200];
      final r = await _terrainFromVals(vals);
      expect(r.slope, greaterThan(5.0));
      expect(r.aspect, closeTo(90.0, 1.0));
      expect(r.source, 'ign_bdalti_5m');
    });

    test('rampe Ouest pure (E→O) → aspect 270° ± 1', () async {
      const vals = <double?>[200, 150, 100, 200, 150, 100, 200, 150, 100];
      final r = await _terrainFromVals(vals);
      expect(r.slope, greaterThan(5.0));
      expect(r.aspect, closeTo(270.0, 1.0));
    });

    test('rampe Sud pure (N→S) → aspect 180° ± 1', () async {
      const vals = <double?>[100, 100, 100, 150, 150, 150, 200, 200, 200];
      final r = await _terrainFromVals(vals);
      expect(r.slope, greaterThan(5.0));
      expect(r.aspect, closeTo(180.0, 1.0));
    });

    test('rampe Nord pure (S→N) → aspect 0° ± 1 (modulo 360)', () async {
      const vals = <double?>[200, 200, 200, 150, 150, 150, 100, 100, 100];
      final r = await _terrainFromVals(vals);
      expect(r.slope, greaterThan(5.0));
      final a = r.aspect;
      expect(a, isNotNull);
      final mod = a! % 360.0;
      expect(mod < 1.0 || mod > 359.0, isTrue);
    });

    test('un point du patch manquant → slope=null, aspect=null', () async {
      final vals = <double?>[100, null, 120, 130, 140, 150, 160, 170, 180];
      final r = await _terrainFromVals(vals);
      expect(r.elevation, 140.0);
      expect(r.slope, isNull);
      expect(r.aspect, isNull);
      expect(r.source, 'ign_bdalti_5m');
    });

    test('seul le centre disponible → elevation ok, reste null', () async {
      final vals = List<double?>.filled(9, null);
      vals[4] = 140.0;
      final r = await _terrainFromVals(vals);
      expect(r.elevation, 140.0);
      expect(r.slope, isNull);
      expect(r.aspect, isNull);
    });
  });

  group('fallback IGN → Open-Elevation', () {
    test('IGN 500 bascule sur Open-Elevation, source correcte', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'data.geopf.fr') {
          return Response('{}', 500);
        }
        if (request.url.host == 'api.open-elevation.com') {
          final body = jsonEncode({
            'results': List<Map<String, dynamic>>.generate(
              9,
              (i) => {'latitude': 44.0, 'longitude': 1.0, 'elevation': 100 + i},
            ),
          });
          return Response(
            body,
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return Response('fail', 404);
      });

      final svc = IgnOpenElevationTerrainService(client: client);
      final data = await svc.getTerrainData(lat: 44.0, lng: 1.0);
      expect(data.source, 'srtm_open_elevation_30m');
      expect(data.elevation, 104.0);
      expect(data.slope, isNotNull);
    });

    test('deux services KO → exception propagée', () async {
      final client = MockClient((request) async => Response('nope', 503));
      final svc = IgnOpenElevationTerrainService(client: client);
      expect(
        svc.getTerrainData(lat: 44.0, lng: 1.0),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('cache', () {
    test('mêmes coords → 1 seul appel HTTP, valeurs identiques', () async {
      var ignCallCount = 0;
      final client = MockClient((request) async {
        if (request.url.host == 'data.geopf.fr') {
          ignCallCount++;
          final body = jsonEncode({
            'elevations': List<Map<String, dynamic>>.generate(
              9,
              (_) => {'lon': 1.0, 'lat': 44.0, 'z': 500.0, 'acc': 1.0},
            ),
          });
          return Response(
            body,
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return Response('{}', 500);
      });

      final svc = IgnOpenElevationTerrainService(client: client);
      final a = await svc.getTerrainData(lat: 44.0, lng: 1.0);
      final b = await svc.getTerrainData(lat: 44.0, lng: 1.0);
      expect(ignCallCount, 1);
      expect(a.elevation, b.elevation);
      expect(a.source, b.source);
      expect(a.source, 'ign_bdalti_5m');
    });

    test('coords éloignées (> précision cache) → 2 appels HTTP', () async {
      var ignCallCount = 0;
      final client = MockClient((request) async {
        if (request.url.host == 'data.geopf.fr') {
          ignCallCount++;
          final body = jsonEncode({
            'elevations': List<Map<String, dynamic>>.generate(
              9,
              (_) => {'lon': 1.0, 'lat': 44.0, 'z': 100.0, 'acc': 1.0},
            ),
          });
          return Response(
            body,
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return Response('{}', 500);
      });

      final svc = IgnOpenElevationTerrainService(client: client);
      await svc.getTerrainData(lat: 44.0, lng: 1.0);
      await svc.getTerrainData(lat: 44.0 + 0.1, lng: 1.0 + 0.1);
      expect(ignCallCount, 2);
    });
  });

  group('requête HTTP IGN bien formée', () {
    test('POST JSON avec lon/lat arrays + resource ign_rge_alti5', () async {
      Request? captured;
      final client = MockClient((request) async {
        captured = request;
        final body = jsonEncode({
          'elevations': List<Map<String, dynamic>>.generate(
            9,
            (_) => {'lon': 1.0, 'lat': 44.0, 'z': 200.0, 'acc': 1.0},
          ),
        });
        return Response(
          body,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = IgnOpenElevationTerrainService(client: client);
      await svc.getTerrainData(lat: 44.0, lng: 1.0);

      final req = captured!;
      expect(req.method, 'POST');
      expect(req.url.host, 'data.geopf.fr');
      final parsed = jsonDecode(req.body) as Map<String, dynamic>;
      expect(parsed['resource'], 'ign_rge_alti5');
      expect(parsed['lon'] is List, isTrue);
      expect(parsed['lat'] is List, isTrue);
      expect((parsed['lon'] as List).length, 9);
      expect((parsed['lat'] as List).length, 9);
    });
  });

  group('getElevation wrapper', () {
    test('retourne l\'altitude centrale quand dispo', () async {
      const vals = <double?>[1, 2, 3, 4, 99.0, 6, 7, 8, 9];
      final svc = IgnOpenElevationTerrainService(
        client: _mockIgnFixedVals(vals),
      );
      final e = await svc.getElevation(lat: 44.0, lng: 1.0);
      expect(e, 99.0);
    });

    test('erreur si altitude non dispo', () async {
      final vals = List<double?>.filled(9, null);
      final svc = IgnOpenElevationTerrainService(
        client: _mockIgnFixedVals(vals),
      );
      expect(svc.getElevation(lat: 44.0, lng: 1.0), throwsA(isA<StateError>()));
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────

Client _mockIgnFixedVals(List<double?> vals) {
  return MockClient((request) async {
    if (request.url.host == 'data.geopf.fr') {
      final body = jsonEncode({
        'elevations': List<Map<String, dynamic>>.generate(vals.length, (i) {
          final m = <String, dynamic>{'lon': 1.0, 'lat': 44.0, 'acc': 1.0};
          final v = vals[i];
          if (v != null) m['z'] = v;
          return m;
        }),
      });
      return Response(body, 200, headers: {'content-type': 'application/json'});
    }
    return Response('{}', 500);
  });
}

Future<dynamic> _terrainFromVals(List<double?> vals) async {
  final svc = IgnOpenElevationTerrainService(client: _mockIgnFixedVals(vals));
  return svc.getTerrainData(lat: 44.0, lng: 1.0);
}
