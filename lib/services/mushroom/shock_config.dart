/// HYPOTHÈSES issues d'un rapport non sourcé, à calibrer avec les observations.
/// Tous les seuils et poids de l'événement choc sont provisoires.
class ShockConfig {
  ShockConfig._();

  /// Couche native ECMWF IFS utilisée pour la température du sol (cm).
  static const (double, double) soilTemperatureLayerDepth = (0, 7);

  /// Fenêtre basse de déclenchement de pluie sur 48 heures (mm).
  static const double rainTriggerMm = 10;

  /// Seuils de pluie forte et très forte sur 48 heures (mm).
  static const double rainMediumMm = 15;
  static const double rainHighMm = 30;

  /// Scores placeholders de la composante pluie.
  static const double rainLowPart = 0.2;
  static const double rainMediumPart = 0.5;
  static const double rainHighPart = 1.0;

  /// Seuils placeholders de baisse thermique (°C) et scores associés.
  static const double temperatureDropMediumC = 3;
  static const double temperatureDropHighC = 5;
  static const double temperatureDropMediumPart = 0.5;
  static const double temperatureDropHighPart = 1.0;
  static const double temperatureDropNoPart = 0.0;

  /// Décalage provisoire entre l'événement et la date estimée (jours).
  static const int lagMinDays = 6;
  static const int lagMaxDays = 10;

  /// Seuils placeholders de température du sol (°C).
  static const double soilTemperatureLowC = 8;
  static const double soilTemperatureOptimalLowC = 12;
  static const double soilTemperatureOptimalHighC = 17;
  static const double soilTemperatureHighC = 22;
  static const double soilTemperatureModeratePart = 0.5;

  /// Poids provisoires des facteurs globaux (à renormaliser si inconnus).
  static const double waterWeight = 0.25;
  static const double airOrSoilTemperatureWeight = 0.15;
  static const double dryingWeight = 0.10;
  static const double shockWeight = 0.20;
  static const double terrainWeight = 0.15;
  static const double forestWeight = 0.15;
}
