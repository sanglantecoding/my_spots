import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_observation.dart';

void main() {
  group('MushroomObservation serialization', () {
    final observation = MushroomObservation(
      id: 'obs-1',
      date: DateTime(2026, 10, 8),
      latitude: 45.2,
      longitude: 2.1,
      abundance: MushroomAbundance.none,
      approximateCount: 0,
      microHabitats: const [
        MushroomMicroHabitat.streamEdge,
        MushroomMicroHabitat.clearing,
      ],
      notes: 'Sortie sans récolte',
      forecastSnapshot: const MushroomForecastSnapshot(
        index: 37,
        confidence: 0.74,
        factors: {
          'water': 0.2,
          'temperature': null,
          'drying': 0.8,
          'terrain': null,
          'forest': null,
          'shock': 0.5,
        },
        habitat: HabitatStatus.unknown,
        habitatReason: 'Altitude inconnue',
        hydricGate: 0.4,
        wetStreak: 2,
        dryBefore: 18,
        shockRainMm: 22,
        shockTempDropC: 4,
        temperatureSource: 'air',
        dataSources: {'weather': 'Open-Meteo'},
      ),
    );

    test('aller-retour JSON conserve tous les champs et le snapshot', () {
      final decoded = MushroomObservation.fromJson(
        jsonDecode(jsonEncode(observation.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.id, observation.id);
      expect(decoded.date, observation.date);
      expect(decoded.latitude, observation.latitude);
      expect(decoded.longitude, observation.longitude);
      expect(decoded.species, observation.species);
      expect(decoded.abundance, MushroomAbundance.none);
      expect(decoded.approximateCount, 0);
      expect(decoded.microHabitats, observation.microHabitats);
      expect(decoded.notes, observation.notes);
      expect(decoded.forecastSnapshot?.index, 37);
      expect(decoded.forecastSnapshot?.factors['temperature'], isNull);
      expect(decoded.forecastSnapshot?.habitat, HabitatStatus.unknown);
      expect(decoded.forecastSnapshot?.hydricGate, 0.4);
      expect(decoded.forecastSnapshot?.wetStreak, 2);
      expect(decoded.forecastSnapshot?.shockRainMm, 22);
      expect(decoded.forecastSnapshot?.dataSources['weather'], 'Open-Meteo');
    });

    test('observation sans prévision conserve un snapshot null', () {
      final noSnapshot = MushroomObservation(
        id: 'obs-2',
        date: DateTime(2026, 10, 8),
        latitude: 45,
        longitude: 2,
        abundance: MushroomAbundance.few,
      );
      final decoded = MushroomObservation.fromJson(noSnapshot.toJson());
      expect(decoded.forecastSnapshot, isNull);
    });
  });
}
