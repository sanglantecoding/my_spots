import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/litto3d_layer.dart';

/// Emprise géographique d'une grande région Litto3D / LiDAR côtière.
class LidarRegionBounds {
  const LidarRegionBounds({
    required this.id,
    required this.name,
    required this.bounds,
    required this.layerIds,
  });

  final String id;
  final String name;
  final LatLngBounds bounds;
  final List<String> layerIds;

  bool intersects(LatLngBounds other) => bounds.isOverlapping(other);

  List<Litto3DLayer> get layers => Litto3DCatalog.layersFromIds(layerIds);
}

/// Emprises des régions LiDAR SHOM pour le filtrage spatial dynamique.
class LidarRegionCatalog {
  LidarRegionCatalog._();

  /// Marge de pré-chargement autour de la vue carte (~25 km).
  static const double viewMarginKm = 25;

  static final List<LidarRegionBounds> all = [
    LidarRegionBounds(
      id: 'normandie_hdf',
      name: 'Normandie et Hauts-de-France',
      bounds: LatLngBounds(LatLng(48.5, -2.0), LatLng(51.2, 2.5)),
      layerIds: ['normandie_hdf'],
    ),
    LidarRegionBounds(
      id: 'bretagne',
      name: 'Bretagne',
      bounds: LatLngBounds(LatLng(47.2, -5.5), LatLng(49.0, -1.0)),
      layerIds: [
        'bretagne_iroise',
        'bretagne_finistere',
        'bretagne_morbihan',
        'bretagne',
        'bretagne_rance',
        'bretagne_roches_douvres',
      ],
    ),
    LidarRegionBounds(
      id: 'nouvelle_aquitaine',
      name: 'Nouvelle-Aquitaine',
      bounds: LatLngBounds(LatLng(43.0, -2.0), LatLng(46.5, -0.5)),
      layerIds: ['nouvelle_aquitaine'],
    ),
    LidarRegionBounds(
      id: 'occitanie',
      name: 'Occitanie',
      bounds: LatLngBounds(LatLng(42.3, 1.5), LatLng(44.2, 4.5)),
      layerIds: ['occitanie_2009', 'occitanie_2011', 'occitanie_2014_2015'],
    ),
    LidarRegionBounds(
      id: 'paca',
      name: 'Provence-Alpes-Côte d\'Azur',
      bounds: LatLngBounds(LatLng(42.5, 4.5), LatLng(44.5, 7.8)),
      layerIds: ['paca'],
    ),
    LidarRegionBounds(
      id: 'corse',
      name: 'Corse',
      bounds: LatLngBounds(LatLng(41.3, 8.4), LatLng(43.1, 9.8)),
      layerIds: ['corse'],
    ),
    LidarRegionBounds(
      id: 'antilles',
      name: 'Antilles',
      bounds: LatLngBounds(LatLng(14.3, -62.0), LatLng(18.8, -60.8)),
      layerIds: [
        'antilles_guadeloupe',
        'antilles_martinique',
        'antilles_saint_barth',
        'antilles_saint_martin',
      ],
    ),
    LidarRegionBounds(
      id: 'spm',
      name: 'Saint-Pierre-et-Miquelon',
      bounds: LatLngBounds(LatLng(46.6, -56.5), LatLng(47.2, -56.0)),
      layerIds: ['spm'],
    ),
    LidarRegionBounds(
      id: 'ocean_indien',
      name: 'Océan Indien',
      bounds: LatLngBounds(LatLng(-13.0, 43.0), LatLng(-11.0, 56.0)),
      layerIds: ['indien_eparses', 'indien_mayotte', 'indien_reunion'],
    ),
    LidarRegionBounds(
      id: 'pacifique',
      name: 'Pacifique',
      bounds: LatLngBounds(LatLng(-18.5, -152.0), LatLng(-16.0, -148.5)),
      layerIds: [
        'pacifique_bora_bora',
        'pacifique_moorea',
        'pacifique_taharuu',
        'pacifique_tahiti',
      ],
    ),
  ];

  /// Étend une emprise visible avec une marge en kilomètres.
  static LatLngBounds expandBounds(LatLngBounds bounds, double marginKm) {
    final center = bounds.center;
    final latDelta = marginKm / 111.0;
    final lngDelta =
        marginKm / (111.0 * math.cos(center.latitude * math.pi / 180));

    return LatLngBounds(
      LatLng(bounds.south - latDelta, bounds.west - lngDelta),
      LatLng(bounds.north + latDelta, bounds.east + lngDelta),
    );
  }

  /// Régions dont l'emprise croise la zone visible (+ marge).
  static List<LidarRegionBounds> regionsIntersecting(
    LatLngBounds visibleBounds,
  ) {
    final query = expandBounds(visibleBounds, viewMarginKm);
    return all.where((region) => region.intersects(query)).toList();
  }

  /// Couches Litto3D actives pour la vue courante.
  static List<Litto3DLayer> activeLayersForView(LatLngBounds visibleBounds) {
    final regions = regionsIntersecting(visibleBounds);
    final seen = <String>{};
    final layers = <Litto3DLayer>[];

    for (final region in regions) {
      for (final layer in region.layers) {
        if (seen.add(layer.id)) {
          layers.add(layer);
        }
      }
    }

    layers.sort((a, b) {
      final regionIndex = Litto3DCatalog.regions
          .indexOf(a.region)
          .compareTo(Litto3DCatalog.regions.indexOf(b.region));
      if (regionIndex != 0) return regionIndex;
      return a.sortOrder.compareTo(b.sortOrder);
    });

    return layers;
  }
}
