import 'package:my_spots/models/mushroom/weather_day.dart';

/// Configuration du gel récent pour le modèle BoletusEdulisModel.
///
/// Sources : préprint Brejon Lamartinière & Hoffman (hêtraie allemande, 2015-2024, non relu par des pairs)
/// à recalibrer avec mes observations (Haut-Languedoc).
///
/// Ces valeurs sont des HYPOTHESES à calibrer, aucune donnée inventée.
class FrostConfig {
  FrostConfig._();

  /// Fenètre de vérification du gel (jours avant la date cible).
  static const int frostWindowDays = 3;

  /// Seuil de gel léger (°C).
  static const double lightFrostThresholdC = 0.0;

  /// Seuil de gel sévère (°C).
  static const double severeFrostThresholdC = -3.0;

  /// Multiplicateur en cas de gel léger.
  static const double lightFrostMultiplier = 0.6;

  /// Multiplicateur en cas de gel sévère.
  static const double severeFrostMultiplier = 0.3;

  /// Calcule le multiplicateur de gel récent pour une date donnée.
  static double frostMultiplier(DateTime targetDate, List<WeatherDay> weather) {
    final byDate = <DateTime, WeatherDay>{};
    for (final day in weather) {
      final date = DateTime.utc(day.date.year, day.date.month, day.date.day);
      if (!date.isAfter(targetDate)) byDate[date] = day;
    }

    double multiplier = 1.0;
    // Vérifier les 3 jours précédents
    for (var i = 1; i <= frostWindowDays; i++) {
      final date = targetDate.subtract(Duration(days: i));
      final day = byDate[DateTime.utc(date.year, date.month, date.day)];
      if (day?.temperatureMin != null) {
        final minTemp = day!.temperatureMin!;
        if (minTemp <= severeFrostThresholdC) {
          multiplier = multiplier < severeFrostMultiplier
              ? multiplier
              : severeFrostMultiplier;
        } else if (minTemp <= lightFrostThresholdC) {
          multiplier = multiplier < lightFrostMultiplier
              ? multiplier
              : lightFrostMultiplier;
        }
      }
    }

    return multiplier;
  }

  /// Indique s'il y a un gel récent.
  static bool hasRecentFrost(DateTime targetDate, List<WeatherDay> weather) {
    return frostMultiplier(targetDate, weather) < 1.0;
  }
}
