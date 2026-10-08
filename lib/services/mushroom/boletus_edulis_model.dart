import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_engine.dart';

/// Moteur de prévision pour le Cèpe de Bordeaux (Boletus edulis).
///
/// ⚠️ IMPORTANT - PLACEHOLDERS NON SCIENTIFIQUES ⚠️
///
/// Tous les coefficients et seuils utilisés dans cette classe sont des PLACEHOLDERS
/// pour le développement uniquement. Ils NE SONT PAS basés sur des données
/// scientifiques ou une expertise mycologique validée.
///
/// Ces coefficients DOIVENT être remplacés par des valeurs calibrées avec :
/// - Des données d'observation réelles de fructification
/// - Une expertise mycologique professionnelle
/// - Une validation statistique sur plusieurs saisons
///
/// L'indice calculé représente des "conditions favorables" basées sur ces
/// placeholders, PAS une probabilité scientifique de trouver des champignons.
class BoletusEdulisModel implements MushroomForecastEngine {
  @override
  MushroomSpecies get species => MushroomSpecies.boletusEdulis;

  static DateTime _stripTime(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day);

  /// Ordonne une liste de jours météo en antéchronologique :
  /// du PLUS RÉCENT (index 0) au PLUS ANCIEN.
  static List<WeatherDay> _sortDesc(List<WeatherDay> days) {
    final list = List<WeatherDay>.from(days);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Ordonne une liste SoilMoistureData en antéchronologique
  /// (du PLUS RÉCENT au PLUS ANCIEN) pour la couche [layerDepthMin..layerDepthMax].
  static List<SoilMoistureData> _sortSoilDesc(List<SoilMoistureData> layers) {
    final list = List<SoilMoistureData>.from(layers);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  MushroomForecast calculate({
    required List<WeatherDay> weatherHistory,
    required List<WeatherDay> weatherForecast,
    required List<SoilMoistureData> soilMoistureLayers,
    required TerrainData terrain,
    required ForestData forest,
    required DateTime targetDate,
  }) {
    final tDay = _stripTime(targetDate);

    // ── 1. Série météo jusqu'à targetDate, en antéchronologique ──────────
    // Concaténer historique + prévisions, puis filtrer ceux dont la date
    // est <= targetDate. On trie ensuite en antéchronologique (plus récent
    // en index 0) pour que .take(14) corresponde aux 14 JOURS QUI PRECEDENT
    // (ou incluent) targetDate, et que le calcul des jours secs parte de
    // targetDate vers le passé.
    final allWeather = <WeatherDay>[...weatherHistory, ...weatherForecast];
    final upToTarget = allWeather
        .where((d) => !_stripTime(d.date).isAfter(tDay))
        .toList();
    final weatherSeriesDesc = _sortDesc(upToTarget);

    // ── 2. Couche de sol la plus superficielle, proche de targetDate ─────
    final byLayer = <(double s, double e), List<SoilMoistureData>>{};
    for (final layer in soilMoistureLayers) {
      final k = (layer.depthStart, layer.depthEnd);
      byLayer.putIfAbsent(k, () => []).add(layer);
    }
    SoilMoistureData? nearestSoil;
    if (byLayer.isNotEmpty) {
      final shallowestKey = byLayer.keys.reduce((a, b) => a.$1 < b.$1 ? a : b);
      final list = byLayer[shallowestKey]!;
      final sorted = _sortSoilDesc(list);
      // Prendre l'entrée dont la date est <= targetDate la plus récente ;
      // sinon la plus ancienne en fallback (hors futur).
      try {
        nearestSoil = sorted.firstWhere(
          (s) => !_stripTime(s.date).isAfter(tDay),
        );
      } on StateError {
        // toutes les entrées sont dans le futur
        if (sorted.isNotEmpty) {
          nearestSoil = sorted.last;
        }
      }
    }

    // 3. Calcul du facteur eau (pluie cumulée récente + humidité sol)
    final waterFactor = _calculateWaterFactor(weatherSeriesDesc, nearestSoil);

    // 4. Calcul du facteur température (températures moyennes récentes)
    final temperatureFactor = _calculateTemperatureFactor(weatherSeriesDesc);

    // 5. Calcul du facteur dessèchement (périodes sèches prolongées)
    final dryingFactor = _calculateDryingFactor(weatherSeriesDesc);

    // 6. Calcul du facteur terrain (pente, exposition, altitude)
    final terrainFactor = _calculateTerrainFactor(terrain);

    // 7. Calcul du facteur forêt (type, densité)
    final forestFactor = _calculateForestFactor(forest);

    // 8. Agrégation des facteurs en indice global (0-100)
    final index = _aggregateIndex(
      waterFactor,
      temperatureFactor,
      dryingFactor,
      terrainFactor,
      forestFactor,
    );

    // 9. Calcul de la confiance (basée sur la disponibilité des données)
    final confidence = _calculateConfidence(
      weatherSeriesDesc,
      weatherForecast,
      nearestSoil,
      waterFactor,
      temperatureFactor,
      terrain,
      forest,
    );

    return MushroomForecast(
      date: targetDate,
      species: species,
      index: index,
      confidence: confidence,
      factors: ForecastFactors(
        waterFactor: waterFactor,
        temperatureFactor: temperatureFactor,
        dryingFactor: dryingFactor,
        terrainFactor: terrainFactor,
        forestFactor: forestFactor,
      ),
    );
  }

  /// Facteur eau : pluie cumulée sur 14 jours récents + humidité du sol.
  double? _calculateWaterFactor(
    List<WeatherDay> weatherSeriesDesc,
    SoilMoistureData? moisture,
  ) {
    // weatherSeriesDesc est déjà antéchronologique : take(14) sélectionne
    // correctement les 14 jours les plus récents AVANT (ou égal à) la date
    // cible.
    final recent14Days = weatherSeriesDesc.take(14).toList();
    final precip14 = WeatherDay.cumulativePrecipitation(recent14Days);

    // Normalisation placeholder (à calibrer).
    final precipScore = precip14.value == null
        ? null
        : (precip14.value! / 50.0).clamp(0.0, 1.0).toDouble();

    // Open-Meteo soilMoisture a déjà été converti en % volumique par le
    // provider (m³/m³ × 100). Un volume m3/m3 = 0.25 → 25 % vol.
    // Saturation en eau du sol est ≈ 50 % volumique (sable 25-35 %, limon
    // 30-45 %, argile 40-60 %). On normalise donc /50 pour se situer dans
    // [0,1]. Note : placeholder, à calibrer.
    final moistureScore = moisture?.soilMoisture == null
        ? null
        : (moisture!.soilMoisture! / 50.0).clamp(0.0, 1.0).toDouble();
    if (precipScore == null && moistureScore == null) return null;

    var weightedSum = 0.0;
    var knownWeight = 0.0;
    if (precipScore != null) {
      weightedSum += precipScore * 0.7;
      knownWeight += 0.7;
    }
    if (moistureScore != null) {
      weightedSum += moistureScore * 0.3;
      knownWeight += 0.3;
    }
    return (weightedSum / knownWeight).clamp(0.0, 1.0).toDouble();
  }

  /// Facteur température : températures moyennes sur les 14 derniers jours.
  double? _calculateTemperatureFactor(List<WeatherDay> weatherSeriesDesc) {
    final recent14Days = weatherSeriesDesc.take(14).toList();
    final meanTemp = WeatherDay.meanTemperature(recent14Days).value;

    // Température optimale pour les cèpes : ~15-20°C
    if (meanTemp == null) return null;
    if (meanTemp >= 15 && meanTemp <= 20) {
      return 1.0;
    } else if (meanTemp >= 10 && meanTemp < 15) {
      return 0.7;
    } else if (meanTemp > 20 && meanTemp <= 25) {
      return 0.6;
    } else {
      return 0.3;
    }
  }

  /// Facteur dessèchement : pénalité pour jours secs consécutifs.
  ///
  /// IMPORTANT : la série [weatherSeriesDesc] doit être triée du PLUS RÉCENT
  /// (index 0 = targetDate ou le jour précédent immédiat) au PLUS ANCIEN.
  /// La boucle parcourt depuis le présent vers le passé et arrête le comptage
  /// à la première pluie significative rencontrée.
  double _calculateDryingFactor(List<WeatherDay> weatherSeriesDesc) {
    int dryDays = 0;
    for (final day in weatherSeriesDesc) {
      if (day.precipitation == null) break;
      if (day.precipitation! < 2.0) {
        dryDays++;
      } else {
        break;
      }
    }

    if (dryDays > 10) return 0.2;
    if (dryDays > 7) return 0.4;
    if (dryDays > 5) return 0.6;
    return 1.0;
  }

  /// Facteur terrain : pente, exposition, altitude.
  /// Retourne null si toutes les données d'entrée sont inconnues (null).
  double? _calculateTerrainFactor(TerrainData terrain) {
    // Si toutes les données terrain sont inconnues, le facteur est inconnu.
    if (terrain.elevation == null &&
        terrain.slope == null &&
        terrain.aspect == null) {
      return null;
    }

    // Pente : les cèpes préfèrent les pentes modérées (5-20°)
    final slopeScore = terrain.slope == null
        ? null
        : _normalizeSlope(terrain.slope!);

    // Exposition : préférence pour les expositions nord/est (plus fraîches)
    final aspectScore = terrain.aspect == null
        ? null
        : _normalizeAspect(terrain.aspect!);

    // Altitude : préférence pour 200-800m (à calibrer selon région)
    final elevationScore = terrain.elevation == null
        ? null
        : _normalizeElevation(terrain.elevation!);

    var weightedSum = 0.0;
    var knownWeight = 0.0;
    if (slopeScore != null) {
      weightedSum += slopeScore * 0.4;
      knownWeight += 0.4;
    }
    if (aspectScore != null) {
      weightedSum += aspectScore * 0.3;
      knownWeight += 0.3;
    }
    if (elevationScore != null) {
      weightedSum += elevationScore * 0.3;
      knownWeight += 0.3;
    }
    if (knownWeight == 0) return null;
    return (weightedSum / knownWeight).clamp(0.0, 1.0).toDouble();
  }

  double _normalizeSlope(double slope) {
    if (slope >= 5 && slope <= 20) return 1.0;
    if (slope >= 0 && slope < 5) return 0.6;
    if (slope > 20 && slope <= 30) return 0.7;
    return 0.4;
  }

  double _normalizeAspect(double aspect) {
    // Nord (315-45°) et Est (45-135°) favorables
    if ((aspect >= 315 || aspect < 45) || (aspect >= 45 && aspect < 135)) {
      return 1.0;
    }
    // Sud (135-225°) moins favorable
    if (aspect >= 135 && aspect < 225) {
      return 0.5;
    }
    return 0.7;
  }

  double _normalizeElevation(double elevation) {
    if (elevation >= 200 && elevation <= 800) return 1.0;
    if (elevation >= 100 && elevation < 200) return 0.8;
    if (elevation > 800 && elevation <= 1200) return 0.7;
    return 0.5;
  }

  /// Facteur forêt : type, densité.
  /// Retourne null si la donnée d'entrée est inconnue (forest.isForest == null).
  double? _calculateForestFactor(ForestData forest) {
    if (forest.isForest == null) return null;
    if (!forest.isForest!) return 0.0;

    // Type de forêt : feuillu et mixte favorables
    final typeScore = forest.forestType == null
        ? null
        : (forest.forestType!.toLowerCase().contains('feuillu') ||
                  forest.forestType!.toLowerCase().contains('mixte')
              ? 1.0
              : 0.6);

    // Densité : 40-80% optimale
    final densityScore = forest.treeDensity == null
        ? null
        : forest.treeDensity! >= 40 && forest.treeDensity! <= 80
        ? 1.0
        : ((forest.treeDensity! >= 20 && forest.treeDensity! < 40) ||
              (forest.treeDensity! > 80 && forest.treeDensity! <= 90))
        ? 0.7
        : 0.5;

    if (typeScore == null && densityScore == null) return 1.0;
    var weightedSum = 0.0;
    var knownWeight = 0.0;
    if (typeScore != null) {
      weightedSum += typeScore * 0.6;
      knownWeight += 0.6;
    }
    if (densityScore != null) {
      weightedSum += densityScore * 0.4;
      knownWeight += 0.4;
    }
    return (weightedSum / knownWeight).clamp(0.0, 1.0).toDouble();
  }

  /// Agrégation des facteurs en indice global (0-100).
  /// Les facteurs terrain et forest peuvent être null si leurs données sont inconnues.
  /// Les facteurs connus sont moyennés pondérément avec leurs poids renormalisés
  /// pour que la somme reste 1.
  int _aggregateIndex(
    double? water,
    double? temperature,
    double drying,
    double? terrain,
    double? forest,
  ) {
    // Pondérations par défaut (à calibrer)
    const waterWeight = 0.35;
    const temperatureWeight = 0.20;
    const dryingWeight = 0.15;
    const terrainWeight = 0.15;
    const forestWeight = 0.15;

    // Calculer la somme des poids des facteurs connus
    double knownWeightSum = dryingWeight;
    if (water != null) knownWeightSum += waterWeight;
    if (temperature != null) knownWeightSum += temperatureWeight;
    if (terrain != null) knownWeightSum += terrainWeight;
    if (forest != null) knownWeightSum += forestWeight;

    // Calculer le médian pondéré en redistribuant les poids
    var weightedSum = drying * dryingWeight;
    if (water != null) weightedSum += water * waterWeight;
    if (temperature != null) weightedSum += temperature * temperatureWeight;
    if (terrain != null) weightedSum += terrain * terrainWeight;
    if (forest != null) weightedSum += forest * forestWeight;

    // Normaliser pour que la somme des poids soit 1
    final weighted = (weightedSum / knownWeightSum).clamp(0.0, 1.0);

    return (weighted * 100).round();
  }

  /// Calcul de la confiance dans la prédiction.
  /// La confiance est diminuée proportionnellement au poids des facteurs
  /// dont les données sont inconnues.
  double _calculateConfidence(
    List<WeatherDay> weatherSeriesDesc,
    List<WeatherDay> forecast,
    SoilMoistureData? moisture,
    double? waterFactor,
    double? temperatureFactor,
    TerrainData terrain,
    ForestData forest,
  ) {
    double confidence = 0.5;

    // On utilise la série effective (qui va jusqu'à targetDate), pas
    // l'historique brut, pour valider qu'on a assez de données.
    if (weatherSeriesDesc.length >= 30) {
      confidence += 0.2;
    }
    if (forecast.length >= 7) {
      confidence += 0.1;
    }
    if (moisture?.soilMoisture != null) {
      confidence += 0.1;
    }
    if (terrain.elevation != null) {
      confidence += 0.05;
    }
    if (forest.forestType != null && forest.forestType!.isNotEmpty) {
      confidence += 0.05;
    }

    // Pénalité proportionnelle pour les facteurs inconnus
    double missingWeight = 0.0;
    if (terrain.elevation == null &&
        terrain.slope == null &&
        terrain.aspect == null) {
      missingWeight += 0.15; // poids du facteur terrain
    }
    if (forest.isForest == null) {
      missingWeight += 0.15; // poids du facteur forêt
    }
    if (waterFactor == null) missingWeight += 0.35;
    if (temperatureFactor == null) missingWeight += 0.20;

    return (confidence - missingWeight).clamp(0.0, 1.0);
  }
}
