import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\lib\services\zone_download_service.dart';
  final sb = StringBuffer();

  sb.writeln('');
  sb.writeln('/// WMTS URL template for a marine layer name (Clevisu).');
  sb.writeln('String _marineUrl(String layerName) =>');
  sb.writeln('    MarineMapService.clevisuWmtsUrl(layerName);');
  sb.writeln('');
  sb.writeln('/// WMTS URL template for a LiDAR (INSPIRE) layer name.');
  sb.writeln('String _lidarUrl(String wmtsLayerName) =>');
  sb.writeln('    MarineMapService.inspireWmtsUrl(wmtsLayerName);');
  sb.writeln('');
  sb.writeln('/// Returns the WMTS URL template for a [LayerType].');
  sb.writeln('String urlForLayerType(LayerType type) {');
  sb.writeln('  switch (type) {');
  sb.writeln('    case LayerType.marine50k:');
  sb.writeln("      return _marineUrl('RASTER_MARINE_50_WMTS_3857');");
  sb.writeln('    case LayerType.marine25k:');
  sb.writeln("      return _marineUrl('RASTER_MARINE_25_WMTS_3857');");
  sb.writeln('    case LayerType.marine10k:');
  sb.writeln("      return _marineUrl('RASTER_MARINE_10_WMTS_3857');");
  sb.writeln('    case LayerType.lidarOmbrage:');
  sb.writeln("      return _lidarUrl(MapTileCacheService.lidarOmbrageLayerName);");
  sb.writeln('    case LayerType.lidarLitto3d:');
  sb.writeln('      // Use the first available Litto3D layer.');
  sb.writeln('      if (Litto3DCatalog.allLayers.isEmpty) {');
  sb.writeln("        throw ArgumentError('No Litto3D layers in catalog');");
  sb.writeln('      }');
  sb.writeln('      return _lidarUrl(Litto3DCatalog.allLayers.first.wmtsLayerName);');
  sb.writeln('  }');
  sb.writeln('}');
  sb.writeln('');
  sb.writeln('/// HTTP headers required to call SHOM WMTS endpoints.');
  sb.writeln('Map<String, String> shomHeaders() => MapTileCacheService.shomTileHeaders;');
  sb.writeln('');
  sb.writeln('/// Returns the zone-scoped FMTC store for a layer type.');
  sb.writeln('FMTCStore storeForLayerType(String zoneUuid, LayerType type) {');
  sb.writeln('  switch (type) {');
  sb.writeln('    case LayerType.marine50k:');
  sb.writeln('    case LayerType.marine25k:');
  sb.writeln('    case LayerType.marine10k:');
  sb.writeln('      return MapTileCacheService.marineStoreForZone(zoneUuid);');
  sb.writeln('    case LayerType.lidarOmbrage:');
  sb.writeln('    case LayerType.lidarLitto3d:');
  sb.writeln('      return MapTileCacheService.lidarStoreForZone(zoneUuid);');
  sb.writeln('  }');
  sb.writeln('}');
  sb.writeln('');
  sb.writeln('/// Internal per-zone download state.');
  sb.writeln('class _ZoneState {');
  sb.writeln('  _ZoneState({');
  sb.writeln('    required this.zoneUuid,');
  sb.writeln('    required this.totalLayers,');
  sb.writeln('    this.completedLayers = 0,');
  sb.writeln('    this.failedLayers = 0,');
  sb.writeln('    this.isCancelled = false,');
  sb.writeln('  });');
  sb.writeln('  final String zoneUuid;');
  sb.writeln('  final int totalLayers;');
  sb.writeln('  int completedLayers;');
  sb.writeln('  int failedLayers;');
  sb.writeln('  bool isCancelled;');
  sb.writeln('  bool get isFinished =>');
  sb.writeln('      isCancelled || completedLayers + failedLayers >= totalLayers;');
  sb.writeln('}');
  sb.writeln('');

  File(path).writeAsStringSync(
    File(path).readAsStringSync() + sb.toString(),
    flush: true,
  );
  print('Part 2 appended: +${sb.length} chars');
}
