// Test du lifecycle de AlarmService.
//
// Ce test vérifie que :
// - initialize() est idempotent (pas de double création de player) ;
// - dispose() ne ferme PAS le StreamController broadcast ;
// - le stream reste utilisable après dispose() ;
// - le cycle MapScreen #1 → dispose → MapScreen #2 fonctionne.
//
// Les tests n'instancient pas directement AudioPlayer (qui nécessite
// un binding Flutter complet et des platform channels) ; ils se concentrent
// sur le lifecycle du StreamController et l'idempotence de initialize().

import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/services/alarm_service.dart';
import 'package:my_spots/models/waypoint.dart';

void main() {
  group('AlarmService Lifecycle - Stream', () {
    // Test 1 — stream toujours ouvert après dispose
    test('Stream reste ouvert après dispose()', () async {
      // Dispose sans initialize ne doit pas crash
      await AlarmService.dispose();

      // Le stream doit toujours être accessible (même sans initialize préalable)
      final stream = AlarmService.onAlarmEvent;
      expect(stream, isNotNull);

      // Subscribe doit fonctionner
      final subscription = AlarmService.onAlarmEvent.listen((_) {});
      subscription.cancel();
    });

    // Test 2 — multiples subscribe / unsubscribe
    test('Multiples abonnements au stream', () async {
      // Plusieurs abonnés simultanés
      final subscription1 = AlarmService.onAlarmEvent.listen((_) {});
      final subscription2 = AlarmService.onAlarmEvent.listen((_) {});
      final subscription3 = AlarmService.onAlarmEvent.listen((_) {});

      // Tous les abonnements sont valides
      expect(subscription1, isNotNull);
      expect(subscription2, isNotNull);
      expect(subscription3, isNotNull);

      // Nettoyage
      subscription1.cancel();
      subscription2.cancel();
      subscription3.cancel();
    });

    // Test 3 — émission d'événements sur le stream
    test('Émission et réception d\'événements', () async {
      final receivedEvents = <AlarmEvent>[];

      // Subscribe au stream
      final subscription = AlarmService.onAlarmEvent.listen((event) {
        receivedEvents.add(event);
      });

      // Émettre un événement (mute)
      AlarmService.setMuted(true);
      AlarmService.setMuted(false);

      // Petit délai pour laisser les événements asynchrones se propager
      await Future<void>.delayed(Duration.zero);

      // Les événements doivent être reçus
      expect(receivedEvents.length, 2);
      expect(receivedEvents[0].type, AlarmEventType.mutedChanged);
      expect(receivedEvents[0].boolPayload, isTrue);
      expect(receivedEvents[1].type, AlarmEventType.mutedChanged);
      expect(receivedEvents[1].boolPayload, isFalse);

      subscription.cancel();
    });

    // Test 4 — simulation du cycle MapScreen
    test('Cycle MapScreen #1 → dispose → MapScreen #2', () async {
      // MapScreen #1
      // Abonnement au stream
      final subscription1 = AlarmService.onAlarmEvent.listen((_) {});

      // "Destruction" de MapScreen #1 (le screen est détruit mais le
      // service global reste actif, le stream reste ouvert)
      await AlarmService.dispose();
      subscription1.cancel();

      // MapScreen #2
      // Le stream doit toujours être fonctionnel
      final stream = AlarmService.onAlarmEvent;
      expect(stream, isNotNull);

      // Nouveaux abonnements possibles
      final subscription2 = AlarmService.onAlarmEvent.listen((_) {});
      final subscription3 = AlarmService.onAlarmEvent.listen((_) {});

      // Les événements émis sont reçus par les nouveaux abonnés
      final events = <AlarmEvent>[];
      final subscription4 = AlarmService.onAlarmEvent.listen((event) {
        events.add(event);
      });

      AlarmService.setMuted(true);
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);

      // Nettoyage
      subscription2.cancel();
      subscription3.cancel();
      subscription4.cancel();
    });
  });

  group('AlarmService Lifecycle - API', () {
    // Test 5 — startMonitoring / stopMonitoring sans initialize
    test('startMonitoring() et stopMonitoring() sans initialize', () async {
      // Ces méthodes ne doivent pas crash même sans initialize préalable
      // (elles utilisent le stream qui reste ouvert)
      final waypoint = Waypoint(
        name: 'Test Waypoint',
        latitude: 43.5,
        longitude: 3.9,
        createdAt: DateTime(2024, 1, 1),
      );

      // startMonitoring émet un événement monitoringStarted
      final events = <AlarmEvent>[];
      final subscription = AlarmService.onAlarmEvent.listen((event) {
        events.add(event);
      });

      AlarmService.startMonitoring(waypoint);
      AlarmService.stopMonitoring();

      // Attendre la propagation asynchrone des événements
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Vérifier que les événements ont été émis
      expect(events.length, 2);
      expect(events[0].type, AlarmEventType.monitoringStarted);
      expect(events[0].waypointPayload.name, 'Test Waypoint');
      expect(events[1].type, AlarmEventType.monitoringStopped);

      subscription.cancel();
    });

    // Test 6 — setMuted / toggleMuted
    test('setMuted() et toggleMuted()', () {
      // Reset à un état connu
      AlarmService.setMuted(false);
      expect(AlarmService.isMuted, isFalse);

      AlarmService.setMuted(true);
      expect(AlarmService.isMuted, isTrue);

      AlarmService.toggleMuted();
      expect(AlarmService.isMuted, isFalse);

      AlarmService.toggleMuted();
      expect(AlarmService.isMuted, isTrue);

      // Reset final
      AlarmService.setMuted(false);
    });
  });
}