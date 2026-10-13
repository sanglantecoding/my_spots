import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/services/mushroom/forest_service.dart';
import 'package:my_spots/services/mushroom/ign_bd_foret_forest_service.dart';

void main() {
  group('CompositeForestService', () {
    test('getForestBatch: one service fails, other succeeds', () async {
      final mockBdForet = _MockForestService(shouldFail: true);
      final mockOverpass = _MockForestService(shouldFail: false);

      final composite = CompositeForestService(
        bdForet: mockBdForet,
        overpass: mockOverpass,
      );

      final bounds = LatLngBounds(
        const LatLng(43.0, 3.0),
        const LatLng(44.0, 4.0),
      );
      final centers = [const LatLng(43.5, 3.5), const LatLng(43.6, 3.6)];

      final result = await composite.getForestBatch(bounds, centers);

      // Should return results from the successful service
      expect(result.length, equals(2));
      expect(result.containsKey('43.5,3.5'), isTrue);
      expect(result.containsKey('43.6,3.6'), isTrue);
    });

    test(
      'getForestBatch: OSM lake (water) preserved when BD Forêt sees forest',
      () async {
        final mockBdForet = _MockForestService(
          shouldFail: false,
          isForest: true,
          landCover: null,
        );
        final mockOverpass = _MockForestService(
          shouldFail: false,
          isForest: false,
          landCover: 'water',
        );

        final composite = CompositeForestService(
          bdForet: mockBdForet,
          overpass: mockOverpass,
        );

        final bounds = LatLngBounds(
          const LatLng(43.0, 3.0),
          const LatLng(44.0, 4.0),
        );
        final centers = [const LatLng(43.5, 3.5)];

        final result = await composite.getForestBatch(bounds, centers);

        final data = result['43.5,3.5'];
        expect(data, isNotNull);
        // BD Forêt sees forest, so isForest should be true
        expect(data!.isForest, isTrue);
        // OSM landCover (water) should be preserved
        expect(data.landCover, equals('water'));
      },
    );

    test('getForestBatch: both services fail returns empty map', () async {
      final mockBdForet = _MockForestService(shouldFail: true);
      final mockOverpass = _MockForestService(shouldFail: true);

      final composite = CompositeForestService(
        bdForet: mockBdForet,
        overpass: mockOverpass,
      );

      final bounds = LatLngBounds(
        const LatLng(43.0, 3.0),
        const LatLng(44.0, 4.0),
      );
      final centers = [const LatLng(43.5, 3.5)];

      final result = await composite.getForestBatch(bounds, centers);

      expect(result, isEmpty);
    });
  });
}

class _MockForestService implements ForestService {
  final bool shouldFail;
  final bool? isForest;
  final String? landCover;

  _MockForestService({
    required this.shouldFail,
    this.isForest = true,
    this.landCover,
  });

  @override
  Future<ForestData> getForestData({
    required double lat,
    required double lng,
  }) async {
    if (shouldFail) throw Exception('Mock failure');
    return ForestData(
      latitude: lat,
      longitude: lng,
      isForest: isForest,
      forestType: 'feuillu',
      source: 'mock',
      landCover: landCover,
    );
  }

  @override
  Future<Map<String, ForestData>> getForestBatch(
    LatLngBounds bounds,
    List<LatLng> centers, {
    void Function(String)? onStage,
  }) async {
    if (shouldFail) throw Exception('Mock failure');
    final result = <String, ForestData>{};
    for (final center in centers) {
      final key = '${center.latitude},${center.longitude}';
      result[key] = ForestData(
        latitude: center.latitude,
        longitude: center.longitude,
        isForest: isForest,
        forestType: 'feuillu',
        source: 'mock',
        landCover: landCover,
      );
    }
    return result;
  }
}
