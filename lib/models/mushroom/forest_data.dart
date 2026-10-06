/// Données de forêt/occupation du sol pour une position.
class ForestData {
  final double latitude;
  final double longitude;
  final bool isForest; // true si zone forestière, false sinon
  final String?
  forestType; // Type de forêt (ex: "feuillu", "conifère", "mixte") si isForest=true
  final double? treeDensity; // % (0-100) si isForest=true
  final double? canopyCover; // % couverture forestière (0-100) si isForest=true
  final String?
  source; // Source des données (ex: "ign", "corine", si disponible)

  ForestData({
    required this.latitude,
    required this.longitude,
    required this.isForest,
    this.forestType,
    this.treeDensity,
    this.canopyCover,
    this.source,
  });

  /// Crée une instance mockée pour les tests/développement.
  factory ForestData.mock({
    double lat = 43.5,
    double lng = 3.5,
    bool isForest = true,
    String? forestType,
    double? treeDensity,
    double? canopyCover,
    String? source,
  }) {
    return ForestData(
      latitude: lat,
      longitude: lng,
      isForest: isForest,
      forestType: forestType ?? (isForest ? 'feuillu' : null),
      treeDensity: treeDensity ?? (isForest ? 60.0 : null),
      canopyCover: canopyCover,
      source: source,
    );
  }
}
