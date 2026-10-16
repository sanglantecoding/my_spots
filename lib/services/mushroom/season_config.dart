/// Configuration saisonnière pour le modèle BoletusEdulisModel.
///
/// Sources : préprint Brejon Lamartinière & Hoffman (hêtraie allemande, 2015-2024, non relu par des pairs)
/// À recalibrer avec mes observations (Haut-Languedoc).
///
/// Ces valeurs sont des HYPOTHÈSES à calibrer, aucune donnée inventée.
class SeasonConfig {
  SeasonConfig._();

  /// Début de la saison pleine (20 août).
  static const int fullSeasonStartMonth = 8;
  static const int fullSeasonStartDay = 20;

  /// Fin de la saison pleine (30 novembre).
  static const int fullSeasonEndMonth = 11;
  static const int fullSeasonEndDay = 30;

  /// Durée des rampes d'entrée/sortie de saison (jours).
  static const int rampDays = 15;

  /// Multiplicateur hors saison.
  static const double outOfSeasonMultiplier = 0.15;

  /// Multiplicateur en saison pleine.
  static const double fullSeasonMultiplier = 1.0;

  /// Calcule le multiplicateur saisonnier pour une date donnée.
  static double seasonMultiplier(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final fullStart = DateTime.utc(
      day.year,
      fullSeasonStartMonth,
      fullSeasonStartDay,
    );
    final fullEnd = DateTime.utc(
      day.year,
      fullSeasonEndMonth,
      fullSeasonEndDay,
    );

    // Si la date est dans la période pleine
    if (!day.isBefore(fullStart) && !day.isAfter(fullEnd)) {
      return fullSeasonMultiplier;
    }

    // Rampe d'entrée (avant le début de la saison pleine)
    final rampStart = fullStart.subtract(Duration(days: rampDays));
    if (day.isAfter(rampStart) && day.isBefore(fullStart)) {
      final daysIntoRamp = day.difference(rampStart).inDays;
      final t = daysIntoRamp / rampDays;
      return outOfSeasonMultiplier +
          (fullSeasonMultiplier - outOfSeasonMultiplier) * t;
    }

    // Rampe de sortie (après la fin de la saison pleine)
    final rampEnd = fullEnd.add(Duration(days: rampDays));
    if (day.isAfter(fullEnd) && day.isBefore(rampEnd)) {
      final daysIntoRamp = day.difference(fullEnd).inDays;
      final t = daysIntoRamp / rampDays;
      return fullSeasonMultiplier -
          (fullSeasonMultiplier - outOfSeasonMultiplier) * t;
    }

    // Hors saison
    return outOfSeasonMultiplier;
  }
}
