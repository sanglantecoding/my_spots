/// Configuration des poids du modèle pour BoletusEdulisModel.
///
/// Sources : préprint Brejon Lamartinière & Hoffman (hêtraie allemande, 2015-2024, non relu par des pairs)
/// À recalibrer avec mes observations (Haut-Languedoc).
///
/// Ces valeurs sont des HYPOTHÈSES à calibrer, aucune donnée inventée.
class ModelWeights {
  ModelWeights._();

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

  /// Décalage provisoire entre l'événement et la date estimée (jours).
  static const int lagMinDays = 6;
  static const int lagMaxDays = 10;

  /// Poids provisoires des facteurs globaux (à renormaliser si inconnus).
  static const double waterWeight = 0.30;
  static const double airOrSoilTemperatureWeight = 0.20;
  static const double dryingWeight = 0.10;
  static const double shockWeight = 0.10;
  static const double terrainWeight = 0.15;
  static const double forestWeight = 0.15;
}
