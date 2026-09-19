import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/services/tile_cache/blank_gray_filter.dart';

/// Tests d'invariants de la détection de pixels "vides".
///
/// Ces valeurs ne sont pas inventées : ce sont les RGBA réellement observés
/// dans les logs terrain (tuiles blanches bruitées du SHOM, terres beiges,
/// eaux bleu clair, fonds sombres, traits magenta). Tout changement futur
/// des tolérances (3 / 190) fera échouer ce fichier immédiatement.
void main() {
  group('isVoidPixel — pixels "vides" (deviennent transparents)', () {
    test('alpha 0 → vide quel que soit le RGB', () {
      expect(BlankGrayFilteringImageProvider.isVoidPixel(0, 0, 0, 0), isTrue);
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(255, 255, 255, 0),
        isTrue,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(128, 200, 30, 0),
        isTrue,
      );
    });

    test('blanc pur → vide', () {
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(255, 255, 255, 255),
        isTrue,
      );
    });

    test('blancs bruités du serveur SHOM (vus en logs) → vides', () {
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(253, 251, 253, 255),
        isTrue,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(249, 249, 249, 255),
        isTrue,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(244, 244, 244, 255),
        isTrue,
      );
    });

    test('gris clair uniforme → vide', () {
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(200, 200, 200, 255),
        isTrue,
      );
    });

    test('borne basse de luminosité : 190 vide, 189 conservé', () {
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(190, 190, 190, 255),
        isTrue,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(189, 189, 189, 255),
        isFalse,
      );
    });

    test('tolérance achromatique : écart 3 vide, écart 4 conservé', () {
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(255, 252, 255, 255),
        isTrue,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(255, 251, 255, 255),
        isFalse,
      );
    });
  });

  group('isVoidPixel — pixels de carte (doivent être conservés)', () {
    test('terres beiges SHOM → conservées', () {
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(249, 237, 188, 255),
        isFalse,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(233, 224, 177, 255),
        isFalse,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(231, 215, 191, 255),
        isFalse,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(204, 196, 156, 255),
        isFalse,
      );
    });

    test('eaux bleu clair et isobathes → conservées', () {
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(199, 222, 241, 255),
        isFalse,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(240, 246, 252, 255),
        isFalse,
      );
    });

    test('fonds sombres, végétation et traits → conservés', () {
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(22, 49, 79, 255),
        isFalse,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(94, 91, 77, 255),
        isFalse,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(145, 162, 141, 255),
        isFalse,
      );
      expect(
        BlankGrayFilteringImageProvider.isVoidPixel(167, 93, 146, 255),
        isFalse,
      );
    });
  });
}
