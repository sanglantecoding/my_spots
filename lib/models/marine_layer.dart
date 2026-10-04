import 'offline_map_layer.dart';

/// Modèle d'une couche marine SHOM (RasterMarine clevisu).
///
/// Source UNIQUE de vérité : nom WMTS, type offline, plages de zoom
/// d'affichage, zoom de probe preflight. Miroir de [Litto3DCatalog].
class MarineLayer {
  /// Nom exact de la couche WMTS clevisu.
  final String wmtsLayerName;

  /// Type de couche offline (null = couche d'affichage uniquement,
  /// jamais téléchargée dans une zone).
  final LayerType? layerType;

  /// Plage de zoom d'affichage (empilement flutter_map).
  final double minZoom;
  final double maxZoom;

  /// Zooms natifs de la couche (overzoom au-delà).
  final int minNativeZoom;
  final int maxNativeZoom;

  /// Zoom utilisé par le preflight de couverture SHOM (couches
  /// téléchargeables uniquement).
  final int probeZoom;

  const MarineLayer({
    required this.wmtsLayerName,
    this.layerType,
    required this.minZoom,
    required this.maxZoom,
    required this.minNativeZoom,
    required this.maxNativeZoom,
    this.probeZoom = 12,
  });

  bool get isDownloadable => layerType != null;
}

/// Catalogue des couches marines — noms vérifiés via GetCapabilities clevisu.
class MarineLayerCatalog {
  MarineLayerCatalog._();

  // ── Couches d'affichage uniquement ──
  static const MarineLayer overview = MarineLayer(
    wmtsLayerName: 'RASTER_MARINE_3857_WMTS',
    minZoom: 1.0,
    maxZoom: 8.0,
    minNativeZoom: 1,
    maxNativeZoom: 7,
  );
  static const MarineLayer marine350k = MarineLayer(
    wmtsLayerName: 'RASTER_MARINE_350_WMTS_3857',
    minZoom: 7.0,
    maxZoom: 10.0,
    minNativeZoom: 6,
    maxNativeZoom: 9,
  );
  static const MarineLayer marine100k = MarineLayer(
    wmtsLayerName: 'RASTER_MARINE_100_WMTS_3857',
    minZoom: 9.0,
    maxZoom: 12.0,
    minNativeZoom: 9,
    maxNativeZoom: 11,
  );

  // ── Couches téléchargeables offline ──
  static const MarineLayer marine50k = MarineLayer(
    wmtsLayerName: 'RASTER_MARINE_50_WMTS_3857',
    layerType: LayerType.marine50k,
    minZoom: 11.0,
    maxZoom: 22.0,
    minNativeZoom: 11,
    maxNativeZoom: 14,
    probeZoom: 12,
  );
  static const MarineLayer marine25k = MarineLayer(
    wmtsLayerName: 'RASTER_MARINE_25_WMTS_3857',
    layerType: LayerType.marine25k,
    minZoom: 12.0,
    maxZoom: 22.0,
    minNativeZoom: 12,
    maxNativeZoom: 15,
    probeZoom: 13,
  );
  static const MarineLayer marine10k = MarineLayer(
    wmtsLayerName: 'RASTER_MARINE_10_WMTS_3857',
    layerType: LayerType.marine10k,
    minZoom: 14.0,
    maxZoom: 22.0,
    minNativeZoom: 14,
    maxNativeZoom: 16,
    probeZoom: 15,
  );

  /// Toutes les couches vivantes (affichage + offline).
  /// ⚠️ Le 1M ('RASTER_MARINE_1M_3857_WMTS') est volontairement absent :
  /// aucun chemin d'affichage ni de téléchargement ne l'utilise.
  static const List<MarineLayer> allLayers = [
    overview,
    marine350k,
    marine100k,
    marine50k,
    marine25k,
    marine10k,
  ];

  static List<String> get allWmtsNames =>
      allLayers.map((l) => l.wmtsLayerName).toList();

  /// Couches téléchargées dans les zones (50K/25K/10K).
  static List<MarineLayer> get downloadableLayers =>
      allLayers.where((l) => l.isDownloadable).toList();

  static MarineLayer? findByWmtsName(String name) {
    for (final l in allLayers) {
      if (l.wmtsLayerName == name) return l;
    }
    return null;
  }

  static MarineLayer? findByLayerType(LayerType type) {
    for (final l in allLayers) {
      if (l.layerType == type) return l;
    }
    return null;
  }
}
