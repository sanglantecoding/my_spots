/// Origine temporelle d'une observation météo.
enum WeatherDataKind { historical, forecast }

/// Agrégation d'une fenêtre de jours, avec couverture explicite.
///
/// [value] n'est calculé qu'à partir des mesures présentes. Les jours
/// manquants ne sont ni interpolés ni remplacés. [isComplete] est faux
/// dès qu'au moins une valeur de la fenêtre est absente.
class WeatherAggregate {
  const WeatherAggregate({
    required this.value,
    required this.windowLength,
    required this.observedCount,
  });

  /// Somme ou moyenne des mesures observées, ou `null` s'il n'y en a aucune.
  final double? value;

  /// Nombre de jours dans la fenêtre demandée.
  final int windowLength;

  /// Nombre de jours pour lesquels la mesure agrégée est présente.
  final int observedCount;

  bool get isEmpty => observedCount == 0;

  bool get isComplete => windowLength > 0 && observedCount == windowLength;

  bool get isPartial => observedCount > 0 && observedCount < windowLength;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherAggregate &&
          value == other.value &&
          windowLength == other.windowLength &&
          observedCount == other.observedCount;

  @override
  int get hashCode => Object.hash(value, windowLength, observedCount);
}

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
