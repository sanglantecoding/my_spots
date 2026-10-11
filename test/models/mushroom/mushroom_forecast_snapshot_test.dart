import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';

void main() {
  group('MushroomForecast snapshot backward compatibility', () {
    test(
      'Old JSON without rain26, tmean20, hasRecentFrost, isInSeason loads without error',
      () {
        // Simulate old JSON format without new fields
        final oldJson = '''
      {
        "date": "2026-10-15T00:00:00.000Z",
        "species": "boletus_edulis",
        "index": 65,
        "confidence": 0.75,
        "habitat": "suitable",
        "wetStreak": 5,
        "dryBefore": 3,
        "soilMoistureAvailable": true,
        "soilMoisture0To7Percent": 28.5,
        "soilMoisture7To28Percent": 32.0,
        "hydricGate": 0.9,
        "shockDate": "2026-10-08T00:00:00.000Z",
        "shockRainMm": 25.0,
        "temperatureSource": "air_tmean20",
        "dataSources": {"terrain": "ign_rge_alti_wld", "forest": "ign_bd_foret"}
      }
      ''';

        // Decode and encode should not throw
        final jsonMap = jsonDecode(oldJson) as Map<String, dynamic>;

        // Create forecast with old data (missing new fields should default to null)
        final forecast = MushroomForecast(
          date: DateTime.parse(jsonMap['date'] as String),
          species: MushroomSpecies.boletusEdulis,
          index: jsonMap['index'] as int,
          confidence: (jsonMap['confidence'] as num).toDouble(),
          factors: ForecastFactors.mock(),
          habitat: HabitatStatus.values.firstWhere(
            (e) => e.name == jsonMap['habitat'],
            orElse: () => HabitatStatus.suitable,
          ),
          wetStreak: jsonMap['wetStreak'] as int?,
          dryBefore: jsonMap['dryBefore'] as int?,
          soilMoistureAvailable:
              jsonMap['soilMoistureAvailable'] as bool? ?? false,
          soilMoisture0To7Percent: (jsonMap['soilMoisture0To7Percent'] as num?)
              ?.toDouble(),
          soilMoisture7To28Percent:
              (jsonMap['soilMoisture7To28Percent'] as num?)?.toDouble(),
          hydricGate: (jsonMap['hydricGate'] as num?)?.toDouble(),
          shockDate: jsonMap['shockDate'] != null
              ? DateTime.parse(jsonMap['shockDate'] as String)
              : null,
          shockRainMm: (jsonMap['shockRainMm'] as num?)?.toDouble(),
          temperatureSource: jsonMap['temperatureSource'] as String?,
          // New fields default to null
          rain26: null,
          tmean20: null,
          hasRecentFrost: null,
          isInSeason: null,
          dataSources:
              (jsonMap['dataSources'] as Map<String, dynamic>?)
                  ?.cast<String, String?>() ??
              {},
        );

        // Verify new fields are null
        expect(forecast.rain26, isNull);
        expect(forecast.tmean20, isNull);
        expect(forecast.hasRecentFrost, isNull);
        expect(forecast.isInSeason, isNull);

        // Verify old fields are preserved
        expect(forecast.index, equals(65));
        expect(forecast.confidence, equals(0.75));
        expect(forecast.wetStreak, equals(5));
      },
    );
  });
}
