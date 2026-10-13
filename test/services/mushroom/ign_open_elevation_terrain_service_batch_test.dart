import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/services/mushroom/ign_open_elevation_terrain_service.dart';
import 'package:my_spots/services/mushroom/point_key.dart';

void main() {
  group('IgnOpenElevationTerrainService.getTerrainBatch', () {
    late IgnOpenElevationTerrainService service;
    late http.Client mockClient;

    setUp(() {
      mockClient = http.Client();
      service = IgnOpenElevationTerrainService(client: mockClient);
    });

    tearDown(() {
      mockClient.close();
    });

    test(
      'returns Map indexed by mushroomViewportPointKey for 5 centers',
      () async {
        final centers = [
          const LatLng(44.06879, 3.57342),
          const LatLng(44.06880, 3.57343),
          const LatLng(44.06881, 3.57344),
          const LatLng(44.06882, 3.57345),
          const LatLng(44.06883, 3.57346),
        ];

        // Mock IGN response with elevations
        final mockResponse = {
          'elevations': List.generate(
            5 * 9, // 5 centers * 9 points per patch
            (i) => {'z': 1000.0 + i.toDouble()},
          ),
        };

        mockClient = MockClient((request) async {
          return http.Response(jsonEncode(mockResponse), 200);
        });

        service = IgnOpenElevationTerrainService(client: mockClient);

        final result = await service.getTerrainBatch(centers, 100.0);

        // Verify all 5 keys are present with correct format
        expect(result.length, equals(5));
        for (final center in centers) {
          final key = mushroomViewportPointKey(center);
          expect(result.containsKey(key), isTrue);
          expect(result[key]!.elevation, isNotNull);
          expect(result[key]!.source, equals('ign_rge_alti_wld'));
        }
      },
    );

    test('second call uses cache and returns same keys', () async {
      final centers = [
        const LatLng(44.06879, 3.57342),
        const LatLng(44.06880, 3.57343),
      ];

      var callCount = 0;
      mockClient = MockClient((request) async {
        callCount++;
        final mockResponse = {
          'elevations': List.generate(
            2 * 9,
            (i) => {'z': 1000.0 + i.toDouble()},
          ),
        };
        return http.Response(jsonEncode(mockResponse), 200);
      });

      service = IgnOpenElevationTerrainService(client: mockClient);

      // First call - should hit API
      final result1 = await service.getTerrainBatch(centers, 100.0);
      expect(callCount, equals(1));
      expect(result1.length, equals(2));

      // Second call - should use cache
      final result2 = await service.getTerrainBatch(centers, 100.0);
      expect(callCount, equals(1)); // No additional API call
      expect(result2.length, equals(2));

      // Verify keys are the same (main goal of this test)
      for (final center in centers) {
        final key = mushroomViewportPointKey(center);
        expect(result1.containsKey(key), isTrue);
        expect(result2.containsKey(key), isTrue);
      }
    });

    test('returns correct key format even when IGN fails', () async {
      final centers = [const LatLng(44.06879, 3.57342)];

      mockClient = MockClient((request) async {
        // Return error to trigger fallback
        return http.Response('Error', 500);
      });

      service = IgnOpenElevationTerrainService(client: mockClient);

      final result = await service.getTerrainBatch(centers, 100.0);

      // Verify key format is still correct even on failure
      final key = mushroomViewportPointKey(centers[0]);
      expect(result.containsKey(key), isTrue);
      expect(result[key]!.elevation, isNull); // Failed to get elevation
    });
  });
}
