import 'package:my_spots/models/mushroom/mushroom_species.dart';

/// Prévision de conditions favorables aux champignons pour une position et un jour.
class MushroomForecast {
  final DateTime date;
  final MushroomSpecies species;
  final int index; // 0-100 : conditions favorables
  final double confidence; // 0-1 : confiance dans la prédiction
  final ForecastFactors factors;

  MushroomForecast({
    required this.date,
    required this.species,
    required this.index,
    required this.confidence,
    required this.factors,
  });

  /// Crée une instance mockée pour les tests/développement.
  factory MushroomForecast.mock({
    DateTime? date,
    MushroomSpecies species = MushroomSpecies.boletusEdulis,
    int index = 50,
    double confidence = 0.7,
    ForecastFactors? factors,
  }) {
    return MushroomForecast(
      date: date ?? DateTime.now(),
      species: species,
      index: index,
      confidence: confidence,
      factors: factors ?? ForecastFactors.mock(),
    );
  }
}

/// Facteurs détaillés contribuant à l'indice de prévision.
class ForecastFactors {
  final double waterFactor; // 0-1 : contribution eau/pluie
  final double temperatureFactor; // 0-1 : contribution température
  final double dryingFactor; // 0-1 : contribution dessèchement
  final double terrainFactor; // 0-1 : contribution terrain (pente, exposition)
  final double forestFactor; // 0-1 : contribution forêt/type

  ForecastFactors({
    required this.waterFactor,
    required this.temperatureFactor,
    required this.dryingFactor,
    required this.terrainFactor,
    required this.forestFactor,
  });

  /// Crée une instance mockée pour les tests/développement.
  factory ForecastFactors.mock({
    double water = 0.5,
    double temperature = 0.5,
    double drying = 0.5,
    double terrain = 0.5,
    double forest = 0.5,
  }) {
    return ForecastFactors(
      waterFactor: water,
      temperatureFactor: temperature,
      dryingFactor: drying,
      terrainFactor: terrain,
      forestFactor: forest,
    );
  }
}
