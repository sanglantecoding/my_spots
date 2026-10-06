/// Données de terrain pour une position.
class TerrainData {
  final double latitude;
  final double longitude;
  final double elevation; // mètres
  final double slope; // degrés (0-90)
  final double aspect; // degrés (0-360, 0=Nord, 90=Est, 180=Sud, 270=Ouest)

  TerrainData({
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.slope,
    required this.aspect,
  });

  /// Crée une instance mockée pour les tests/développement.
  factory TerrainData.mock({
    double lat = 43.5,
    double lng = 3.5,
    double elevation = 200.0,
    double slope = 10.0,
    double aspect = 180.0,
  }) {
    return TerrainData(
      latitude: lat,
      longitude: lng,
      elevation: elevation,
      slope: slope,
      aspect: aspect,
    );
  }

  /// Orientation cardinale textuelle.
  String get aspectCardinal {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
    final index = ((aspect + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}
