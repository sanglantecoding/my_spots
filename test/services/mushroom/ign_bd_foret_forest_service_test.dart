import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/services/mushroom/ign_bd_foret_forest_service.dart';
import 'package:my_spots/services/mushroom/forest_service.dart';

void main() {
  late Directory cacheDirectory;
  final fixtures = <String, Map<String, dynamic>>{};

  setUpAll(() {
    for (final name in ['deciduous', 'conifers', 'mixed', 'lande', 'empty']) {
      fixtures[name] =
          jsonDecode(
                File(
                  'test/fixtures/mushroom/bd_foret_$name.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
    }
  });

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp('bd_foret_test_');
    AppSettings.offlineModeEnabled = false;
  });

  tearDown(() async {
    AppSettings.offlineModeEnabled = false;
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  });

  test('GeoJSON maps closed deciduous forest and canopy class', () {
    final data = IgnBdForetForestService.parseFeatureCollection(
      fixtures['deciduous']!,
      lat: 43.57,
      lng: 2.71,
    );
    expect(data.isForest, isTrue);
    expect(data.forestType, 'feuillu');
    expect(data.canopyClass, 'fermée');
    expect(data.canopyCover, isNull);
    expect(data.treeDensity, isNull);
  });

  test('GeoJSON maps conifer, mixed/open, and explicit heathland', () {
    final conifer = IgnBdForetForestService.parseFeatureCollection(
      fixtures['conifers']!,
      lat: 0,
      lng: 0,
    );
    final mixed = IgnBdForetForestService.parseFeatureCollection(
      fixtures['mixed']!,
      lat: 0,
      lng: 0,
    );
    final lande = IgnBdForetForestService.parseFeatureCollection(
      fixtures['lande']!,
      lat: 0,
      lng: 0,
    );
    expect(conifer.forestType, 'conifère');
    expect(mixed.forestType, 'mixte');
    expect(mixed.canopyClass, 'ouverte');
    expect(lande.isForest, isFalse);
  });

  test('empty valid feature collection remains unknown', () {
    final data = IgnBdForetForestService.parseFeatureCollection(
      fixtures['empty']!,
      lat: 0,
      lng: 0,
    );
    expect(data.isForest, isNull);
  });

  test('request uses WFS 2.0 latitude longitude axes', () async {
    var calls = 0;
    final service = IgnBdForetForestService(
      client: MockClient((request) async {
        calls++;
        expect(
          request.url.queryParameters['TYPENAMES'],
          IgnBdForetForestService.layerName,
        );
        expect(
          request.url.queryParameters['FILTER'],
          contains('<gml:pos>43.57158 2.71777</gml:pos>'),
        );
        return http.Response(jsonEncode(fixtures['deciduous']), 200);
      }),
      cacheDirectory: cacheDirectory,
      endpoint: Uri.parse('https://wfs.test/ows'),
    );
    final data = await service.getForestData(lat: 43.57158, lng: 2.71777);
    expect(data.isForest, isTrue);
    expect(calls, 1);
  });

  test('cache is reused and available offline', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(jsonEncode(fixtures['deciduous']), 200);
    });
    final firstService = IgnBdForetForestService(
      client: client,
      cacheDirectory: cacheDirectory,
    );
    expect(
      (await firstService.getForestData(lat: 43.5, lng: 2.7)).isForest,
      isTrue,
    );
    AppSettings.offlineModeEnabled = true;
    final secondService = IgnBdForetForestService(
      client: MockClient(
        (_) async => fail('offline cache miss made a request'),
      ),
      cacheDirectory: cacheDirectory,
    );
    expect(
      (await secondService.getForestData(lat: 43.5001, lng: 2.7001)).isForest,
      isTrue,
    );
    expect(calls, 1);
  });

  test('network error without cache returns all unknown fields', () async {
    final service = IgnBdForetForestService(
      client: MockClient((_) async => http.Response('failure', 503)),
      cacheDirectory: cacheDirectory,
    );
    final data = await service.getForestData(lat: 43.5, lng: 2.7);
    expect(data.isForest, isNull);
    expect(data.forestType, isNull);
    expect(data.canopyClass, isNull);
    expect(data.treeDensity, isNull);
    expect(data.canopyCover, isNull);
    expect(data.landCover, isNull);
    expect(data.source, isNull);
  });

  test(
    'OSM positive forest and landcover take the composite priority',
    () async {
      final composite = CompositeForestService(
        bdForet: _StubForest(
          ForestData.mock(isForest: false, source: 'ign_bdforet_v2'),
        ),
        overpass: _StubForest(
          ForestData.mock(
            isForest: true,
            landCover: 'water',
            source: 'osm_overpass',
          ),
        ),
      );
      final data = await composite.getForestData(lat: 0, lng: 0);
      expect(data.isForest, isTrue);
      expect(data.landCover, 'water');
      expect(data.source, 'ign_bdforet_v2+osm_overpass');
    },
  );
}

class _StubForest implements ForestService {
  _StubForest(this.value);
  final ForestData value;
  @override
  Future<ForestData> getForestData({
    required double lat,
    required double lng,
  }) async => value;
}
