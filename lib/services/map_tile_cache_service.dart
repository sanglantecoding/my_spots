import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

/// Cache local des tuiles cartographiques (FMTC) pour usage hors-ligne.
class MapTileCacheService {
  static const String baseMapStore = 'baseMapTiles';

  /// Ancien store unique — conservé pour compatibilité des caches déjà créés.
  static const String bathymetryStore = 'bathymetryOverlayTiles';

  /// Couches Litto3D empilées dans l'overlay bathymétrie.
  static const List<String> bathymetryLayerNames = [
    'LITTO3D_LR_2009_PYR_3857_WMTS',
    'L3D_MAR_LR_2011_PYR_3857_WMTS',
    'L3D_MAR_LR_2014_2015_WMTS_3857',
  ];

  /// Cartes marines RasterMarine empilées par échelle (clevisu SHOM).
  static const List<String> marineLayerNames = [
    'RASTER_MARINE_50_WMTS_3857',
    'RASTER_MARINE_25_WMTS_3857',
    'RASTER_MARINE_10_WMTS_3857',
  ];

  /// Identifiant Android du projet (android/app/build.gradle.kts).
  static const String packageName = 'com.svc.my_spots';

  /// Version alignée sur pubspec.yaml pour le User-Agent IGN/SHOM.
  static const String appVersion = '1.0.0';

  /// En-têtes requis par la Géoplateforme (IGN) et les serveurs SHOM.
  static Map<String, String> get geoplateformeTileHeaders => {
        'User-Agent': '$packageName/$appVersion (Flutter)',
        'Accept': 'image/webp,image/png,image/*;q=0.8',
      };

  /// En-têtes pour les flux WMTS directs du SHOM (INSPIRE / clevisu).
  static Map<String, String> get shomTileHeaders => {
        ...geoplateformeTileHeaders,
        'Referer': 'https://data.shom.fr/',
      };

  static bool _initialised = false;
  static final Map<String, TileProvider> _bathymetryTileProviders = {};
  static final Map<String, TileProvider> _marineTileProviders = {};

  static String bathymetryStoreForLayer(String layerName) =>
      'bathymetryOverlay_$layerName';

  static String marineStoreForLayer(String layerName) =>
      'marineBase_$layerName';

  static Future<void> initialise() async {
    if (_initialised) return;
    await FMTCObjectBoxBackend().initialise();
    await const FMTCStore(baseMapStore).manage.create();
    await const FMTCStore(bathymetryStore).manage.create();
    for (final layerName in bathymetryLayerNames) {
      await FMTCStore(bathymetryStoreForLayer(layerName)).manage.create();
    }
    for (final layerName in marineLayerNames) {
      await FMTCStore(marineStoreForLayer(layerName)).manage.create();
    }
    _initialised = true;
  }

  static final TileProvider baseMapTileProvider = FMTCTileProvider(
    stores: {baseMapStore: BrowseStoreStrategy.readUpdateCreate},
    headers: geoplateformeTileHeaders,
  );

  /// Provider FMTC dédié par couche cartographique marine SHOM.
  static TileProvider marineTileProviderFor(String layerName) {
    return _marineTileProviders.putIfAbsent(layerName, () {
      return FMTCTileProvider(
        stores: {
          marineStoreForLayer(layerName): BrowseStoreStrategy.readUpdateCreate,
        },
        headers: shomTileHeaders,
      );
    });
  }

  /// Provider FMTC dédié par couche Litto3D SHOM.
  ///
  /// Obligatoire : un seul [FMTCTileProvider] partagé provoque une collision
  /// dans le cache mémoire Flutter (clé = coordonnées + provider, sans URL).
  static TileProvider bathymetryTileProviderFor(String layerName) {
    return _bathymetryTileProviders.putIfAbsent(layerName, () {
      return FMTCTileProvider(
        stores: {
          bathymetryStoreForLayer(layerName):
              BrowseStoreStrategy.readUpdateCreate,
        },
        headers: shomTileHeaders,
      );
    });
  }
}
