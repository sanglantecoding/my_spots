/// Placeholder hydrique unique, à calibrer avec des observations réelles.
/// Ces valeurs de développement ne sont pas des seuils mycologiques validés.
class HydricConfig {
  HydricConfig._();

  /// Humidité volumique considérée humide, en pourcentage.
  static const double wetThresholdPercent = 25;

  /// Nombre placeholder de jours humides pour une persistance complète.
  static const int wetMinDays = 5;

  /// Pluie journalière minimale comptée comme jour pluvieux (mm).
  static const double rainDayMm = 2;

  /// Fenêtre récente de pluie et bilan hydrique (jours).
  static const int window = 14;

  /// Fenêtre de sécheresse antérieure à l'épisode pluvieux (jours).
  static const int drynessWindow = 30;

  /// Couche native ECMWF IFS prioritaire pour l'humidité (cm), sans interpolation.
  static const (double, double) soilLayerDepth = (7, 28);

  /// Couche native de repli ECMWF IFS si 7–28 cm n'est pas fournie.
  static const (double, double) soilLayerFallbackDepth = (0, 7);

  /// Seuil placeholder à partir duquel la porte hydrique cesse de limiter l'indice.
  static const double gateFullAt = 0.5;
}
