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

  test('un fichier corrompu est ignoré sans exception', () async {
    final file = await store.file;
    await file.parent.create(recursive: true);
    await file.writeAsString('{json tronqué');

    await expectLater(store.load(), completes);
    expect(await store.load(), isEmpty);
  });
}
