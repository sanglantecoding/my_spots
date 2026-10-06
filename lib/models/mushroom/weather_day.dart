/// Données météo pour un jour donné à une position.
class WeatherDay {
  final DateTime date;
  final double temperatureMin; // °C
  final double temperatureMax; // °C
  final double temperatureMean; // °C
  final double precipitation; // mm
  final double humidity; // % (0-100)
  final double? et0; // mm (Évapotranspiration de référence, si disponible)
  final double? windSpeed; // m/s (Vitesse du vent, si disponible)
  final double? windGust; // m/s (Rafales de vent, si disponible)
  final double? solarRadiation; // W/m² (Rayonnement solaire, si disponible)

  WeatherDay({
    required this.date,
    required this.temperatureMin,
    required this.temperatureMax,
    required this.temperatureMean,
    required this.precipitation,
    required this.humidity,
    this.et0,
    this.windSpeed,
    this.windGust,
    this.solarRadiation,
  });

  /// Crée une instance mockée pour les tests/développement.
  factory WeatherDay.mock({
    DateTime? date,
    double tempMin = 15.0,
    double tempMax = 25.0,
    double tempMean = 20.0,
    double precip = 5.0,
    double humidity = 70.0,
    double? et0,
    double? windSpeed,
    double? windGust,
    double? solarRadiation,
  }) {
    return WeatherDay(
      date: date ?? DateTime.now(),
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

  /// Pluie cumulée sur une période de jours.
  static double cumulativePrecipitation(List<WeatherDay> days) {
    return days.fold(0.0, (sum, day) => sum + day.precipitation);
  }

  /// Température moyenne sur une période de jours.
  static double meanTemperature(List<WeatherDay> days) {
    if (days.isEmpty) return 0.0;
    return days.fold(0.0, (sum, day) => sum + day.temperatureMean) /
        days.length;
  }
}
