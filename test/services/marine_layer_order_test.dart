import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/services/marine_map_service.dart';

/// Tests d'invariants de l'ordre d'empilement des couches marines.
///
/// Ces seuils (12.0 / 14.0) sont critiques :
/// - Ils doivent être EN DEÇÀ du demi-niveau (12.5 / 14.5) où flutter_map
///   passe à z entier +1, sinon les tuiles transparentes de la couche
///   supérieure laissent voir le fond "Dézoomez" de la couche du bas.
/// - L'ordre (index 0 = couche du BAS) détermine quelle couche peint
///   le message "Dézoomez pour voir la carte".
///
/// Tout changement futur de ces seuils ou de l'ordre fera échouer ce
/// fichier immédiatement.
void main() {
  group('layerOrderForZoom — mode ONLINE', () {
    test('zoom < 7.0 → seule la 1M (couche la plus générale)', () {
      for (final z in [1.0, 3.0, 5.0, 6.99]) {
        final order = MarineMapService.layerOrderForZoom(z);
        expect(order, hasLength(1), reason: 'zoom $z');
        expect(order.first, contains('3857_WMTS'), reason: 'zoom $z');
        expect(order.first, isNot(contains('350')), reason: 'zoom $z');
      }
    });

    test('7.0 ≤ zoom < 9.0 → seule la 350K', () {
      for (final z in [7.0, 7.5, 8.0, 8.99]) {
        final order = MarineMapService.layerOrderForZoom(z);
        expect(order, hasLength(1), reason: 'zoom $z');
        expect(order.first, contains('350'), reason: 'zoom $z');
      }
    });

    test('9.0 ≤ zoom < 11.0 → seule la 100K', () {
      for (final z in [9.0, 9.5, 10.0, 10.99]) {
        final order = MarineMapService.layerOrderForZoom(z);
        expect(order, hasLength(1), reason: 'zoom $z');
        expect(order.first, contains('100'), reason: 'zoom $z');
      }
    });

    test('11.0 ≤ zoom < 12.0 → seule la 50K', () {
      for (final z in [11.0, 11.5, 11.99]) {
        final order = MarineMapService.layerOrderForZoom(z);
        expect(order, hasLength(1), reason: 'zoom $z');
        expect(order.first, contains('50'), reason: 'zoom $z');
      }
    });

    test('12.0 ≤ zoom < 14.0 → 50K (bas) puis 25K (haut)', () {
      for (final z in [12.0, 12.5, 13.0, 13.99]) {
        final order = MarineMapService.layerOrderForZoom(z);
        expect(order, hasLength(2), reason: 'zoom $z');
        expect(order[0], contains('50'), reason: 'zoom $z — couche du bas');
        expect(order[1], contains('25'), reason: 'zoom $z — couche du haut');
      }
    });

    test('zoom ≥ 14.0 → 50K (bas) + 25K (milieu) + 10K (haut)', () {
      for (final z in [14.0, 14.5, 15.0, 16.0, 22.0]) {
        final order = MarineMapService.layerOrderForZoom(z);
        expect(order, hasLength(3), reason: 'zoom $z');
        expect(order[0], contains('50'), reason: 'zoom $z — couche du bas');
        expect(order[1], contains('25'), reason: 'zoom $z — couche du milieu');
        expect(order[2], contains('10'), reason: 'zoom $z — couche du haut');
      }
    });
  });

  group('layerOrderForZoom — mode OFFLINE', () {
    test(
      'zoom < 12.0 → seule la 50K (s\'étire car pas de 1M/350K/100K offline)',
      () {
        for (final z in [1.0, 5.0, 8.0, 10.0, 11.99]) {
          final order = MarineMapService.layerOrderForZoom(z, offline: true);
          expect(order, hasLength(1), reason: 'zoom $z');
          expect(order.first, contains('50'), reason: 'zoom $z');
        }
      },
    );

    test('12.0 ≤ zoom < 14.0 → 50K (bas) puis 25K (haut)', () {
      for (final z in [12.0, 12.5, 13.0, 13.99]) {
        final order = MarineMapService.layerOrderForZoom(z, offline: true);
        expect(order, hasLength(2), reason: 'zoom $z');
        expect(order[0], contains('50'), reason: 'zoom $z — couche du bas');
        expect(order[1], contains('25'), reason: 'zoom $z — couche du haut');
      }
    });

    test('zoom ≥ 14.0 → 50K + 25K + 10K (identique à online)', () {
      for (final z in [14.0, 14.5, 15.0, 16.0, 22.0]) {
        final order = MarineMapService.layerOrderForZoom(z, offline: true);
        expect(order, hasLength(3), reason: 'zoom $z');
        expect(order[0], contains('50'));
        expect(order[1], contains('25'));
        expect(order[2], contains('10'));
      }
    });
  });

  group('layerOrderForZoom — bornes exactes des seuils', () {
    test('seuil 12.0 : 11.99 → 1 couche, 12.0 → 2 couches', () {
      expect(MarineMapService.layerOrderForZoom(11.99), hasLength(1));
      expect(MarineMapService.layerOrderForZoom(12.0), hasLength(2));
    });

    test('seuil 14.0 : 13.99 → 2 couches, 14.0 → 3 couches', () {
      expect(MarineMapService.layerOrderForZoom(13.99), hasLength(2));
      expect(MarineMapService.layerOrderForZoom(14.0), hasLength(3));
    });

    test('seuil 12.0 offline : 11.99 → 1 couche, 12.0 → 2 couches', () {
      expect(
        MarineMapService.layerOrderForZoom(11.99, offline: true),
        hasLength(1),
      );
      expect(
        MarineMapService.layerOrderForZoom(12.0, offline: true),
        hasLength(2),
      );
    });

    test('seuil 14.0 offline : 13.99 → 2 couches, 14.0 → 3 couches', () {
      expect(
        MarineMapService.layerOrderForZoom(13.99, offline: true),
        hasLength(2),
      );
      expect(
        MarineMapService.layerOrderForZoom(14.0, offline: true),
        hasLength(3),
      );
    });
  });

  group('layerOrderForZoom — ordre d\'empilement invariant', () {
    test('la 50K est TOUJOURS en bas (index 0)', () {
      for (final z in [11.0, 12.0, 13.0, 14.0, 15.0, 20.0]) {
        final order = MarineMapService.layerOrderForZoom(z);
        expect(order.first, contains('50'), reason: 'zoom $z');
      }
    });

    test('la 25K est TOUJOURS au milieu (index 1) quand présente', () {
      for (final z in [12.0, 13.0, 14.0, 15.0, 20.0]) {
        final order = MarineMapService.layerOrderForZoom(z);
        if (order.length >= 2) {
          expect(order[1], contains('25'), reason: 'zoom $z');
        }
      }
    });

    test('la 10K est TOUJOURS en haut (dernier index) quand présente', () {
      for (final z in [14.0, 15.0, 16.0, 20.0]) {
        final order = MarineMapService.layerOrderForZoom(z);
        if (order.length >= 3) {
          expect(order.last, contains('10'), reason: 'zoom $z');
        }
      }
    });
  });
}
