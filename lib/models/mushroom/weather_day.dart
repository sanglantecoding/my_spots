/// Origine temporelle d'une observation météo.
enum WeatherDataKind { historical, forecast }

/// Données météo pour un jour donné à une position.
class WeatherDay {
  final DateTime date;
  final WeatherDataKind kind;
  final double? temperatureMin; // °C
  final double? temperatureMax; // °C
  final double? temperatureMean; // °C
  final double? precipitation; // mm
  final double? humidity; // % (0-100)
  final double? et0; // mm (Évapotranspiration de référence, si disponible)
  final double? windSpeed; // m/s (Vitesse du vent, si disponible)
  final double? windGust; // m/s (Rafales de vent, si disponible)
  final double? solarRadiation; // W/m² (Rayonnement solaire, si disponible)

  WeatherDay({
    required this.date,
    this.kind = WeatherDataKind.historical,
    this.temperatureMin,
    this.temperatureMax,
    this.temperatureMean,
    this.precipitation,
    this.humidity,
    this.et0,
    this.windSpeed,
    this.windGust,
    this.solarRadiation,
  });

  /// Crée une instance mockée pour les tests/développement.
  factory WeatherDay.mock({
    DateTime? date,
    WeatherDataKind kind = WeatherDataKind.historical,
    double? tempMin,
    double? tempMax,
    double? tempMean,
    double? precip,
    double? humidity,
    double? et0,
    double? windSpeed,
    double? windGust,
    double? solarRadiation,
  }) {
    return WeatherDay(
      date: date ?? DateTime.now(),
      kind: kind,
      temperatureMin: tempMin,
      temperatureMax: tempMax,
      temperatureMean: tempMean,
      precipitation: precip,
      humidity: humidity,
      et0: et0,
      windSpeed: windSpeed,
      windGust: windGust,
      solarRadiation: solarRadiation,
    );
  }
}
