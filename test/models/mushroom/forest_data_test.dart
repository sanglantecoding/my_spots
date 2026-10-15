import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';

void main() {
  group('ForestData', () {
    test('creates instance with correct values', () {
      final forest = ForestData(
        latitude: 43.5,
        longitude: 3.5,
        isForest: true,
        forestType: 'feuillu',
      );

      expect(forest.latitude, 43.5);
      expect(forest.longitude, 3.5);
      expect(forest.isForest, true);
      expect(forest.forestType, 'feuillu');
    });

    test('creates instance with null optional fields', () {
      final forest = ForestData(
        latitude: 43.5,
        longitude: 3.5,
        isForest: true,
        forestType: 'feuillu',
      );

      expect(forest.source, isNull);
    });

    test('creates instance for non-forest area', () {
      final forest = ForestData(
        latitude: 43.5,
        longitude: 3.5,
        isForest: false,
      );

      expect(forest.isForest, false);
      expect(forest.forestType, isNull);
    });

    test('mock leaves forest classification and measurements absent', () {
      final forest = ForestData.mock();

      expect(forest.latitude, 43.5);
      expect(forest.longitude, 3.5);
      expect(forest.isForest, isNull);
      expect(forest.forestType, isNull);
      expect(forest.source, isNull);
    });

    test('mock accepts custom values', () {
      final forest = ForestData.mock(
        isForest: true,
        forestType: 'conifère',
        source: 'ign',
      );

      expect(forest.isForest, true);
      expect(forest.forestType, 'conifère');
      expect(forest.source, 'ign');
    });

    test('mock creates non-forest instance', () {
      final forest = ForestData.mock(isForest: false);

      expect(forest.isForest, false);
      expect(forest.forestType, isNull);
    });
  });
}
