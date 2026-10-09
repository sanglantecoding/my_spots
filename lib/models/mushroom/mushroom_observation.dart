import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';

enum MushroomAbundance { none, few, many }

extension MushroomAbundanceLabel on MushroomAbundance {
  String get label => switch (this) {
    MushroomAbundance.none => 'Aucun',
    MushroomAbundance.few => 'Quelques-uns',
    MushroomAbundance.many => 'Beaucoup',
  };
}

enum MushroomMicroHabitat {
  streamEdge,
  understory,
  forestEdge,
  clearing,
  other,
}

extension MushroomMicroHabitatLabel on MushroomMicroHabitat {
  String get label => switch (this) {
    MushroomMicroHabitat.streamEdge => 'Bord de ruisseau',
    MushroomMicroHabitat.understory => 'Sous-bois',
    MushroomMicroHabitat.forestEdge => 'Lisière',
    MushroomMicroHabitat.clearing => 'Clairière',
    MushroomMicroHabitat.other => 'Autre',
  };
}

/// Instantané autonome des valeurs et sources réellement affichées.
class MushroomForecastSnapshot {
  final int index;
  final double confidence;
  final Map<String, double?> factors;
  final HabitatStatus habitat;
  final String? habitatReason;
  final double? hydricGate;
  final int? wetStreak;
  final int? dryBefore;
  final bool soilMoistureAvailable;
  final double? soilMoisture0To7Percent;
  final double? soilMoisture7To28Percent;
  final double? soilMoisture7To28Min60dPercent;
  final double? soilMoisture7To28Median60dPercent;
  final double? soilMoisture7To28Max60dPercent;
  final double? soilMoisture7To28Percentile60d;
  final double? soilTemperature0To7C;
  final DateTime? shockDate;
  final double? shockRainMm;
  final double? shockTempDropC;
  final String? temperatureSource;
  final Map<String, String?> dataSources;

  const MushroomForecastSnapshot({
    required this.index,
    required this.confidence,
    required this.factors,
    required this.habitat,
    this.habitatReason,
    this.hydricGate,
    this.wetStreak,
    this.dryBefore,
    this.soilMoistureAvailable = false,
    this.soilMoisture0To7Percent,
    this.soilMoisture7To28Percent,
    this.soilMoisture7To28Min60dPercent,
    this.soilMoisture7To28Median60dPercent,
    this.soilMoisture7To28Max60dPercent,
    this.soilMoisture7To28Percentile60d,
    this.soilTemperature0To7C,
    this.shockDate,
    this.shockRainMm,
    this.shockTempDropC,
    this.temperatureSource,
    this.dataSources = const {},
  });

  factory MushroomForecastSnapshot.fromForecast(MushroomForecast forecast) =>
      MushroomForecastSnapshot(
        index: forecast.index,
        confidence: forecast.confidence,
        factors: {
          'water': forecast.factors.waterFactor,
          'temperature': forecast.factors.temperatureFactor,
          'drying': forecast.factors.dryingFactor,
          'terrain': forecast.factors.terrainFactor,
          'forest': forecast.factors.forestFactor,
          'shock': forecast.factors.shockFactor,
        },
        habitat: forecast.habitat,
        habitatReason: forecast.habitatReason,
        hydricGate: forecast.hydricGate,
        wetStreak: forecast.wetStreak,
        dryBefore: forecast.dryBefore,
        soilMoistureAvailable: forecast.soilMoistureAvailable,
        soilMoisture0To7Percent: forecast.soilMoisture0To7Percent,
        soilMoisture7To28Percent: forecast.soilMoisture7To28Percent,
        soilMoisture7To28Min60dPercent: forecast.soilMoisture7To28Min60dPercent,
        soilMoisture7To28Median60dPercent:
            forecast.soilMoisture7To28Median60dPercent,
        soilMoisture7To28Max60dPercent: forecast.soilMoisture7To28Max60dPercent,
        soilMoisture7To28Percentile60d: forecast.soilMoisture7To28Percentile60d,
        soilTemperature0To7C: forecast.soilTemperature0To7C,
        shockDate: forecast.shockDate,
        shockRainMm: forecast.shockRainMm,
        shockTempDropC: forecast.shockTempDropC,
        temperatureSource: forecast.temperatureSource,
        dataSources: Map.unmodifiable(forecast.dataSources),
      );

