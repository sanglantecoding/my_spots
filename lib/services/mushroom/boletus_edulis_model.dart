import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_engine.dart';
import 'package:my_spots/services/mushroom/hydric_config.dart';
import 'package:my_spots/services/mushroom/shock_config.dart';
import 'package:my_spots/services/mushroom/habitat_rules.dart';

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

  double? _soilValueAt(
    List<SoilMoistureData> layers,
    DateTime targetDate, {
    required (double, double) depth,
    required double? Function(SoilMoistureData) select,
  }) {
    for (final soil in layers) {
      if (soil.depthStart == depth.$1 &&
          soil.depthEnd == depth.$2 &&
          _stripTime(soil.date) == targetDate) {
        return select(soil);
      }
    }
    return null;
  }

  ({double? min, double? median, double? max, double? percentile})
  _soilMoistureStats60d(List<SoilMoistureData> layers, DateTime targetDate) {
    final startDate = targetDate.subtract(const Duration(days: 60));
    final values =
        layers
            .where(
              (soil) =>
                  soil.depthStart == 7 &&
                  soil.depthEnd == 28 &&
                  soil.soilMoisture != null &&
                  !_stripTime(soil.date).isBefore(startDate) &&
                  !_stripTime(soil.date).isAfter(targetDate),
            )
            .map((soil) => soil.soilMoisture!)
            .toList()
          ..sort();
    if (values.isEmpty) {
      return (min: null, median: null, max: null, percentile: null);
    }
    final currentValue = _soilValueAt(
      layers,
      targetDate,
      depth: (7, 28),
      select: (soil) => soil.soilMoisture,
    );
    final middle = values.length ~/ 2;
    final median = values.length.isOdd
        ? values[middle]
        : (values[middle - 1] + values[middle]) / 2;
    // Inclusive percentile rank: share of available values <= today's value.
    final percentile = currentValue == null
        ? null
        : values.where((value) => value <= currentValue).length /
              values.length *
              100;
    return (
      min: values.first,
      median: median,
      max: values.last,
      percentile: percentile,
    );
  }

  /// Ordonne une liste de jours météo en antéchronologique :
  /// du PLUS RÉCENT (index 0) au PLUS ANCIEN.
  static List<WeatherDay> _sortDesc(List<WeatherDay> days) {
    final list = List<WeatherDay>.from(days);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Ordonne une liste SoilMoistureData en antéchronologique
  /// (du PLUS RÉCENT au PLUS ANCIEN) pour la couche [layerDepthMin..layerDepthMax].
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
    final hydric = _calculateHydricMetrics(
      weatherSeriesDesc,
      soilMoistureLayers,
      tDay,
    );
    final waterFactor = hydric.factor;
    final soilMoistureStats = _soilMoistureStats60d(soilMoistureLayers, tDay);

    // 4. Température du sol si connue, sinon température de l'air.
    final temperature = _calculateTemperatureFactor(
      weatherSeriesDesc,
      soilMoistureLayers,
      tDay,
    );
    final temperatureFactor = temperature.factor;

    // 5. Événement hydro-thermique antérieur et décalage de fructification.
    final shock = _calculateShockFactor(upToTarget, tDay);

    // 6. Calcul du facteur dessèchement (périodes sèches prolongées)
    final dryingFactor = _calculateDryingFactor(weatherSeriesDesc);

    // 7. Calcul du facteur terrain (pente, exposition, altitude)
    final terrainFactor = _calculateTerrainFactor(terrain);

    // 8. Calcul du facteur forêt (type, densité)
    final forestFactor = _calculateForestFactor(forest);

    // 9. Vérification de l'habitat avant de produire un indice.
    final habitat = _evaluateHabitat(terrain, forest);

    // 10. Une exclusion certaine interdit toute valeur d'indice positive.
    final aggregatedIndex = _aggregateIndex(
      waterFactor,
      temperatureFactor,
      dryingFactor,
      shock.factor,
      terrainFactor,
      forestFactor,
    );
    final hydricGate = waterFactor == null
        ? 1.0
        : (waterFactor / HydricConfig.gateFullAt).clamp(0.0, 1.0).toDouble();
    final index = habitat.status == HabitatStatus.excluded
        ? 0
        : (aggregatedIndex * hydricGate).round();

    // 10. Calcul de la confiance (basée sur la disponibilité des données)
    final confidence = _calculateConfidence(
      weatherSeriesDesc,
      weatherForecast,
      hydric.hasSoilMoisture,
      temperature.source == 'soil_0_7cm',
      waterFactor,
      temperatureFactor,
      shock.factor,
      terrain,
      forest,
    );

    String? soilSource;
    for (final layer in soilMoistureLayers) {
      if (!_stripTime(layer.date).isAfter(tDay) && layer.source != null) {
        soilSource = layer.source;
        break;
      }
    }

    return MushroomForecast(
      date: targetDate,
      species: species,
      index: index,
      confidence: confidence,
      habitat: habitat.status,
      habitatReason: habitat.reason,
      wetStreak: hydric.wetStreak,
      dryBefore: hydric.dryBefore,
      soilMoistureAvailable: hydric.hasSoilMoisture,
      soilMoisture0To7Percent: _soilValueAt(
        soilMoistureLayers,
        tDay,
        depth: (0, 7),
        select: (soil) => soil.soilMoisture,
      ),
      soilMoisture7To28Percent: _soilValueAt(
        soilMoistureLayers,
        tDay,
        depth: (7, 28),
        select: (soil) => soil.soilMoisture,
      ),
      soilMoisture7To28Min60dPercent: soilMoistureStats.min,
      soilMoisture7To28Median60dPercent: soilMoistureStats.median,
      soilMoisture7To28Max60dPercent: soilMoistureStats.max,
      soilMoisture7To28Percentile60d: soilMoistureStats.percentile,
      soilTemperature0To7C: _soilValueAt(
        soilMoistureLayers,
        tDay,
        depth: ShockConfig.soilTemperatureLayerDepth,
        select: (soil) => soil.soilTemperature,
      ),
      hydricGate: hydricGate,
      shockDate: shock.date,
      shockRainMm: shock.rain48h,
      shockTempDropC: shock.tempDrop,
      temperatureSource: temperature.source,
      dataSources: {
        'terrain': terrain.source,
        'forest': forest.source,
        'forestType': forest.forestType,
        'canopyClass': forest.canopyClass,
        'forestAreasInTile': forest.forestAreasInTile?.toString(),
        'nearestForestDistanceMeters': forest.nearestForestDistanceMeters
            ?.toString(),
        'forestTileKnown': forest.forestAreasInTile == null ? null : 'true',
        'temperature': temperature.source,
        'soil': soilSource,
      },
      factors: ForecastFactors(
        waterFactor: waterFactor,
        temperatureFactor: temperatureFactor,
        dryingFactor: dryingFactor,
        terrainFactor: terrainFactor,
        forestFactor: forestFactor,
        shockFactor: shock.factor,
      ),
    );
  }

  ({HabitatStatus status, String? reason}) _evaluateHabitat(
    TerrainData terrain,
    ForestData forest,
  ) {
    final terrainExclusion = HabitatRules.evaluateTerrain(terrain);
    if (terrainExclusion != null) return terrainExclusion;

    const landCoverReasons = <String, String>{
      'water': 'Étendue d’eau',
      'beach': 'Plage ou sable',
      'desert': 'Désert',
      'glacier': 'Glacier',
      'bare_rock': 'Roche nue',
      'urban': 'Zone urbanisée',
    };
    final landCoverReason = landCoverReasons[forest.landCover?.toLowerCase()];
    if (landCoverReason != null) {
      return (status: HabitatStatus.excluded, reason: landCoverReason);
    }

    if (terrain.elevation == null || forest.isForest == null) {
      final missing = <String>[];
      if (terrain.elevation == null) missing.add('Altitude inconnue');
      if (forest.isForest == null) {
        missing.add('Présence de forêt non vérifiée');
      }
      return (status: HabitatStatus.unknown, reason: missing.join(' · '));
    }

    return (status: HabitatStatus.suitable, reason: null);
  }

  /// Persistance hydrique. Les seuils de [HydricConfig] sont des placeholders.
  ({double? factor, int? wetStreak, int? dryBefore, bool hasSoilMoisture})
  _calculateHydricMetrics(
    List<WeatherDay> weatherSeriesDesc,
    List<SoilMoistureData> soilLayers,
    DateTime targetDate,
  ) {
    final preferred = HydricConfig.soilLayerDepth;
    final preferredAvailable = soilLayers.any(
      (s) =>
          s.depthStart == preferred.$1 &&
          s.depthEnd == preferred.$2 &&
          s.soilMoisture != null &&
          !_stripTime(s.date).isAfter(targetDate),
    );
    final fallback = HydricConfig.soilLayerFallbackDepth;
    final fallbackAvailable = soilLayers.any(
      (s) =>
          s.depthStart == fallback.$1 &&
          s.depthEnd == fallback.$2 &&
          s.soilMoisture != null &&
          !_stripTime(s.date).isAfter(targetDate),
    );
    final depth = preferredAvailable
        ? preferred
        : fallbackAvailable
        ? fallback
        : preferred;
    final soilByDay = <DateTime, double?>{};
    for (final soil in soilLayers) {
      if (soil.depthStart == depth.$1 &&
          soil.depthEnd == depth.$2 &&
          !_stripTime(soil.date).isAfter(targetDate)) {
        soilByDay[_stripTime(soil.date)] = soil.soilMoisture;
      }
    }
    final nearestSoilDate = soilByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final hasSoilMoisture =
        nearestSoilDate.isNotEmpty && soilByDay[nearestSoilDate.first] != null;

    int? wetStreak;
    if (soilByDay[targetDate] != null) {
      var streak = 0;
      var date = targetDate;
      while (soilByDay.containsKey(date)) {
        final value = soilByDay[date];
        if (value == null || value < HydricConfig.wetThresholdPercent) break;
        streak++;
        date = date.subtract(const Duration(days: 1));
      }
      wetStreak = streak;
    }

    final recent = weatherSeriesDesc.take(HydricConfig.window).toList();
    final knownRain = recent.map((d) => d.precipitation).whereType<double>();
    final rainValues = knownRain.toList();
    final rainDays14 = rainValues.isEmpty
        ? null
        : rainValues.where((p) => p >= HydricConfig.rainDayMm).length;
    final rainSum = rainValues.fold<double>(0, (sum, value) => sum + value);
    final rainConcentration = rainSum <= 0 || rainValues.isEmpty
        ? null
        : rainValues.reduce((a, b) => a > b ? a : b) / rainSum;

    double? balance14;
    for (final day in recent) {
      if (day.precipitation == null || day.et0 == null) continue;
      balance14 = (balance14 ?? 0) + day.precipitation! - day.et0!;
    }

    // Localise le dernier épisode de jours pluvieux et son début.
    var runStart = weatherSeriesDesc.indexWhere(
      (d) =>
          d.precipitation != null && d.precipitation! >= HydricConfig.rainDayMm,
    );
    if (runStart < 0) {
      runStart = 0;
    } else {
      while (runStart + 1 < weatherSeriesDesc.length) {
        final newer = weatherSeriesDesc[runStart];
        final older = weatherSeriesDesc[runStart + 1];
        final consecutive =
            _stripTime(newer.date).difference(_stripTime(older.date)).inDays ==
            1;
        if (!consecutive ||
            older.precipitation == null ||
            older.precipitation! < HydricConfig.rainDayMm) {
          break;
        }
        runStart++;
      }
    }
    final prior = weatherSeriesDesc
        .skip(runStart + 1)
        .take(HydricConfig.drynessWindow)
        .where((d) => d.precipitation != null)
        .toList();
    final dryBefore = prior.isEmpty
        ? null
        : prior.where((d) => d.precipitation! < HydricConfig.rainDayMm).length;

    final terms = <(double, double)>[];
    if (wetStreak != null) {
      terms.add(((wetStreak / HydricConfig.wetMinDays).clamp(0.0, 1.0), 0.40));
    }
    if (rainDays14 != null) {
      terms.add(((rainDays14 / 6).clamp(0.0, 1.0), 0.20));
    }
    if (rainConcentration != null) {
      terms.add((1 - ((rainConcentration - 0.4) / 0.4).clamp(0.0, 1.0), 0.20));
    }
    if (balance14 != null) {
      terms.add(((balance14 / 40).clamp(0.0, 1.0), 0.20));
    }

    double? factor;
    if (terms.isNotEmpty) {
      final weightSum = terms.fold<double>(0, (sum, term) => sum + term.$2);
      factor =
          terms.fold<double>(0, (sum, term) => sum + term.$1 * term.$2) /
          weightSum;
      if (wetStreak != null &&
          wetStreak < 2 &&
          dryBefore != null &&
          dryBefore >= 14) {
        factor = factor.clamp(0.0, 0.3).toDouble();
      }
    }
    return (
      factor: factor,
      wetStreak: wetStreak,
      dryBefore: dryBefore,
      hasSoilMoisture: hasSoilMoisture,
    );
  }

  ({double? factor, String source}) _calculateTemperatureFactor(
    List<WeatherDay> weatherSeriesDesc,
    List<SoilMoistureData> soilLayers,
    DateTime targetDate,
  ) {
    final soilTemps =
        soilLayers
            .where(
              (soil) =>
                  soil.depthStart == ShockConfig.soilTemperatureLayerDepth.$1 &&
                  soil.depthEnd == ShockConfig.soilTemperatureLayerDepth.$2 &&
                  soil.soilTemperature != null &&
                  !_stripTime(soil.date).isAfter(targetDate),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    if (soilTemps.isNotEmpty) {
      final temperature = soilTemps.first.soilTemperature!;
      if (temperature >= ShockConfig.soilTemperatureOptimalLowC &&
          temperature <= ShockConfig.soilTemperatureOptimalHighC) {
        return (factor: 1.0, source: 'soil_0_7cm');
      }
      if ((temperature >= ShockConfig.soilTemperatureLowC &&
              temperature < ShockConfig.soilTemperatureOptimalLowC) ||
          (temperature > ShockConfig.soilTemperatureOptimalHighC &&
              temperature <= ShockConfig.soilTemperatureHighC)) {
        return (
          factor: ShockConfig.soilTemperatureModeratePart,
          source: 'soil_0_7cm',
        );
      }
      return (factor: 0.0, source: 'soil_0_7cm');
    }

    final meanTemp = WeatherDay.meanTemperature(
      weatherSeriesDesc.take(14).toList(),
    ).value;
    if (meanTemp == null) return (factor: null, source: 'air');
    // Formule existante pour la température de l'air, conservée en repli.
    if (meanTemp >= 15 && meanTemp <= 20) {
      return (factor: 1.0, source: 'air');
    } else if (meanTemp >= 10 && meanTemp < 15) {
      return (factor: 0.7, source: 'air');
    } else if (meanTemp > 20 && meanTemp <= 25) {
      return (factor: 0.6, source: 'air');
    } else {
      return (factor: 0.3, source: 'air');
    }
  }

  ({double? factor, DateTime? date, double? rain48h, double? tempDrop})
  _calculateShockFactor(List<WeatherDay> weather, DateTime targetDate) {
    final byDate = <DateTime, WeatherDay>{};
    for (final day in weather) {
      final date = _stripTime(day.date);
      if (!date.isAfter(targetDate)) byDate[date] = day;
    }

    double? bestFactor;
    DateTime? bestDate;
    double? bestRain;
    double? bestTempDrop;
    for (
      var lag = ShockConfig.lagMinDays;
      lag <= ShockConfig.lagMaxDays;
      lag++
    ) {
      final date = targetDate.subtract(Duration(days: lag));
      final eventDay = byDate[date];
      final previousDay = byDate[date.subtract(const Duration(days: 1))];
      if (eventDay?.precipitation == null ||
          previousDay?.precipitation == null) {
        continue;
      }
      final rain48h = eventDay!.precipitation! + previousDay!.precipitation!;
      final tempDrop = _temperatureDrop(byDate, date);
      final score = rain48h < ShockConfig.rainTriggerMm
          ? 0.0
          : _shockScore(rain48h, tempDrop);
      if (bestFactor == null || score > bestFactor) {
        bestFactor = score;
        bestDate = date;
        bestRain = rain48h;
        bestTempDrop = tempDrop;
      }
    }
    return (
      factor: bestFactor,
      date: bestDate,
      rain48h: bestRain,
      tempDrop: bestTempDrop,
    );
  }

  double _shockScore(double rain48h, double? tempDrop) {
    final rainPart = rain48h >= ShockConfig.rainHighMm
        ? ShockConfig.rainHighPart
        : rain48h >= ShockConfig.rainMediumMm
        ? ShockConfig.rainMediumPart
        : ShockConfig.rainLowPart;
    if (tempDrop == null) return rainPart;
    final tempPart = tempDrop >= ShockConfig.temperatureDropHighC
        ? ShockConfig.temperatureDropHighPart
        : tempDrop >= ShockConfig.temperatureDropMediumC
        ? ShockConfig.temperatureDropMediumPart
        : ShockConfig.temperatureDropNoPart;
    return (rainPart + tempPart) / 2;
  }

  double? _temperatureDrop(Map<DateTime, WeatherDay> byDate, DateTime date) {
    final previous = <double>[];
    for (var daysAgo = 4; daysAgo >= 2; daysAgo--) {
      final value =
          byDate[date.subtract(Duration(days: daysAgo))]?.temperatureMean;
      if (value == null) return null;
      previous.add(value);
    }
    final current = <double>[];
    for (var daysAhead = 0; daysAhead <= 1; daysAhead++) {
      final value =
          byDate[date.add(Duration(days: daysAhead))]?.temperatureMean;
      if (value == null) return null;
      current.add(value);
    }
    final previousMean = previous.reduce((a, b) => a + b) / previous.length;
    final currentMean = current.reduce((a, b) => a + b) / current.length;
    return previousMean - currentMean;
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
    double? shock,
    double? terrain,
    double? forest,
  ) {
    final waterWeight = ShockConfig.waterWeight;
    final temperatureWeight = ShockConfig.airOrSoilTemperatureWeight;
    final dryingWeight = ShockConfig.dryingWeight;
    final shockWeight = ShockConfig.shockWeight;
    final terrainWeight = ShockConfig.terrainWeight;
    final forestWeight = ShockConfig.forestWeight;

    // Calculer la somme des poids des facteurs connus
    double knownWeightSum = dryingWeight;
    if (water != null) knownWeightSum += waterWeight;
    if (temperature != null) knownWeightSum += temperatureWeight;
    if (shock != null) knownWeightSum += shockWeight;
    if (terrain != null) knownWeightSum += terrainWeight;
    if (forest != null) knownWeightSum += forestWeight;

    // Calculer le médian pondéré en redistribuant les poids
    var weightedSum = drying * dryingWeight;
    if (water != null) weightedSum += water * waterWeight;
    if (temperature != null) weightedSum += temperature * temperatureWeight;
    if (shock != null) weightedSum += shock * shockWeight;
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
    bool hasSoilMoisture,
    bool hasSoilTemperature,
    double? waterFactor,
    double? temperatureFactor,
    double? shockFactor,
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
    if (hasSoilMoisture) {
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
    if (!hasSoilMoisture) missingWeight += 0.15;
    if (!hasSoilTemperature) missingWeight += 0.05;
    if (waterFactor == null) missingWeight += ShockConfig.waterWeight;
    if (temperatureFactor == null) {
      missingWeight += ShockConfig.airOrSoilTemperatureWeight;
    }
    if (shockFactor == null) missingWeight += ShockConfig.shockWeight;

    return (confidence - missingWeight).clamp(0.0, 1.0);
  }
}
