import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';

void main() {
  group('TerrainData', () {
    test('creates instance with correct values', () {
      final terrain = TerrainData(
        latitude: 43.5,
        longitude: 3.5,
        elevation: 200.0,
        slope: 10.0,
        aspect: 180.0,
      );

      expect(terrain.latitude, 43.5);
      expect(terrain.longitude, 3.5);
      expect(terrain.elevation, 200.0);
      expect(terrain.slope, 10.0);
      expect(terrain.aspect, 180.0);
    });

    test('mock creates instance with default values', () {
      final terrain = TerrainData.mock();

      expect(terrain.latitude, 43.5);
      expect(terrain.longitude, 3.5);
      expect(terrain.elevation, 200.0);
      expect(terrain.slope, 10.0);
      expect(terrain.aspect, 180.0);
    });

    test('aspectCardinal returns correct direction', () {
      expect(TerrainData.mock(aspect: 0).aspectCardinal, 'N');
      expect(TerrainData.mock(aspect: 45).aspectCardinal, 'NE');
      expect(TerrainData.mock(aspect: 90).aspectCardinal, 'E');
      expect(TerrainData.mock(aspect: 135).aspectCardinal, 'SE');
      expect(TerrainData.mock(aspect: 180).aspectCardinal, 'S');
      expect(TerrainData.mock(aspect: 225).aspectCardinal, 'SO');
      expect(TerrainData.mock(aspect: 270).aspectCardinal, 'O');
      expect(TerrainData.mock(aspect: 315).aspectCardinal, 'NO');
    });

    test('allows unavailable terrain measures', () {
      final terrain = TerrainData(latitude: 43.5, longitude: 3.5);
      expect(terrain.elevation, isNull);
      expect(terrain.slope, isNull);
      expect(terrain.aspect, isNull);
      expect(terrain.aspectCardinal, isNull);
    });
  });
}
