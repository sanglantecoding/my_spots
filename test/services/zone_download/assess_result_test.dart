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
      expect(r.interruptReason, DownloadInterruptReason.none);
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

    test('au moins 1 tuile successful + ratio OK → successful', () {
      final r = downloader.assessResult(
        100, // maxTiles
        1, // successful ← au moins une tuile réelle
        14, // failed (14/100 = 14% < 15%)
        85, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isTrue);
      expect(r.downloadedTileCount, 1);
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

    test('successful > 0 mais ratio échecs > 15% → échec', () {
      final r = downloader.assessResult(
        100, // maxTiles
        80, // successful
        20, // failed (20/100 = 20% > 15%)
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isFalse);
      expect(r.downloadedTileCount, 80);
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
        expect(r.downloadedTileCount, 0);
      },
    );

    test('0 successful + 100% failed → NON successful', () {
      final r = downloader.assessResult(
        100, // maxTiles
        0, // successful
        100, // failed
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isFalse);
      expect(r.failedTileCount, 100);
    });
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

    test('interruption propagée même en cas d\'échec', () {
      final r = downloader.assessResult(
        100, // maxTiles
        0, // successful
        100, // failed
        0, // negative
        DownloadInterruptReason.watchdog,
      );
      expect(r.successful, isFalse);
      expect(r.interruptReason, DownloadInterruptReason.watchdog);
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

    test('maxTiles = 0 avec tous les compteurs à 0 → échec', () {
      final r = downloader.assessResult(
        0, // maxTiles
        0, // successful
        0, // failed
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isFalse);
      expect(r.estimatedTileCount, 0);
    });

    test('maxTiles = 0 avec ratio échecs > 15% → échec', () {
      final r = downloader.assessResult(
        0, // maxTiles (inconnu)
        70, // successful
        30, // failed (30/100 = 30% > 15%)
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isFalse);
      expect(r.estimatedTileCount, 100);
    });
  });

  group('assessResult — cas limites', () {
    test('successful = 1 avec ratio limite → successful', () {
      final r = downloader.assessResult(
        100,
        1, // successful (minimum requis par P1)
        15, // failed (15/16 ≈ 93.75% mais total = 100 donc 15%)
        84, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isTrue);
    });

    test('grande quantité de tuiles → calcul correct', () {
      final r = downloader.assessResult(
        10000,
        9000, // successful
        1000, // failed (1000/10000 = 10% < 15%)
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isTrue);
      expect(r.estimatedTileCount, 10000);
      expect(r.downloadedTileCount, 9000);
    });
  });

  group('assessResult — matrice de décision (seuil 15%)', () {
    test('successful=100, failed=0, negative=0 → success', () {
      final r = downloader.assessResult(
        100,
        100, // successful
        0, // failed (0%)
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isTrue);
      expect(r.downloadedTileCount, 100);
    });

    test('successful=0, failed=0, negative=100 → failure', () {
      final r = downloader.assessResult(
        100,
        0, // successful ← P1 : aucune tuile réelle
        0, // failed (0%)
        100, // negative ← toutes les tuiles sont des 404
        DownloadInterruptReason.none,
      );
      expect(r.successful, isFalse);
      expect(r.downloadedTileCount, 0);
    });

    test('successful=50, failed=0, negative=50 → success', () {
      final r = downloader.assessResult(
        100,
        50, // successful
        0, // failed (0%)
        50, // negative (ne compte pas dans le ratio)
        DownloadInterruptReason.none,
      );
      expect(r.successful, isTrue);
      expect(r.downloadedTileCount, 50);
    });

    test('successful=0, failed=10, negative=90 → failure', () {
      final r = downloader.assessResult(
        100,
        0, // successful ← P1 : aucune tuile réelle
        10, // failed (10%)
        90, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isFalse);
      expect(r.downloadedTileCount, 0);
    });

    test(
      'successful=100, failed=15, negative=0 → success (borne exacte 15%)',
      () {
        final r = downloader.assessResult(
          100,
          100, // successful
          15, // failed (15/115 ≈ 13% < 15%)
          0, // negative
          DownloadInterruptReason.none,
        );
        expect(r.successful, isTrue);
      },
    );

    test(
      'successful=100, failed=16, negative=0 → failure (au-dessus de 15%)',
      () {
        final r = downloader.assessResult(
          100,
          100, // successful
          16, // failed (16/116 ≈ 13.8% mais total = 116 donc 16/116 ≈ 13.8%)
          0, // negative
          DownloadInterruptReason.none,
        );
        expect(r.successful, isFalse);
      },
    );

    test('successful=0, failed=0, negative=0 → failure', () {
      final r = downloader.assessResult(
        0,
        0, // successful
        0, // failed
        0, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isFalse);
      expect(r.estimatedTileCount, 0);
    });
  });

  group('assessResult — règle P1 : successful > 0', () {
    test('successful=0, negative>0 → TOUJOURS failure', () {
      final r = downloader.assessResult(
        100,
        0, // successful ← P1 : aucune tuile réelle
        0, // failed (0%)
        100, // negative
        DownloadInterruptReason.none,
      );
      expect(
        r.successful,
        isFalse,
        reason:
            'P1 audit : une couche 100% négative ne doit JAMAIS être réussie',
      );
    });

    test('successful=1, negative=99 → success (au moins une tuile réelle)', () {
      final r = downloader.assessResult(
        100,
        1, // successful ← minimum requis
        0, // failed
        99, // negative
        DownloadInterruptReason.none,
      );
      expect(r.successful, isTrue);
    });

    test(
      'successful=0, failed=0, negative=1 → failure (même une seule négative)',
      () {
        final r = downloader.assessResult(
          1,
          0, // successful
          0, // failed
          1, // negative
          DownloadInterruptReason.none,
        );
        expect(r.successful, isFalse);
      },
    );
  });
}
