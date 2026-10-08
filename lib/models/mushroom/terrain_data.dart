/// Données de terrain pour une position.
class TerrainData {
  final double latitude;
  final double longitude;
  final double? elevation; // mètres
  /// Vrai si l'IGN a explicitement renvoyé son code « pas de donnée ».
  /// Une valeur null avec false signifie que l'altitude est simplement inconnue.
  final bool noElevationData;
  final double? slope; // degrés (0-90)
  final double? aspect; // degrés (0-360, 0=Nord, 90=Est, 180=Sud, 270=Ouest)
  final String?
  source; // nom du fournisseur (ign_bdalti, srtm_open_elevation, …)

  TerrainData({
    required this.latitude,
    required this.longitude,
    this.elevation,
    this.noElevationData = false,
    this.slope,
    this.aspect,
    this.source,
  });

  /// Crée une instance mockée pour les tests/développement.
  factory TerrainData.mock({
    double lat = 43.5,
    double lng = 3.5,
    double elevation = 200.0,
    bool noElevationData = false,
    double slope = 10.0,
    double aspect = 180.0,
    String? source,
  }) {
    return TerrainData(
      latitude: lat,
      longitude: lng,
      elevation: elevation,
      noElevationData: noElevationData,
      slope: slope,
      aspect: aspect,
      source: source,
    );
  }

  /// Orientation cardinale textuelle.
  String? get aspectCardinal {
    final a = aspect;
    if (a == null) return null;
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
    final index = ((a + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}
