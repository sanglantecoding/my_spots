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

  /// Pluie cumulée sur 26 jours (mm), null si moins de 21 jours de données.
  final double? rain26;

  /// Température moyenne de l'air sur 20 jours (°C), null si moins de 16 jours.
  final double? tmean20;

  /// Indique s'il y a un gel récent (multiplicateur < 1.0).
  final bool? hasRecentFrost;

  /// Indique si la date est hors saison (multiplicateur < 1.0).
  final bool? isInSeason;

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
    this.rain26,
    this.tmean20,
    this.hasRecentFrost,
    this.isInSeason,
    this.dataSources = const {},
  });

  MushroomForecast copyWith({
    int? index,
    double? confidence,
    HabitatStatus? habitat,
    String? habitatReason,
    Map<String, String?>? dataSources,
  }) => MushroomForecast(
    date: date,
    species: species,
    index: index ?? this.index,
    confidence: confidence ?? this.confidence,
    factors: factors,
    habitat: habitat ?? this.habitat,
    habitatReason: habitatReason ?? this.habitatReason,
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
    rain26: rain26,
    tmean20: tmean20,
    hasRecentFrost: hasRecentFrost,
    isInSeason: isInSeason,
    dataSources: dataSources ?? this.dataSources,
  );

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
    double? rain26,
    double? tmean20,
    bool? hasRecentFrost,
    bool? isInSeason,
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
      rain26: rain26,
      tmean20: tmean20,
      isInSeason: isInSeason,
      hasRecentFrost: hasRecentFrost,
      dataSources: dataSources,
    );
  }

  /// Crée une prévision exclue (habitat non adapté).
  factory MushroomForecast.excluded({
    required DateTime date,
    required MushroomSpecies species,
    required HabitatStatus habitat,
    String? habitatReason,
    Map<String, String?> dataSources = const {},
  }) {
    return MushroomForecast(
      date: date,
      species: species,
      index: 0,
      confidence: 1.0,
      habitat: habitat,
      habitatReason: habitatReason,
      factors: ForecastFactors(
        waterFactor: null,
        temperatureFactor: null,
        dryingFactor: 0,
        terrainFactor: null,
        forestFactor: null,
        shockFactor: null,
      ),
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
