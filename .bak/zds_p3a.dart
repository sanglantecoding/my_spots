import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\my_spots\lib\services\zone_download_service.dart';
  final sb = StringBuffer();

  sb.writeln('/// Orchestrator for downloading an [OfflineMap] zone.');
  sb.writeln('///');
  sb.writeln('/// Downloads each [OfflineMapLayer] into the zone-scoped FMTC store');
  sb.writeln('/// ([marineStoreForZone] / [lidarStoreForZone]) and updates ObjectBox');
  sb.writeln('/// state progressively via [OfflineMapRepository].');
  sb.writeln('class ZoneDownloadService {');
  sb.writeln('  ZoneDownloadService({');
  sb.writeln('    required this.repository,');
  sb.writeln('    LayerDownloader? downloader,');
  sb.writeln('  }) : _downloader = downloader ?? const FmtcLayerDownloader();');
  sb.writeln('');
  sb.writeln('  final OfflineMapRepository repository;');
  sb.writeln('  final LayerDownloader _downloader;');
  sb.writeln('  final Map<String, _ZoneState> _zones = {};');
  sb.writeln('');
  sb.writeln('  /// Whether a download is currently active for [zoneUuid].');
  sb.writeln('  bool isDownloading(String zoneUuid) =>');
  sb.writeln('      _zones.containsKey(zoneUuid) && !_zones[zoneUuid]!.isFinished;');
  sb.writeln('');
  sb.writeln('  /// Number of zones currently being downloaded (diagnostic).');
  sb.writeln('  int get activeCount =>');
  sb.writeln('      _zones.values.where((z) => !z.isFinished).length;');
  sb.writeln('');
  sb.writeln('  /// Downloads all [layers] of [map] sequentially.');
  sb.writeln('  ///');
  sb.writeln('  /// [onProgress] receives 0.0..1.0 global progress and a layer label.');
  sb.writeln('  /// Returns when all layers complete, [cancelDownload] is called,');
  sb.writeln('  /// or an unrecoverable error is thrown.');
  sb.writeln('  Future<void> downloadZone({');
  sb.writeln('    required OfflineMap map,');
  sb.writeln('    required List<OfflineMapLayer> layers,');
  sb.writeln('    ZoneProgressCallback? onProgress,');
  sb.writeln('  }) async {');
  sb.writeln('    if (layers.isEmpty) return;');
  sb.writeln('    final state = _ZoneState(zoneUuid: map.uuid, totalLayers: layers.length);');
  sb.writeln('    _zones[map.uuid] = state;');
  sb.writeln('');
  sb.writeln('    // 1) Mark zone and all layers as downloading.');
  sb.writeln('    map.status = OfflineMapStatus.downloading;');
  sb.writeln('    repository.save(map);');
  sb.writeln('    for (final layer in layers) {');
  sb.writeln('      layer.downloadStatus = LayerDownloadStatus.downloading;');
  sb.writeln('      repository.saveLayer(map, layer);');
  sb.writeln('    }');
  sb.writeln('');
  sb.writeln('    final bounds = LatLngBounds(');
  sb.writeln('      LatLng(map.southLat, map.westLng),');
  sb.writeln('      LatLng(map.northLat, map.eastLng),');
  sb.writeln('    );');

  File(path).writeAsStringSync(
    File(path).readAsStringSync() + sb.toString(),
    flush: true,
  );
  print('Part 3a appended: +${sb.length} chars');
}
