import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/mushroom_observation.dart';
import 'package:my_spots/services/mushroom/mushroom_observation_store.dart';

void main() {
  late Directory directory;
  late MushroomObservationStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mushroom-observations-');
    store = MushroomObservationStore(
      file: File('${directory.path}${Platform.pathSeparator}observations.json'),
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'stockage JSON relit les observations, y compris les négatives',
    () async {
      final observation = MushroomObservation(
        id: 'negative',
        date: DateTime(2026, 10, 8),
        latitude: 45,
        longitude: 2,
        abundance: MushroomAbundance.none,
      );
      await store.add(observation);

      final loaded = await store.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.abundance, MushroomAbundance.none);
      expect(await store.exportJson(), contains('negative'));
    },
  );

  test('un fichier corrompu est renommé et lève une exception', () async {
    final file = await store.file;
    await file.parent.create(recursive: true);
    await file.writeAsString('{json tronqué');

    await expectLater(store.load, throwsException);

    // Le fichier corrompu doit avoir été renommé
    expect(await file.exists(), isFalse);
    final corruptFiles = directory.listSync().where(
      (f) => f.path.contains('.corrupt-'),
    );
    expect(corruptFiles, isNotEmpty);
  });

  test('restauration depuis .bak si le fichier principal manque', () async {
    final file = await store.file;
    final backup = File('${file.path}.bak');
    await file.parent.create(recursive: true);

    // Créer un fichier .bak avec une observation
    final observation = MushroomObservation(
      id: 'backup-test',
      date: DateTime(2026, 10, 8),
      latitude: 45,
      longitude: 2,
      abundance: MushroomAbundance.few,
    );
    await backup.writeAsString(jsonEncode([observation.toJson()]));

    // Charger devrait restaurer depuis .bak
    final loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'backup-test');
    expect(await file.exists(), isTrue); // Fichier principal restauré
    expect(await backup.exists(), isFalse); // .bak supprimé après restauration
  });

  test('add et delete ne sauvent pas après un load en échec', () async {
    final file = await store.file;
    await file.parent.create(recursive: true);
    await file.writeAsString('{json tronqué');

    // Le load échoue
    await expectLater(store.load, throwsException);

    // add() devrait lever une exception
    final observation = MushroomObservation(
      id: 'should-fail',
      date: DateTime(2026, 10, 8),
      latitude: 45,
      longitude: 2,
      abundance: MushroomAbundance.few,
    );
    await expectLater(() => store.add(observation), throwsA(isA<StateError>()));

    // Créer un nouveau store pour tester delete indépendamment
    final store2 = MushroomObservationStore(
      file: File(
        '${directory.path}${Platform.pathSeparator}observations2.json',
      ),
    );
    final file2 = await store2.file;
    await file2.parent.create(recursive: true);
    await file2.writeAsString('{json tronqué');

    // Le load échoue sur store2
    await expectLater(store2.load, throwsException);

    // delete() devrait lever une exception
    await expectLater(
      () => store2.delete('any-id'),
      throwsA(isA<StateError>()),
    );
  });

  test('deux add simultanés ne perdent pas de données', () async {
    final obs1 = MushroomObservation(
      id: 'obs1',
      date: DateTime(2026, 10, 8),
      latitude: 45,
      longitude: 2,
      abundance: MushroomAbundance.few,
    );
    final obs2 = MushroomObservation(
      id: 'obs2',
      date: DateTime(2026, 10, 8),
      latitude: 45.1,
      longitude: 2.1,
      abundance: MushroomAbundance.many,
    );

    // Lancer deux add simultanément
    await Future.wait([store.add(obs1), store.add(obs2)]);

    final loaded = await store.load();
    expect(loaded, hasLength(2));
    expect(loaded.any((o) => o.id == 'obs1'), isTrue);
    expect(loaded.any((o) => o.id == 'obs2'), isTrue);
  });

  test('exportJson supprime le fichier temporaire après partage', () async {
    final observation = MushroomObservation(
      id: 'export-test',
      date: DateTime(2026, 10, 8),
      latitude: 45,
      longitude: 2,
      abundance: MushroomAbundance.few,
    );
    await store.add(observation);

    // Créer un fichier d'export temporaire fictif
    final file = await store.file;
    final exportFile = File('${file.path}.export.tmp');
    await exportFile.writeAsString('temp content');

    // exportJson devrait le supprimer
    await store.exportJson();
    expect(await exportFile.exists(), isFalse);
  });
}
