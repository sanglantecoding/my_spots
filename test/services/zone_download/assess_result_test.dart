import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/services/zone_download/fmtc_layer_downloader.dart';
import 'package:my_spots/services/zone_download/layer_download_result.dart';

/// Tests d'invariants de l'évaluation d'un téléchargement de couche.
///
/// Ces tests verrouillent les règles métier du downloader :
/// - Seuil de tolérance aux échecs réseau (15%)
/// - **P1 audit** : une couche 100% négative ne doit JAMAIS être déclarée réussie
/// - Les tuiles négatives (404) ne comptent pas comme des échecs réseau
/// - La raison d'interruption est correctement propagée
///
/// Tout changement futur de la logique fera échouer ce fichier immédiatement.
void main() {
  const downloader = FmtcLayerDownloader();

  group('assessResult — cas réussis', () {
    test('toutes les tuiles réussies → successful', () {
      final r = downloader.assessResult(
        100, // maxTiles
        100, // successful
        0, // failed
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isTrue);
      expect(r.downloadedTileCount, 100);
      expect(r.estimatedTileCount, 100);
      expect(r.failedTileCount, 0);
      expect(r.negativeTileCount, 0);
    });

    test('ratio échecs = 15% (borne exacte) → successful', () {
      final r = downloader.assessResult(
        100, // maxTiles
        85, // successful
        15, // failed (15/100 = 15%)
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isTrue);
      expect(r.downloadedTileCount, 85);
      expect(r.failedTileCount, 15);
    });

    test('ratio échecs < 15% avec négatives → successful', () {
      final r = downloader.assessResult(
        100, // maxTiles
        90, // successful
        10, // failed (10/100 = 10%)
        50, // negative (ne compte pas dans le ratio)
        DownloadInterruptReason.none,
      );
      expect(r.successful, isTrue);
      expect(r.negativeTileCount, 50);
    });
  });

  group('assessResult — cas en échec', () {
    test('ratio échecs = 16% (au-dessus de la borne) → échec', () {
      final r = downloader.assessResult(
        100, // maxTiles
        84, // successful
        16, // failed (16/100 = 16% > 15%)
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isFalse);
    });

    test('ratio échecs élevé → échec', () {
      final r = downloader.assessResult(
        100, // maxTiles
        50, // successful
        50, // failed (50% >> 15%)
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isFalse);
    });

    test('total = 0 → échec', () {
      final r = downloader.assessResult(
        0, // maxTiles
        0, // successful
        0, // failed
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isFalse);
      expect(r.downloadedTileCount, 0);
      expect(r.estimatedTileCount, 0);
    });
  });

  group('assessResult — P1 audit : couche 100% négative', () {
    test('0 successful + 0 failed + 100 negative → NON successful', () {
      // C'est LE bug que le P1 corrige : sans la garde `successful > 0`,
      // failedRatio = 0/100 = 0 → ok = true → couche déclarée réussie
      // alors qu'aucune tuile exploitable n'a été téléchargée.
      final r = downloader.assessResult(
        100, // maxTiles
        0, // successful ← AUCUNE tuile réelle
        0, // failed
        100, // negative ← toutes les tuiles sont des 404
        DownloadInterruptReason.none,
      );
      expect(
        r.successful,
        isFalse,
        reason: 'Une couche 100% négative ne doit JAMAIS être déclarée réussie',
      );
      expect(r.downloadedTileCount, 0);
      expect(r.negativeTileCount, 100);
    });

    test(
      '0 successful + quelques failed + beaucoup de negative → NON successful',
      () {
        final r = downloader.assessResult(
          100, // maxTiles
          0, // successful ← toujours aucune tuile réelle
          10, // failed
          90, // negative
          DownloadInterruptReason.none,
        );
        expect(r.successful, isFalse);
      },
    );
  });

  group('assessResult — propagation de interruptReason', () {
    test('interruption watchdog → propagée dans le résultat', () {
      final r = downloader.assessResult(
        100, // maxTiles
        50, // successful
        0, // failed
        50, // negative
        DownloadInterruptReason.watchdog,
      );
      expect(r.interruptReason, DownloadInterruptReason.watchdog);
    });

    test('interruption tileCeiling → propagée dans le résultat', () {
      final r = downloader.assessResult(
        100, // maxTiles
        50, // successful
        0, // failed
        50, // negative
        DownloadInterruptReason.tileCeiling,
      );
      expect(r.interruptReason, DownloadInterruptReason.tileCeiling);
    });

    test('pas d\'interruption → none', () {
      final r = downloader.assessResult(
        100, // maxTiles
        100, // successful
        0, // failed
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.interruptReason, DownloadInterruptReason.none);
    });
  });

  group('assessResult — calcul de total quand maxTiles = 0', () {
    test(
      'maxTiles = 0 → total calculé depuis successful + failed + negative',
      () {
        final r = downloader.assessResult(
          0, // maxTiles (inconnu)
          80, // successful
          10, // failed
          10, // negative
          DownloadInterruptReason.none,
        );
        expect(r.estimatedTileCount, 100); // 80 + 10 + 10
        expect(r.successful, isTrue); // failedRatio = 10/100 = 10% < 15%
      },
    );
  });
}
