import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';

/// Interface pour le service de forêt/occupation du sol.
///
/// Indépendant du fournisseur de données (IGN, Corine Land Cover, etc.).
abstract class ForestService {
  /// Récupère les données de forêt pour une position.
  ///
  /// [lat] : Latitude
  /// [lng] : Longitude
  ///
  /// Retourne le type de forêt, la densité et la couverture forestière.
  Future<ForestData> getForestData({required double lat, required double lng});

  /// Charge les données de forêt pour plusieurs centres en batch.
  ///
  /// Implementation par défaut retourne une map vide.
  Future<Map<String, ForestData>> getForestBatch(
    LatLngBounds bounds,
    List<LatLng> centers, {
    void Function(String)? onStage,
  }) async {
    return {};
  }
}

/// Service neutre : aucune donnée forestière n'est disponible localement.
class UnknownForestService implements ForestService {
  @override
  Future<ForestData> getForestData({
    required double lat,
    required double lng,
  }) async {
    return ForestData.unknown(lat, lng);
  }

  @override
  Future<Map<String, ForestData>> getForestBatch(
    LatLngBounds bounds,
    List<LatLng> centers, {
    void Function(String)? onStage,
  }) async {
    return {};
  }
}
