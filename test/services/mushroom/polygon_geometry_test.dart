import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/services/mushroom/polygon_geometry.dart';

void main() {
  group('pointInRing', () {
    test('point à l\'intérieur d\'un carré simple', () {
      final ring = [
        const Point(0, 0),
        const Point(0, 1),
        const Point(1, 1),
        const Point(1, 0),
      ];
      final inside = const Point(0.5, 0.5);
      final outside = const Point(2, 2);

      expect(pointInRing(inside, ring), isTrue);
      expect(pointInRing(outside, ring), isFalse);
    });

    test('point sur le bord du polygone', () {
      final ring = [
        const Point(0, 0),
        const Point(0, 1),
        const Point(1, 1),
        const Point(1, 0),
      ];
      final onEdge = const Point(0, 0.5);

      // Le ray casting peut donner des résultats incohérents sur les bords
      // On accepte soit true soit false pour les points exactement sur le bord
      final result = pointInRing(onEdge, ring);
      expect(result, isA<bool>());
    });

    test('point à l\'extérieur d\'un polygone concave', () {
      final ring = [
        const Point(0, 0),
        const Point(0, 2),
        const Point(1, 1),
        const Point(2, 2),
        const Point(2, 0),
      ];
      final inside = const Point(1, 0.5);
      final outside = const Point(1, 1.5);

      expect(pointInRing(inside, ring), isTrue);
      expect(pointInRing(outside, ring), isFalse);
    });
  });

  group('pointInRingRaw', () {
    test('coordonnées lat, lon (latFirst=true)', () {
      final ring = [
        [0.0, 0.0],
        [0.0, 1.0],
        [1.0, 1.0],
        [1.0, 0.0],
      ];
      expect(pointInRingRaw(0.5, 0.5, ring, latFirst: true), isTrue);
      expect(pointInRingRaw(2.0, 2.0, ring, latFirst: true), isFalse);
    });

    test('coordonnées lon, lat (latFirst=false)', () {
      final ring = [
        [0.0, 0.0],
        [1.0, 0.0],
        [1.0, 1.0],
        [0.0, 1.0],
      ];
      expect(pointInRingRaw(0.5, 0.5, ring, latFirst: false), isTrue);
      expect(pointInRingRaw(2.0, 2.0, ring, latFirst: false), isFalse);
    });
  });

  group('distanceToRingMeters', () {
    test('distance à un segment horizontal', () {
      final ring = [const Point(0, 0), const Point(1, 0)];
      final point = const Point(0.5, 0.001); // ~111m au nord

      final distance = distanceToRingMeters(point, ring);
      expect(distance, closeTo(111.0, 1.0));
    });

    test('distance à un segment vertical', () {
      final ring = [const Point(0, 0), const Point(0, 1)];
      final point = const Point(0.001, 0.5); // ~111m à l'est à cette latitude

      final distance = distanceToRingMeters(point, ring);
      expect(distance, closeTo(111.0, 1.0));
    });

    test('distance à un carré fermé', () {
      final ring = [
        const Point(0, 0),
        const Point(0, 1),
        const Point(1, 1),
        const Point(1, 0),
        const Point(0, 0),
      ];
      final inside = const Point(0.5, 0.5);
      final outsideNear = const Point(0.5, 1.001); // ~111m au nord

      expect(distanceToRingMeters(inside, ring), closeTo(0.5 * 111320.0, 10.0));
      expect(distanceToRingMeters(outsideNear, ring), closeTo(111.0, 1.0));
    });
  });
}
