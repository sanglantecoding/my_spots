import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/zone_download/layer_download_result.dart';
import 'package:my_spots/services/zone_download/repository_interface.dart';
import 'package:my_spots/services/zone_download/zone_download_service.dart';

/// Repository factice : assessLayerResult/finalStatus ne touchent jamais
/// la persistance, donc des méthodes vides suffisent (pas besoin de mockito).
class _FakeRepository extends MapLayerRepository {
  @override
  void save(OfflineMap map) {}

  @override
  void saveLayer(OfflineMap map, OfflineMapLayer layer) {}

  @override
  OfflineMap? findByUuid(String uuid) => null;

  @override
  OfflineMapLayer? findLayerById(int id) => null;
}

OfflineMap _map() => OfflineMap.create(
  uuid: 'z1',
  name: 'Zone test',
  northLat: 1,
  southLat: 0,
  westLng: 0,
  eastLng: 1,
);

void main() {
  final svc = ZoneDownloadService(repository: _FakeRepository());

  group('assessLayerResult — sans interruption', () {
    test('couche complète sans échec → ok', () {
      const r = LayerDownloadResult(
        downloadedTileCount: 100,
        estimatedTileCount: 100,
        successful: true,
      );
      expect(
        svc.assessLayerResult(r, DownloadCancelReason.none),
        LayerOutcome.ok,
      );
    });

    test('tuiles OK + échecs résiduels → partial', () {
      const r = LayerDownloadResult(
        downloadedTileCount: 90,
        estimatedTileCount: 100,
        successful: true,
        failedTileCount: 10,
      );
      expect(
        svc.assessLayerResult(r, DownloadCancelReason.none),
        LayerOutcome.partial,
      );
    });

    test(
      'jugée failed par le downloader malgré des tuiles → networkFailure',
      () {
        const r = LayerDownloadResult(
          downloadedTileCount: 50,
          estimatedTileCount: 100,
          successful: false,
          failedTileCount: 50,
        );
        expect(
          svc.assessLayerResult(r, DownloadCancelReason.none),
          LayerOutcome.networkFailure,
        );
      },
    );

    test('0 tuile + 0 échec (que des négatives) → noCoverage', () {
      const r = LayerDownloadResult(
        downloadedTileCount: 0,
        estimatedTileCount: 100,
        successful: false,
        negativeTileCount: 100,
      );
      expect(
        svc.assessLayerResult(r, DownloadCancelReason.none),
        LayerOutcome.noCoverage,
      );
    });

    test('0 tuile + échecs réseau → networkFailure', () {
      const r = LayerDownloadResult(
        downloadedTileCount: 0,
        estimatedTileCount: 100,
        successful: false,
        failedTileCount: 100,
      );
      expect(
        svc.assessLayerResult(r, DownloadCancelReason.none),
        LayerOutcome.networkFailure,
      );
    });
  });

  group('assessLayerResult — avec interruption', () {
    test('annulé avec tuiles téléchargées → partial', () {
      const r = LayerDownloadResult(
        downloadedTileCount: 40,
        estimatedTileCount: 100,
        successful: true,
      );
      expect(
        svc.assessLayerResult(r, DownloadCancelReason.user),
        LayerOutcome.partial,
      );
    });

    test('watchdog sans aucune tuile → interrupted', () {
      const r = LayerDownloadResult(
        downloadedTileCount: 0,
        estimatedTileCount: 100,
        successful: false,
      );
      expect(
        svc.assessLayerResult(r, DownloadCancelReason.watchdog),
        LayerOutcome.interrupted,
      );
    });
  });

  group('finalStatus — sans interruption', () {
    test('toutes ok → ready + lastError null', () {
      final m = _map();
      expect(
        svc.finalStatus(m, [
          LayerOutcome.ok,
          LayerOutcome.ok,
        ], DownloadCancelReason.none),
        OfflineMapStatus.ready,
      );
      expect(m.lastError, isNull);
    });

    test('ok + partial → partial, sans message', () {
      final m = _map();
      expect(
        svc.finalStatus(m, [
          LayerOutcome.ok,
          LayerOutcome.partial,
        ], DownloadCancelReason.none),
        OfflineMapStatus.partial,
      );
      expect(m.lastError, isNull);
    });

    test('networkFailure seul → failed + message réseau', () {
      final m = _map();
      expect(
        svc.finalStatus(m, [
          LayerOutcome.networkFailure,
        ], DownloadCancelReason.none),
        OfflineMapStatus.failed,
      );
      expect(m.lastError, contains('réseau'));
    });

    test('ok + networkFailure → partial + message réseau', () {
      final m = _map();
      expect(
        svc.finalStatus(m, [
          LayerOutcome.ok,
          LayerOutcome.networkFailure,
        ], DownloadCancelReason.none),
        OfflineMapStatus.partial,
      );
      expect(m.lastError, contains('réseau'));
    });

    test('noCoverage seul → partial + message couverture', () {
      final m = _map();
      expect(
        svc.finalStatus(m, [
          LayerOutcome.noCoverage,
        ], DownloadCancelReason.none),
        OfflineMapStatus.partial,
      );
      expect(m.lastError, contains('sans couverture'));
    });

    test(
      'CAS MIXTE ok + noCoverage → partial + message couverture visible',
      () {
        // Comportement simplifié : le message doit être visible même quand
        // d'autres couches sont ok (ex. marine OK + LiDAR hors campagne).
        final m = _map();
        expect(
          svc.finalStatus(m, [
            LayerOutcome.ok,
            LayerOutcome.noCoverage,
          ], DownloadCancelReason.none),
          OfflineMapStatus.partial,
        );
        expect(m.lastError, contains('sans couverture'));
      },
    );
  });

  group('finalStatus — avec interruption', () {
    test('user + contenu → partial + message annulation', () {
      final m = _map();
      expect(
        svc.finalStatus(m, [
          LayerOutcome.partial,
          LayerOutcome.interrupted,
        ], DownloadCancelReason.user),
        OfflineMapStatus.partial,
      );
      expect(m.lastError, contains('Annulé'));
    });

    test('user sans contenu → notStarted', () {
      final m = _map();
      expect(
        svc.finalStatus(m, [
          LayerOutcome.interrupted,
        ], DownloadCancelReason.user),
        OfflineMapStatus.notStarted,
      );
    });

    test('watchdog sans contenu → failed + message watchdog', () {
      final m = _map();
      expect(
        svc.finalStatus(m, [
          LayerOutcome.interrupted,
        ], DownloadCancelReason.watchdog),
        OfflineMapStatus.failed,
      );
      expect(m.lastError, contains('watchdog'));
    });

    test('watchdog + contenu → partial', () {
      final m = _map();
      expect(
        svc.finalStatus(m, [
          LayerOutcome.partial,
        ], DownloadCancelReason.watchdog),
        OfflineMapStatus.partial,
      );
    });

    test('plafond + contenu → partial + message plafond', () {
      final m = _map();
      expect(
        svc.finalStatus(m, [
          LayerOutcome.partial,
        ], DownloadCancelReason.tileCeiling),
        OfflineMapStatus.partial,
      );
      expect(m.lastError, contains('plafond'));
    });

    test('plafond sans contenu → failed', () {
      final m = _map();
      expect(
        svc.finalStatus(m, [
          LayerOutcome.interrupted,
        ], DownloadCancelReason.tileCeiling),
        OfflineMapStatus.failed,
      );
    });
  });
}
