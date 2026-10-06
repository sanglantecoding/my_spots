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

  @override
  MushroomForecast calculate({
    required List<WeatherDay> weatherHistory,
    required List<WeatherDay> weatherForecast,
    required List<SoilMoistureData> soilMoistureLayers,
    required TerrainData terrain,
    required ForestData forest,
    required DateTime targetDate,
  }) {
    // Sélectionner la couche de sol la plus superficielle (0-7cm typiquement)
    // Si aucune donnée, utiliser une valeur par défaut neutre
    final soilMoisture = soilMoistureLayers.isNotEmpty
        ? soilMoistureLayers.reduce(
            (a, b) => a.depthStart < b.depthStart ? a : b,
          )
        : null;

    // 1. Calcul du facteur eau (pluie cumulée récente + humidité sol)
    final waterFactor = _calculateWaterFactor(weatherHistory, soilMoisture);

    // 2. Calcul du facteur température (températures moyennes récentes)
    final temperatureFactor = _calculateTemperatureFactor(weatherHistory);

    // 3. Calcul du facteur dessèchement (périodes sèches prolongées)
    final dryingFactor = _calculateDryingFactor(weatherHistory);

    // 4. Calcul du facteur terrain (pente, exposition, altitude)
    final terrainFactor = _calculateTerrainFactor(terrain);

    // 5. Calcul du facteur forêt (type, densité)
    final forestFactor = _calculateForestFactor(forest);

    // 6. Agrégation des facteurs en indice global (0-100)
    final index = _aggregateIndex(
      waterFactor,
      temperatureFactor,
      dryingFactor,
      terrainFactor,
      forestFactor,
    );

    // 7. Calcul de la confiance (basée sur la disponibilité des données)
    final confidence = _calculateConfidence(
      weatherHistory,
      weatherForecast,
      soilMoisture,
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

  /// Facteur eau : pluie cumulée sur 7-14 jours + humidité du sol.
  double _calculateWaterFactor(
    List<WeatherDay> history,
    SoilMoistureData? moisture,
  ) {
    // Pluie cumulée sur les 14 derniers jours
    final recent14Days = history.take(14).toList();
    final precip14 = WeatherDay.cumulativePrecipitation(recent14Days);

    // Normalisation placeholder (à calibrer)
    final precipScore = precip14.value == null
        ? 0.0
        : (precip14.value! / 50.0).clamp(0.0, 1.0);
    final moistureScore = moisture?.soilMoisture == null
        ? 0.0
        : (moisture!.soilMoisture! / 50.0).clamp(0.0, 1.0);

    return (precipScore * 0.7 + moistureScore * 0.3).clamp(0.0, 1.0);
  }

  /// Facteur température : températures moyennes récentes.
  double _calculateTemperatureFactor(List<WeatherDay> history) {
    final recent14Days = history.take(14).toList();
    final meanTemp = WeatherDay.meanTemperature(recent14Days).value;

    // Température optimale pour les cèpes : ~15-20°C
    // Normalisation placeholder (à calibrer)
    if (meanTemp == null) return 0.0;
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

  /// Facteur dessèchement : pénalité pour périodes sèches prolongées.
  double _calculateDryingFactor(List<WeatherDay> history) {
    // Compter les jours consécutifs sans pluie significative (< 2mm)
    int dryDays = 0;
    for (final day in history) {
      if (day.precipitation == null) break;
      if (day.precipitation! < 2.0) {
        dryDays++;
      } else {
        break;
      }
    }

    // Plus de 10 jours sans pluie = pénalité forte
    if (dryDays > 10) return 0.2;
    if (dryDays > 7) return 0.4;
    if (dryDays > 5) return 0.6;
    return 1.0;
  }

  /// Facteur terrain : pente, exposition, altitude.
  double _calculateTerrainFactor(TerrainData terrain) {
    // Pente : les cèpes préfèrent les pentes modérées (5-20°)
    final slopeScore = terrain.slope == null
        ? 0.0
        : _normalizeSlope(terrain.slope!);

    // Exposition : préférence pour les expositions nord/est (plus fraîches)
    final aspectScore = terrain.aspect == null
        ? 0.0
        : _normalizeAspect(terrain.aspect!);

    // Altitude : préférence pour 200-800m (à calibrer selon région)
    final elevationScore = terrain.elevation == null
        ? 0.0
        : _normalizeElevation(terrain.elevation!);

    return (slopeScore * 0.4 + aspectScore * 0.3 + elevationScore * 0.3).clamp(
      0.0,
      1.0,
    );
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
  double _calculateForestFactor(ForestData forest) {
    // Si ce n'est pas une forêt, pas de facteur forêt
    if (forest.isForest == null || !forest.isForest!) return 0.0;

    // Type de forêt : feuillu et mixte favorables
    final typeScore =
        forest.forestType != null &&
            (forest.forestType!.toLowerCase().contains('feuillu') ||
                forest.forestType!.toLowerCase().contains('mixte'))
        ? 1.0
        : 0.6;

    // Densité : 40-80% optimale
    final densityScore =
        forest.treeDensity != null &&
            forest.treeDensity! >= 40 &&
            forest.treeDensity! <= 80
        ? 1.0
        : forest.treeDensity != null &&
              ((forest.treeDensity! >= 20 && forest.treeDensity! < 40) ||
                  (forest.treeDensity! > 80 && forest.treeDensity! <= 90))
        ? 0.7
        : 0.5;

    return (typeScore * 0.6 + densityScore * 0.4).clamp(0.0, 1.0);
  }

  /// Agrégation des facteurs en indice global (0-100).
  int _aggregateIndex(
    double water,
    double temperature,
    double drying,
    double terrain,
    double forest,
  ) {
    // Pondérations placeholder (à calibrer)
    final weighted =
        (water * 0.35 +
                temperature * 0.20 +
                drying * 0.15 +
                terrain * 0.15 +
                forest * 0.15)
            .clamp(0.0, 1.0);

    return (weighted * 100).round();
  }

  /// Calcul de la confiance dans la prédiction.
  double _calculateConfidence(
    List<WeatherDay> history,
    List<WeatherDay> forecast,
    SoilMoistureData? moisture,
    TerrainData terrain,
    ForestData forest,
  ) {
    // Confiance basée sur la disponibilité des données
    double confidence = 0.5;

    if (history.length >= 30) {
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

    return confidence.clamp(0.0, 1.0);
  }
}