  Map<String, dynamic> toJson() => {
    'index': index,
    'confidence': confidence,
    'factors': factors,
    'habitat': habitat.name,
    'habitatReason': habitatReason,
    'hydricGate': hydricGate,
    'wetStreak': wetStreak,
    'dryBefore': dryBefore,
    'soilMoistureAvailable': soilMoistureAvailable,
    'soilMoisture0To7Percent': soilMoisture0To7Percent,
    'soilMoisture7To28Percent': soilMoisture7To28Percent,
    'soilMoisture7To28Min60dPercent': soilMoisture7To28Min60dPercent,
    'soilMoisture7To28Median60dPercent': soilMoisture7To28Median60dPercent,
    'soilMoisture7To28Max60dPercent': soilMoisture7To28Max60dPercent,
    'soilMoisture7To28Percentile60d': soilMoisture7To28Percentile60d,
    'soilTemperature0To7C': soilTemperature0To7C,
    'shockDate': shockDate?.toIso8601String(),
    'shockRainMm': shockRainMm,
    'shockTempDropC': shockTempDropC,
    'temperatureSource': temperatureSource,
    'dataSources': dataSources,
  };

  factory MushroomForecastSnapshot.fromJson(Map<String, dynamic> json) {
    final rawFactors = json['factors'];
    final rawSources = json['dataSources'];
    return MushroomForecastSnapshot(
      index: (json['index'] as num).toInt(),
      confidence: (json['confidence'] as num).toDouble(),
      factors: rawFactors is Map
          ? rawFactors.map(
              (key, value) =>
                  MapEntry(key.toString(), (value as num?)?.toDouble()),
            )
          : const {},
      habitat: HabitatStatus.values.firstWhere(
        (value) => value.name == json['habitat'],
        orElse: () => HabitatStatus.unknown,
      ),
      habitatReason: json['habitatReason'] as String?,
      hydricGate: (json['hydricGate'] as num?)?.toDouble(),
      wetStreak: (json['wetStreak'] as num?)?.toInt(),
      dryBefore: (json['dryBefore'] as num?)?.toInt(),
      soilMoistureAvailable: json['soilMoistureAvailable'] as bool? ?? false,
      soilMoisture0To7Percent: (json['soilMoisture0To7Percent'] as num?)
          ?.toDouble(),
      soilMoisture7To28Percent: (json['soilMoisture7To28Percent'] as num?)
          ?.toDouble(),
      soilMoisture7To28Min60dPercent:
          (json['soilMoisture7To28Min60dPercent'] as num?)?.toDouble(),
      soilMoisture7To28Median60dPercent:
          (json['soilMoisture7To28Median60dPercent'] as num?)?.toDouble(),
      soilMoisture7To28Max60dPercent:
          (json['soilMoisture7To28Max60dPercent'] as num?)?.toDouble(),
      soilMoisture7To28Percentile60d:
          (json['soilMoisture7To28Percentile60d'] as num?)?.toDouble(),
      soilTemperature0To7C: (json['soilTemperature0To7C'] as num?)?.toDouble(),
      shockDate: json['shockDate'] == null
          ? null
          : DateTime.tryParse(json['shockDate'].toString()),
      shockRainMm: (json['shockRainMm'] as num?)?.toDouble(),
      shockTempDropC: (json['shockTempDropC'] as num?)?.toDouble(),
      temperatureSource: json['temperatureSource'] as String?,
      dataSources: rawSources is Map
          ? rawSources.map(
              (key, value) => MapEntry(key.toString(), value as String?),
            )
          : const {},
    );
  }
}

class MushroomObservation {
  final String id;
  final DateTime date;
  final double latitude;
  final double longitude;
  final MushroomSpecies species;
  final MushroomAbundance abundance;
  final int? approximateCount;
  final List<MushroomMicroHabitat> microHabitats;
  final String? notes;
  final MushroomForecastSnapshot? forecastSnapshot;

  const MushroomObservation({
    required this.id,
    required this.date,
    required this.latitude,
    required this.longitude,
    this.species = MushroomSpecies.boletusEdulis,
    required this.abundance,
    this.approximateCount,
    this.microHabitats = const [],
    this.notes,
    this.forecastSnapshot,
  });

  factory MushroomObservation.fromJson(Map<String, dynamic> json) {
    final rawHabitats = json['microHabitats'];
    final rawSnapshot = json['forecastSnapshot'];
    return MushroomObservation(
      id: json['id'] as String,
      date: DateTime.parse(json['date'].toString()),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      species: mushroomSpeciesFromCode(json['species']?.toString() ?? ''),
      abundance: MushroomAbundance.values.firstWhere(
        (value) => value.name == json['abundance'],
      ),
      approximateCount: (json['approximateCount'] as num?)?.toInt(),
      microHabitats: rawHabitats is List
          ? rawHabitats
                .map(
                  (value) => MushroomMicroHabitat.values.firstWhere(
                    (habitat) => habitat.name == value,
                  ),
                )
                .toList(growable: false)
          : const [],
      notes: json['notes'] as String?,
      forecastSnapshot: rawSnapshot is Map
          ? MushroomForecastSnapshot.fromJson(
              Map<String, dynamic>.from(rawSnapshot),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'species': species.code,
    'abundance': abundance.name,
    'approximateCount': approximateCount,
    'microHabitats': microHabitats.map((value) => value.name).toList(),
    'notes': notes,
    'forecastSnapshot': forecastSnapshot?.toJson(),
  };
}
