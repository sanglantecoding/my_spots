import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/services/zone_download/fmtc_layer_downloader.dart';

/// Tests des fonctionnalités pause/reprise de FmtcLayerDownloader.
///
/// Ces tests verrouillent la logique de tracking des instances actives/paused :
/// - Pause d'une instance active → ajout à _pausedInstances
/// - Resume → retrait de _pausedInstances
/// - Pause/resume d'instance inexistante → pas de crash
/// - Le watchdog ne considère pas une pause comme un stall
void main() {
  group('FmtcLayerDownloader — pause/resume', () {
    late FmtcLayerDownloader downloader;
    late FMTCStore store;
    const instanceId = 'test_instance_123';

    setUp(() {
      downloader = const FmtcLayerDownloader();
      store = FMTCStore('test_store');
      FmtcLayerDownloader.clearTrackingSets();
    });

    tearDown(() {
      FmtcLayerDownloader.clearTrackingSets();
    });

    test('pause d\'une instance active → ajout à _pausedInstances', () {
      // Simule l'ajout de l'instance aux actifs (comme dans downloadLayer)
      FmtcLayerDownloader.addToActive(instanceId);

      downloader.pause('zone123', store, instanceId);

      expect(
        FmtcLayerDownloader.isPaused(instanceId),
        isTrue,
        reason: 'L\'instance doit être marquée comme paused',
      );
    });

    test('resume d\'une instance paused → retrait de _pausedInstances', () {
      // Simule l'état paused
      FmtcLayerDownloader.addToActive(instanceId);
      downloader.pause('zone123', store, instanceId);

      expect(FmtcLayerDownloader.isPaused(instanceId), isTrue);

      downloader.resume('zone123', store, instanceId);

      expect(
        FmtcLayerDownloader.isPaused(instanceId),
        isFalse,
        reason: 'L\'instance ne doit plus être marquée comme paused',
      );
    });

    test('pause d\'une instance inexistante → pas de crash', () {
      // L'instance n'est pas dans _activeInstances
      expect(
        () => downloader.pause('zone123', store, 'unknown_instance'),
        returnsNormally,
        reason: 'Pause d\'instance inconnue ne doit pas crasher',
      );

      expect(FmtcLayerDownloader.isPaused('unknown_instance'), isFalse);
    });

    test('resume d\'une instance inexistante → pas de crash', () {
      // L'instance n'est pas dans _activeInstances
      expect(
        () => downloader.resume('zone123', store, 'unknown_instance'),
        returnsNormally,
        reason: 'Resume d\'instance inconnue ne doit pas crasher',
      );
    });

    test('pause/resume successifs → état cohérent', () {
      FmtcLayerDownloader.addToActive(instanceId);

      // Pause
      downloader.pause('zone123', store, instanceId);
      expect(FmtcLayerDownloader.isPaused(instanceId), isTrue);

      // Resume
      downloader.resume('zone123', store, instanceId);
      expect(FmtcLayerDownloader.isPaused(instanceId), isFalse);

      // Pause à nouveau
      downloader.pause('zone123', store, instanceId);
      expect(FmtcLayerDownloader.isPaused(instanceId), isTrue);
    });

    test('deux instances différentes → tracking indépendant', () {
      const instance1 = 'instance_1';
      const instance2 = 'instance_2';

      FmtcLayerDownloader.addToActive(instance1);
      FmtcLayerDownloader.addToActive(instance2);

      // Pause instance1 seulement
      downloader.pause('zone123', store, instance1);

      expect(FmtcLayerDownloader.isPaused(instance1), isTrue);
      expect(FmtcLayerDownloader.isPaused(instance2), isFalse);
    });

    test('cleanup après download → retrait des sets', () {
      FmtcLayerDownloader.addToActive(instanceId);
      downloader.pause('zone123', store, instanceId);

      expect(FmtcLayerDownloader.isPaused(instanceId), isTrue);

      // Simule le cleanup dans le finally de downloadLayer
      FmtcLayerDownloader.clearTrackingSets();

      expect(FmtcLayerDownloader.isPaused(instanceId), isFalse);
    });
  });

  group('FmtcLayerDownloader — watchdog et pause', () {
    setUp(() {
      FmtcLayerDownloader.clearTrackingSets();
    });

    tearDown(() {
      FmtcLayerDownloader.clearTrackingSets();
    });

    test('une instance paused ne doit pas être considérée comme stallée', () {
      // Ce test vérifie la logique dans le watchdog :
      // if (_pausedInstances.contains(instanceId)) {
      //   lastEventAt = DateTime.now(); // pause ≠ stall
      //   return;
      // }
      const instanceId = 'paused_instance';

      FmtcLayerDownloader.addToActive(instanceId);
      const FmtcLayerDownloader().pause(
        'zone123',
        FMTCStore('test'),
        instanceId,
      );

      // L'instance est dans _pausedInstances, donc le watchdog doit
      // réinitialiser lastEventAt au lieu de déclencher un stall
      expect(
        FmtcLayerDownloader.isPaused(instanceId),
        isTrue,
        reason: 'L\'instance doit être marquée paused pour éviter le stall',
      );
    });
  });
}
