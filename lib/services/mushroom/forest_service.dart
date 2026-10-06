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
}
