import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';

/// Interface abstraite pour la persistance des zones et couches hors-ligne.
///
/// Permet d'injecter une implémentation mock pour les tests unitaires
/// tout en utilisant [OfflineMapRepository] en production.
abstract class MapLayerRepository {
  /// Sauvegarde une zone (création ou mise à jour).
  void save(OfflineMap map);

  /// Sauvegarde une couche associée à une zone.
  void saveLayer(OfflineMap map, OfflineMapLayer layer);

  /// Recherche une zone par son UUID.
  OfflineMap? findByUuid(String uuid);

  /// Recherche une couche par son ID.
  OfflineMapLayer? findLayerById(int id);
}
