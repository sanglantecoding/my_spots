import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/services/mushroom/overpass_forest_service.dart';

void main() {
  late Directory cacheDirectory;
  late String fixture;

  setUpAll(() {
    fixture = File(
      'test/fixtures/mushroom/overpass_tile.json',
    ).readAsStringSync();
  });

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp(
      'my_spots_overpass_',
    );
    AppSettings.offlineModeEnabled = false;
  });

  tearDown(() async {
    AppSettings.offlineModeEnabled = false;
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  });

  OverpassForestService service(http.Client client) => OverpassForestService(
    client: client,
    cacheDirectory: cacheDirectory,
    endpoint: Uri.parse('https://overpass.test/api/interpreter'),
    fallbackEndpoint: Uri.parse('https://overpass.test/api/interpreter'),
    retryBackoff: const [],
  );

  MockClient fixtureClient() => MockClient((request) async {
    expect(request.method, 'POST');
    expect(request.url.host, 'overpass.test');
    expect(request.headers['user-agent'], contains('my_spots'));
    expect(request.bodyFields['data'], contains('out geom tags'));
    return http.Response(
      fixture,
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  group('OverpassForestService géométrie', () {
    test('point à l’intérieur de la forêt et type issu de leaf_type', () async {
      final data = await service(
        fixtureClient(),
      ).getForestData(lat: 45.012, lng: 3.012);
      expect(data.isForest, isTrue);
      expect(data.forestType, 'feuillu');
      expect(data.treeDensity, isNull);
      expect(data.canopyCover, isNull);
      expect(data.source, 'osm_overpass');
      expect(data.forestAreasInTile, greaterThan(0));
      expect(data.nearestForestDistanceMeters, isNotNull);
      expect(
        data.landCover,
        isNull,
        reason: 'l’urbain ne prime pas sur la forêt',
      );
    });

    test('absence de polygone dans une tuile connue reste inconnue', () async {
      final data = await service(
        fixtureClient(),
      ).getForestData(lat: 45.045, lng: 3.045);
      expect(data.isForest, isNull);
      expect(data.landCover, isNull);
      expect(data.forestAreasInTile, greaterThan(0));
      expect(data.nearestForestDistanceMeters, greaterThan(50));
    });

    test(
      'tuile connue sans zone forestière compte zéro et distance nulle',
      () async {
        final empty = jsonEncode({'elements': <dynamic>[]});
        final data = await service(
          MockClient((_) async => http.Response(empty, 200)),
        ).getForestData(lat: 45.012, lng: 3.012);
        expect(data.isForest, isNull);
        expect(data.forestAreasInTile, 0);
        expect(data.nearestForestDistanceMeters, isNull);
      },
    );

    test(
      'un trou de multipolygon ne permet pas de conclure à l’absence',
      () async {
        final data = await service(
          fixtureClient(),
        ).getForestData(lat: 45.025, lng: 3.025);
        expect(data.isForest, isNull);
      },
    );

    test(
      'assemble les segments outer désordonnés et inversés autour d’un trou',
      () async {
        final relationFixture = jsonEncode({
          'elements': [
            {
              'type': 'relation',
              'id': 9001,
              'tags': {'type': 'multipolygon', 'landuse': 'forest'},
              'members': [
                {
                  'type': 'way',
                  'role': 'outer',
                  'geometry': [
                    {'lat': 45.0, 'lon': 3.0},
                    {'lat': 45.0, 'lon': 3.01},
                  ],
                },
                {
                  'type': 'way',
                  'role': 'outer',
                  'geometry': [
                    {'lat': 45.01, 'lon': 3.01},
                    {'lat': 45.0, 'lon': 3.01},
                  ],
                },
                {
                  'type': 'way',
                  'role': 'outer',
                  'geometry': [
                    {'lat': 45.01, 'lon': 3.0},
                    {'lat': 45.01, 'lon': 3.01},
                  ],
                },
                {
                  'type': 'way',
                  'role': 'outer',
                  'geometry': [
                    {'lat': 45.0, 'lon': 3.0},
                    {'lat': 45.01, 'lon': 3.0},
                  ],
                },
                {
                  'type': 'way',
                  'role': 'inner',
                  'geometry': [
                    {'lat': 45.004, 'lon': 3.004},
                    {'lat': 45.006, 'lon': 3.004},
                    {'lat': 45.006, 'lon': 3.006},
                  ],
                },
                {
                  'type': 'way',
                  'role': 'inner',
                  'geometry': [
                    {'lat': 45.004, 'lon': 3.004},
                    {'lat': 45.004, 'lon': 3.006},
                    {'lat': 45.006, 'lon': 3.006},
                  ],
                },
              ],
            },
          ],
        });
        final client = MockClient(
          (_) async => http.Response(relationFixture, 200),
        );
        final svc = service(client);

        final forestPoint = await svc.getForestData(lat: 45.002, lng: 3.002);
        final holePoint = await svc.getForestData(lat: 45.005, lng: 3.005);

        expect(forestPoint.isForest, isTrue);
        expect(holePoint.isForest, isNull);
      },
    );

    test(
      'la lisière à 30 m est prouvée, celle à 80 m reste inconnue',
      () async {
        final edge30 = await service(
          fixtureClient(),
        ).getForestData(lat: 45.025, lng: 3.04038);
        final edge80 = await service(
          fixtureClient(),
        ).getForestData(lat: 45.025, lng: 3.04102);
        expect(edge30.isForest, isTrue);
        expect(edge80.isForest, isNull);
      },
    );

    test('lac et plage prennent priorité dans landCover', () async {
      final lake = await service(
        fixtureClient(),
      ).getForestData(lat: 45.004, lng: 3.004);
      final beach = await service(
        fixtureClient(),
      ).getForestData(lat: 45.004, lng: 3.012);
      expect(lake.landCover, 'water');
      expect(beach.landCover, 'beach');
    });
  });

  group('OverpassForestService cache et réseau', () {
    test(
      'une réponse avec remark est un échec et ne va pas en cache',
      () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response('{"remark":"runtime error","elements":[]}', 200);
        });
        final svc = service(client);

        final first = await svc.getForestData(lat: 45.012, lng: 3.012);
        final second = await svc.getForestData(lat: 45.012, lng: 3.012);

        expect(calls, 2);
        for (final data in [first, second]) {
          expect(data.isForest, isNull);
          expect(data.forestType, isNull);
          expect(data.treeDensity, isNull);
          expect(data.canopyCover, isNull);
          expect(data.landCover, isNull);
          expect(data.source, isNull);
        }
      },
    );

    test(
      'deux points dans une tuile ne déclenchent qu’un appel réseau',
      () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response(fixture, 200);
        });
        final svc = service(client);
        await svc.getForestData(lat: 45.012, lng: 3.012);
        await svc.getForestData(lat: 45.045, lng: 3.045);
        expect(calls, 1);
      },
    );

    test(
      'réessaie 429/504 avec backoff puis utilise le endpoint de repli',
      () async {
        final hosts = <String>[];
        final client = MockClient((request) async {
          hosts.add(request.url.host);
          if (request.url.host == 'fallback.test') {
            return http.Response(fixture, 200);
          }
          return http.Response('', hosts.length == 1 ? 429 : 504);
        });
        final svc = OverpassForestService(
          client: client,
          cacheDirectory: cacheDirectory,
          endpoint: Uri.parse('https://overpass.test/api/interpreter'),
          fallbackEndpoint: Uri.parse('https://fallback.test/api/interpreter'),
          retryBackoff: const [Duration.zero, Duration.zero],
        );

        final data = await svc.getForestData(lat: 45.012, lng: 3.012);
        expect(data.isForest, isTrue);
        expect(hosts, [
          'overpass.test',
          'overpass.test',
          'overpass.test',
          'fallback.test',
        ]);
      },
    );

    test(
      'échec réseau sans cache retourne tous les champs facultatifs nuls',
      () async {
        final svc = service(
          MockClient((_) async => throw const SocketException('offline')),
        );
        final data = await svc.getForestData(lat: 45.012, lng: 3.012);
        expect(data.isForest, isNull);
        expect(data.forestType, isNull);
        expect(data.treeDensity, isNull);
        expect(data.canopyCover, isNull);
        expect(data.landCover, isNull);
        expect(data.forestAreasInTile, isNull);
        expect(data.nearestForestDistanceMeters, isNull);
        expect(data.source, isNull);
      },
    );

    test('mode hors-ligne sans cache ne lance aucun appel réseau', () async {
      var calls = 0;
      AppSettings.offlineModeEnabled = true;
      final svc = service(
        MockClient((_) async {
          calls++;
          return http.Response(fixture, 200);
        }),
      );

      final data = await svc.getForestData(lat: 45.012, lng: 3.012);
      expect(calls, 0);
      expect(data.isForest, isNull);
      expect(data.forestType, isNull);
      expect(data.treeDensity, isNull);
      expect(data.canopyCover, isNull);
      expect(data.landCover, isNull);
      expect(data.forestAreasInTile, isNull);
      expect(data.nearestForestDistanceMeters, isNull);
      expect(data.source, isNull);
    });

    test('mode hors-ligne réutilise le cache sans appel réseau', () async {
      await service(fixtureClient()).getForestData(lat: 45.012, lng: 3.012);
      var calls = 0;
      AppSettings.offlineModeEnabled = true;
      final cachedService = service(
        MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
      );

      final data = await cachedService.getForestData(lat: 45.012, lng: 3.012);
      expect(data.isForest, isTrue);
      expect(calls, 0);
    });

    test('la fixture reste un JSON Overpass valide', () {
      expect(jsonDecode(fixture), isA<Map<String, dynamic>>());
    });
  });
}
