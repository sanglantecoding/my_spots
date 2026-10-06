/// Données d'humidité du sol pour une position et une profondeur.
class SoilMoistureData {
  final DateTime date;
  final double depthStart; // cm (profondeur début de la couche)
  final double depthEnd; // cm (profondeur fin de la couche)
  final double soilMoisture; // % volumique (0-100)
  final double? soilTemperature; // °C (température du sol, si disponible)
  final double? soilWaterIndex; // Index normalisé (0-1) si disponible
  final String?
  source; // Source des données (ex: "open-meteo", "smos", si disponible)

  SoilMoistureData({
    required this.date,
    required this.depthStart,
    required this.depthEnd,
    required this.soilMoisture,
    this.soilTemperature,
    this.soilWaterIndex,
    this.source,
  });

  /// Crée une instance mockée pour les tests/développement.
  factory SoilMoistureData.mock({
    DateTime? date,
    double depthStart = 0.0,
    double depthEnd = 7.0,
    double moisture = 30.0,
    double? soilTemperature,
    double? swi,
    String? source,
  }) {
    return SoilMoistureData(
      date: date ?? DateTime.now(),
      depthStart: depthStart,
      depthEnd: depthEnd,
      soilMoisture: moisture,
      soilTemperature: soilTemperature,
      soilWaterIndex: swi,
      source: source,
    );
  }
}
