import 'package:my_spots/models/mushroom/terrain_data.dart';

/// Interface pour le service de terrain (altitude, pente, exposition).
///
/// Indépendant du fournisseur de données (SRTM, IGN, OpenTopoData, etc.).
abstract class TerrainService {
  /// Récupère les données de terrain pour une position.
  ///
  /// [lat] : Latitude
  /// [lng] : Longitude
  ///
  /// Retourne l'altitude, la pente et l'exposition.
  Future<TerrainData> getTerrainData({
    required double lat,
    required double lng,
  });

  /// Récupère l'altitude uniquement (plus léger si seule l'altitude est nécessaire).
  Future<double> getElevation({
    required double lat,
    required double lng,
  });
}
