import 'package:latlong2/latlong.dart';
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

  /// Charge les données de terrain pour plusieurs centres en batch.
  ///
  /// Doit être implémenté par les services qui supportent le traitement par lot.
  Future<Map<String, TerrainData>> getTerrainBatch(
    List<LatLng> centers,
    double spacingMetres,
  ) {
    throw UnimplementedError('getTerrainBatch must be implemented');
  }
}
