import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/services/mushroom/habitat_config.dart';

/// Règles partagées pour les exclusions certaines fondées sur le terrain.
class HabitatRules {
  /// Renvoie l'exclusion du terrain seul, ou null si elle ne s'applique pas.
  static ({HabitatStatus status, String reason})? evaluateTerrain(
    TerrainData terrain,
  ) {
    if (terrain.noElevationData) {
      return (
        status: HabitatStatus.excluded,
        reason: 'Pas d’altitude IGN ni SRTM : mer probable',
      );
    }
    if (terrain.elevation != null && terrain.elevation! <= 0) {
      return (
        status: HabitatStatus.excluded,
        reason: 'Niveau de la mer ou en dessous',
      );
    }

    final elevation = terrain.elevation;
    if (elevation != null && elevation < HabitatConfig.minElevationMeters) {
      return (
        status: HabitatStatus.excluded,
        reason:
            'Altitude ${elevation.round()} m : sous la limite basse de ${HabitatConfig.minElevationMeters.round()} m',
      );
    }
    if (elevation != null && elevation > HabitatConfig.maxElevationMeters) {
      return (
        status: HabitatStatus.excluded,
        reason:
            'Altitude ${elevation.round()} m : au-dessus de la limite haute de ${HabitatConfig.maxElevationMeters.round()} m',
      );
    }
    return null;
  }
}
