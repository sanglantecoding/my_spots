/// Modèle représentant une couche Litto3D (LiDAR) du SHOM.
class Litto3DLayer {
  final String id;
  final String name;
  final String region;
  final String wmtsLayerName;
  final int sortOrder;

  const Litto3DLayer({
    required this.id,
    required this.name,
    required this.region,
    required this.wmtsLayerName,
    required this.sortOrder,
  });
}

/// Catalogue Litto3D — identifiants WMTS vérifiés via GetCapabilities SHOM INSPIRE.
class Litto3DCatalog {
  Litto3DCatalog._();

  /// Occitanie activée par défaut (comportement historique de l'app).
  static const List<String> defaultLayerIds = [
    'occitanie_2009',
    'occitanie_2011',
    'occitanie_2014_2015',
  ];

  static List<String> get allLayerIds =>
      allLayers.map((layer) => layer.id).toList();

  /// Toutes les couches publiées sur services.data.shom.fr/INSPIRE/wmts.
  static const List<Litto3DLayer> allLayers = [
    // ── Normandie et Hauts-de-France ──
    Litto3DLayer(
      id: 'normandie_hdf',
      name: 'Normandie et Hauts-de-France 2016-2018',
      region: 'Normandie et Hauts-de-France',
      wmtsLayerName: 'L3D_MAR_NHDF_2016_2018_PYR_3857_WMTS',
      sortOrder: 0,
    ),

    // ── Bretagne (chronologique) ──
    Litto3DLayer(
      id: 'bretagne_iroise',
      name: 'Parc Naturel Marin d\'Iroise 2012',
      region: 'Bretagne',
      wmtsLayerName: 'L3D_MAR_PNMI_2012_PYR_3857_WMTS',
      sortOrder: 0,
    ),
    Litto3DLayer(
      id: 'bretagne_finistere',
      name: 'Finistère 2014',
      region: 'Bretagne',
      wmtsLayerName: 'LITTO3D_FINISTR_2014_PYR_3857_WMTS',
      sortOrder: 1,
    ),
    Litto3DLayer(
      id: 'bretagne_morbihan',
      name: 'Morbihan 2015',
      region: 'Bretagne',
      wmtsLayerName: 'L3D_MAR_MORBIHAN_2015_PYR_3857_WMTS',
      sortOrder: 2,
    ),
    Litto3DLayer(
      id: 'bretagne',
      name: 'Bretagne 2018-2021',
      region: 'Bretagne',
      wmtsLayerName: 'LITTO3D_BZH_2018_2021_PYR_3857_WMTS',
      sortOrder: 3,
    ),
    Litto3DLayer(
      id: 'bretagne_rance',
      name: 'Rance 2019',
      region: 'Bretagne',
      wmtsLayerName: 'L3D_LIDAR_RANCE_2019_WMTS_3857',
      sortOrder: 4,
    ),
    Litto3DLayer(
      id: 'bretagne_roches_douvres',
      name: 'Roches Douvres - Barnouic 2022',
      region: 'Bretagne',
      wmtsLayerName: 'L3D_LIDAR_ROCHES_DOUVRES_BARNOUIC_2022_WMTS_3857',
      sortOrder: 5,
    ),

    // ── Nouvelle-Aquitaine ──
    Litto3DLayer(
      id: 'nouvelle_aquitaine',
      name: 'Nouvelle-Aquitaine 2020-2022',
      region: 'Nouvelle-Aquitaine',
      wmtsLayerName: 'LITTO3D_NAQ_2020_2022_PYR_PNG_3857_WMTS',
      sortOrder: 0,
    ),

    // ── Occitanie (chronologique) ──
    Litto3DLayer(
      id: 'occitanie_2009',
      name: 'Languedoc-Roussillon 2009',
      region: 'Occitanie',
      wmtsLayerName: 'LITTO3D_LR_2009_PYR_3857_WMTS',
      sortOrder: 0,
    ),
    Litto3DLayer(
      id: 'occitanie_2011',
      name: 'Languedoc-Roussillon 2011',
      region: 'Occitanie',
      wmtsLayerName: 'L3D_MAR_LR_2011_PYR_3857_WMTS',
      sortOrder: 1,
    ),
    Litto3DLayer(
      id: 'occitanie_2014_2015',
      name: 'Languedoc-Roussillon 2014-2015',
      region: 'Occitanie',
      wmtsLayerName: 'L3D_MAR_LR_2014_2015_WMTS_3857',
      sortOrder: 2,
    ),

    // ── Provence-Alpes-Côte d'Azur ──
    Litto3DLayer(
      id: 'paca',
      name: 'Provence-Alpes-Côte d\'Azur 2015',
      region: 'Provence-Alpes-Côte d\'Azur',
      wmtsLayerName: 'LITTO3D_PACA_2015_PYR_3857_WMTS',
      sortOrder: 0,
    ),

    // ── Corse ──
    Litto3DLayer(
      id: 'corse',
      name: 'Corse 2017-2018',
      region: 'Corse',
      wmtsLayerName: 'L3D_LIDAR_CORSE_2017_2018_PYR_3857_WMTS',
      sortOrder: 0,
    ),

    // ── Antilles ──
    Litto3DLayer(
      id: 'antilles_guadeloupe',
      name: 'Guadeloupe 2016',
      region: 'Antilles',
      wmtsLayerName: 'LITTO3D_GUAD_2016_PYR_3857_WMTS',
      sortOrder: 0,
    ),
    Litto3DLayer(
      id: 'antilles_martinique',
      name: 'Martinique 2016',
      region: 'Antilles',
      wmtsLayerName: 'LITTO3D_MART_2016_PYR_3857_WMTS',
      sortOrder: 1,
    ),
    Litto3DLayer(
      id: 'antilles_saint_barth',
      name: 'Saint-Barthélemy 2019',
      region: 'Antilles',
      wmtsLayerName: 'LITTO3D_STBARTHELEMY_2019_PYR_3857_WMTS',
      sortOrder: 2,
    ),
    Litto3DLayer(
      id: 'antilles_saint_martin',
      name: 'Saint-Martin 2019',
      region: 'Antilles',
      wmtsLayerName: 'LITTO3D_STMARTIN_2019_PYR_3857_WMTS',
      sortOrder: 3,
    ),

    // ── Saint-Pierre-et-Miquelon ──
    Litto3DLayer(
      id: 'spm',
      name: 'Saint-Pierre-et-Miquelon 2023',
      region: 'Saint-Pierre-et-Miquelon',
      wmtsLayerName: 'LITTO3D_SPM_2023_PYR_PNG_3857_WMTS',
      sortOrder: 0,
    ),

    // ── Océan Indien ──
    Litto3DLayer(
      id: 'indien_eparses',
      name: 'Îles Éparses 2012',
      region: 'Océan Indien',
      wmtsLayerName: 'LITTO3D_EPARSES_2012_PYR_3857_WMTS',
      sortOrder: 0,
    ),
    Litto3DLayer(
      id: 'indien_mayotte',
      name: 'Mayotte 2012',
      region: 'Océan Indien',
      wmtsLayerName: 'LITTO3D_MAYOT_2012_PYR_3857_WMTS',
      sortOrder: 1,
    ),
    Litto3DLayer(
      id: 'indien_reunion',
      name: 'Réunion 2016',
      region: 'Océan Indien',
      wmtsLayerName: 'LITTO3D_REUNION_2016_PYR_3857_WMTS',
      sortOrder: 2,
    ),

    // ── Pacifique ──
    Litto3DLayer(
      id: 'pacifique_bora_bora',
      name: 'Bora Bora 2015',
      region: 'Pacifique',
      wmtsLayerName: 'L3D_LIDAR_POLYNESIE_BOR_2015_WMTS_3857',
      sortOrder: 0,
    ),
    Litto3DLayer(
      id: 'pacifique_moorea',
      name: 'Moorea 2015',
      region: 'Pacifique',
      wmtsLayerName: 'L3D_LIDAR_POLYNESIE_MOO_2015_WMTS_3857',
      sortOrder: 1,
    ),
    Litto3DLayer(
      id: 'pacifique_taharuu',
      name: 'Taharuu 2015',
      region: 'Pacifique',
      wmtsLayerName: 'L3D_LIDAR_POLYNESIE_TAHARUU_2015_WMTS_3857',
      sortOrder: 2,
    ),
    Litto3DLayer(
      id: 'pacifique_tahiti',
      name: 'Tahiti 2015',
      region: 'Pacifique',
      wmtsLayerName: 'L3D_LIDAR_POLYNESIE_TAHITI_2015_WMTS_3857',
      sortOrder: 3,
    ),
  ];

