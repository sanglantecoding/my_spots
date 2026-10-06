/// Origine temporelle d'une observation d'humidité du sol.
enum SoilMoistureDataKind { historical, forecast }

/// Données d'humidité du sol pour une position et une profondeur.
class SoilMoistureData {
  final DateTime date;
  final SoilMoistureDataKind kind;
  final double depthStart; // cm (profondeur début de la couche)
  final double depthEnd; // cm (profondeur fin de la couche)
  final double? soilMoisture; // % volumique (0-100)
  final double? soilTemperature; // °C (température du sol, si disponible)
  final double? soilWaterIndex; // Index normalisé (0-1) si disponible
  final String? source;

  SoilMoistureData({
    required this.date,
    this.kind = SoilMoistureDataKind.historical,
    required this.depthStart,
    required this.depthEnd,
    this.soilMoisture,
    this.soilTemperature,
    this.soilWaterIndex,
    this.source,
  });

  /// Crée une instance mockée pour les tests/développement.
  factory SoilMoistureData.mock({
    DateTime? date,
    SoilMoistureDataKind kind = SoilMoistureDataKind.historical,
    double depthStart = 0.0,
    double depthEnd = 7.0,
    double? moisture,
    double? soilTemperature,
    double? swi,
    String? source,
  }) {
    return SoilMoistureData(
      date: date ?? DateTime.now(),
      kind: kind,
      depthStart: depthStart,
      depthEnd: depthEnd,
      soilMoisture: moisture,
      soilTemperature: soilTemperature,
      soilWaterIndex: swi,
      source: source,
    );
  }
}
