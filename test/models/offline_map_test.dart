import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/offline_map.dart';

void main() {
  group('OfflineMap', () {
    test('create with rectangle mode should have polygonJson == null', () {
      final map = OfflineMap.create(
        uuid: 'test-uuid',
        name: 'Test Zone',
        northLat: 45.0,
        southLat: 44.0,
        westLng: 2.0,
        eastLng: 3.0,
      );

      expect(map.polygonJson, isNull);
      expect(map.polygonPoints, isNull);
      expect(map.name, equals('Test Zone'));
      expect(map.northLat, equals(45.0));
      expect(map.southLat, equals(44.0));
      expect(map.westLng, equals(2.0));
      expect(map.eastLng, equals(3.0));
    });

    test('create with polygon mode should have polygonJson with vertices', () {
      final polygonJson =
          '[{"lat":45.0,"lng":2.0},{"lat":44.5,"lng":2.5},{"lat":44.0,"lng":3.0}]';

      final map = OfflineMap.create(
        uuid: 'test-uuid',
        name: 'Test Polygon Zone',
        northLat: 45.0,
        southLat: 44.0,
        westLng: 2.0,
        eastLng: 3.0,
        polygonJson: polygonJson,
      );

      expect(map.polygonJson, isNotNull);
      expect(map.polygonJson, equals(polygonJson));
      expect(map.name, equals('Test Polygon Zone'));
    });

    test('create with empty polygonJson should be null', () {
      final map = OfflineMap.create(
        uuid: 'test-uuid',
        name: 'Test Zone',
        northLat: 45.0,
        southLat: 44.0,
        westLng: 2.0,
        eastLng: 3.0,
        polygonJson: null,
      );

      expect(map.polygonJson, isNull);
      expect(map.polygonPoints, isNull);
    });

    test('polygonJson format should contain lat and lng in order', () {
      // This would be jsonEncode(verticesJson) in production
      final polygonJson =
          '[{"lat":45.0,"lng":2.0},{"lat":44.5,"lng":2.5},{"lat":44.0,"lng":3.0}]';

      final map = OfflineMap.create(
        uuid: 'test-uuid',
        name: 'Test Polygon Zone',
        northLat: 45.0,
        southLat: 44.0,
        westLng: 2.0,
        eastLng: 3.0,
        polygonJson: polygonJson,
      );

      expect(map.polygonJson, contains('lat'));
      expect(map.polygonJson, contains('lng'));
      expect(map.polygonJson, contains('45.0'));
      expect(map.polygonJson, contains('44.5'));
      expect(map.polygonJson, contains('44.0'));
    });

    test('polygonPoints getter decodes valid polygon JSON', () {
      final polygonJson =
          '[{"lat":45.0,"lng":2.0},{"lat":44.5,"lng":2.5},{"lat":44.0,"lng":3.0}]';

      final map = OfflineMap.create(
        uuid: 'test-uuid',
        name: 'Test Polygon Zone',
        northLat: 45.0,
        southLat: 44.0,
        westLng: 2.0,
        eastLng: 3.0,
        polygonJson: polygonJson,
      );

      final points = map.polygonPoints;
      expect(points, isNotNull);
      expect(points!.length, equals(3));
      expect(points[0], equals(const LatLng(45.0, 2.0)));
      expect(points[1], equals(const LatLng(44.5, 2.5)));
      expect(points[2], equals(const LatLng(44.0, 3.0)));
    });

    test('polygonPoints getter returns null for invalid JSON', () {
      final map = OfflineMap.create(
        uuid: 'test-uuid',
        name: 'Test Zone',
        northLat: 45.0,
        southLat: 44.0,
        westLng: 2.0,
        eastLng: 3.0,
        polygonJson: 'invalid json',
      );

      expect(map.polygonPoints, isNull);
    });

    test(
      'polygonPoints getter returns null for polygon with fewer than 3 points',
      () {
        final polygonJson = '[{"lat":45.0,"lng":2.0},{"lat":44.5,"lng":2.5}]';

        final map = OfflineMap.create(
          uuid: 'test-uuid',
          name: 'Test Zone',
          northLat: 45.0,
          southLat: 44.0,
          westLng: 2.0,
          eastLng: 3.0,
          polygonJson: polygonJson,
        );

        expect(map.polygonPoints, isNull);
      },
    );

    test('polygonPoints getter returns null for malformed JSON structure', () {
      final polygonJson = '[{"lat":45.0},{"lng":2.0}]';

      final map = OfflineMap.create(
        uuid: 'test-uuid',
        name: 'Test Zone',
        northLat: 45.0,
        southLat: 44.0,
        westLng: 2.0,
        eastLng: 3.0,
        polygonJson: polygonJson,
      );

      expect(map.polygonPoints, isNull);
    });
  });
}