  static List<String> get regions {
    final seen = <String>{};
    final result = <String>[];
    for (final layer in allLayers) {
      if (seen.add(layer.region)) {
        result.add(layer.region);
      }
    }
    return result;
  }

  static List<Litto3DLayer> layersForRegion(String region) {
    return allLayers.where((l) => l.region == region).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static Litto3DLayer? findById(String id) {
    for (final layer in allLayers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  static Litto3DLayer? findByWmtsName(String wmtsLayerName) {
    for (final layer in allLayers) {
      if (layer.wmtsLayerName == wmtsLayerName) return layer;
    }
    return null;
  }

  /// Couches activées, triées région puis chronologie (ancien → récent).
  static List<Litto3DLayer> layersFromIds(List<String> ids) {
    final selected =
        ids.map(findById).whereType<Litto3DLayer>().toList();
    selected.sort((a, b) {
      final regionIndex = regions.indexOf(a.region).compareTo(
            regions.indexOf(b.region),
          );
      if (regionIndex != 0) return regionIndex;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return selected;
  }

  /// Filtre les IDs obsolètes ou inconnus (ex. anciens identifiants WMTS fictifs).
  static List<String> sanitizeLayerIds(List<String> ids) {
    return ids.where((id) => findById(id) != null).toList();
  }
}
