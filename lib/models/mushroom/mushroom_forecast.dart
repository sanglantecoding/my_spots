import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';

/// Prévision de conditions favorables aux champignons pour une position et un jour.
class MushroomForecast {
  final DateTime date;
  final MushroomSpecies species;
  final int index; // 0-100 : conditions favorables
  final double confidence; // 0-1 : confiance dans la prédiction
  final ForecastFactors factors;
  final HabitatStatus habitat;
  final String? habitatReason;

  /// Nombre observé de jours consécutifs humides, null si inconnu.
  final int? wetStreak;

  /// Nombre de jours secs observés avant l'épisode pluvieux récent.
  final int? dryBefore;
  final bool soilMoistureAvailable;
  final double? soilMoisture0To7Percent;
  final double? soilMoisture7To28Percent;
  final double? soilMoisture7To28Min60dPercent;
  final double? soilMoisture7To28Median60dPercent;
  final double? soilMoisture7To28Max60dPercent;
  final double? soilMoisture7To28Percentile60d;
  final double? soilTemperature0To7C;

  /// Porte hydrique appliquée à l'indice, entre 0 et 1.
  final double? hydricGate;
  final DateTime? shockDate;
  final double? shockRainMm;
  final double? shockTempDropC;
  final String? temperatureSource;

  /// Sources réellement fournies par les services, absentes si inconnues.
  final Map<String, String?> dataSources;

  MushroomForecast({
    required this.date,
    required this.species,
    required this.index,
    required this.confidence,
    required this.factors,
    this.habitat = HabitatStatus.suitable,
    this.habitatReason,
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
    this.hydricGate,
    this.shockDate,
    this.shockRainMm,
    this.shockTempDropC,
    this.temperatureSource,
    this.dataSources = const {},
  });

  /// Crée une instance mockée pour les tests/développement.
  factory MushroomForecast.mock({
    DateTime? date,
    MushroomSpecies species = MushroomSpecies.boletusEdulis,
    int index = 50,
    double confidence = 0.7,
    ForecastFactors? factors,
    HabitatStatus habitat = HabitatStatus.suitable,
    String? habitatReason,
    int? wetStreak,
    int? dryBefore,
    bool soilMoistureAvailable = false,
    double? soilMoisture0To7Percent,
    double? soilMoisture7To28Percent,
    double? soilMoisture7To28Min60dPercent,
    double? soilMoisture7To28Median60dPercent,
    double? soilMoisture7To28Max60dPercent,
    double? soilMoisture7To28Percentile60d,
    double? soilTemperature0To7C,
    double? hydricGate,
    DateTime? shockDate,
    double? shockRainMm,
    double? shockTempDropC,
    String? temperatureSource,
    Map<String, String?> dataSources = const {},
  }) {
    return MushroomForecast(
      date: date ?? DateTime.now(),
      species: species,
      index: index,
      confidence: confidence,
      factors: factors ?? ForecastFactors.mock(),
      habitat: habitat,
      habitatReason: habitatReason,
      wetStreak: wetStreak,
      dryBefore: dryBefore,
      soilMoistureAvailable: soilMoistureAvailable,
      soilMoisture0To7Percent: soilMoisture0To7Percent,
      soilMoisture7To28Percent: soilMoisture7To28Percent,
      soilMoisture7To28Min60dPercent: soilMoisture7To28Min60dPercent,
      soilMoisture7To28Median60dPercent: soilMoisture7To28Median60dPercent,
      soilMoisture7To28Max60dPercent: soilMoisture7To28Max60dPercent,
      soilMoisture7To28Percentile60d: soilMoisture7To28Percentile60d,
      soilTemperature0To7C: soilTemperature0To7C,
      hydricGate: hydricGate,
      shockDate: shockDate,
      shockRainMm: shockRainMm,
      shockTempDropC: shockTempDropC,
      temperatureSource: temperatureSource,
      dataSources: dataSources,
    );
  }
}

/// Facteurs détaillés contribuant à l'indice de prévision.
class ForecastFactors {
  final double? waterFactor; // null si inconnue
  final double? temperatureFactor; // null si inconnue
  final double dryingFactor; // 0-1 : contribution dessèchement
  final double? terrainFactor; // 0-1 : contribution terrain (pente, exposition)
  final double? forestFactor; // 0-1 : contribution forêt/type
  final double? shockFactor; // null si la donnée est inconnue

  ForecastFactors({
    required this.waterFactor,
    required this.temperatureFactor,
    required this.dryingFactor,
    required this.terrainFactor,
    required this.forestFactor,
    this.shockFactor,
  });

  /// Crée une instance mockée pour les tests/développement.
  factory ForecastFactors.mock({
    double? water = 0.5,
    double? temperature = 0.5,
    double drying = 0.5,
    double terrain = 0.5,
    double forest = 0.5,
    double? shock = 0.5,
  }) {
    return ForecastFactors(
      waterFactor: water,
      temperatureFactor: temperature,
      dryingFactor: drying,
      terrainFactor: terrain,
      forestFactor: forest,
      shockFactor: shock,
    );
  }
}
