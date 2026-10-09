/// Données de forêt/occupation du sol pour une position.
class ForestData {
  final double latitude;
  final double longitude;
  final bool? isForest; // null si inconnu
  final String?
  forestType; // Type de forêt (ex: "feuillu", "conifère", "mixte") si isForest=true
  final double? treeDensity; // % (0-100) si isForest=true
  final double? canopyCover; // % couverture forestière (0-100) si isForest=true
  /// Occupation du sol connue : water, beach, desert, glacier,
  /// bare_rock ou urban. Null tant qu'aucune source ne la renseigne.
  final String? landCover;

  /// Classe de couvert issue de la BD Forêt : "fermée" ou "ouverte".
  /// Ce champ décrit une classe, jamais un pourcentage estimé.
  final String? canopyClass;

  /// Nombre de polygones forestiers de la tuile connue ; null si tuile inconnue.
  final int? forestAreasInTile;

  /// Distance du point au bord forestier le plus proche, en mètres.
  final double? nearestForestDistanceMeters;
  final String?
  source; // Source des données (ex: "ign", "corine", si disponible)

  ForestData({
    required this.latitude,
    required this.longitude,
    this.isForest,
    this.forestType,
    this.treeDensity,
    this.canopyCover,
    this.landCover,
    this.canopyClass,
    this.forestAreasInTile,
    this.nearestForestDistanceMeters,
    this.source,
  });

  /// Crée une instance mockée pour les tests/développement.
  factory ForestData.mock({
    double lat = 43.5,
    double lng = 3.5,
    bool? isForest,
    String? forestType,
    double? treeDensity,
    double? canopyCover,
    String? landCover,
    String? canopyClass,
    int? forestAreasInTile,
    double? nearestForestDistanceMeters,
    String? source,
  }) {
    return ForestData(
      latitude: lat,
      longitude: lng,
      isForest: isForest,
      forestType: forestType,
      treeDensity: treeDensity,
      canopyCover: canopyCover,
      landCover: landCover,
      canopyClass: canopyClass,
      forestAreasInTile: forestAreasInTile,
      nearestForestDistanceMeters: nearestForestDistanceMeters,
      source: source,
    );
  }
}
