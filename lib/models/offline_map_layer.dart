import 'package:objectbox/objectbox.dart';
import 'package:my_spots/models/offline_map.dart';

enum LayerType {
  marine50k,
  marine25k,
  marine10k,
  lidarLitto3d,
}

enum LayerDownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  skipped,
}

@Entity()
class OfflineMapLayer {
  @Id()
  int id = 0;

  /// Backing field for the ToOne relation to OfflineMap.
  /// ObjectBox stores the parent map id here.
  int offlineMapId = 0;

  /// Convenience accessor returning the related OfflineMap (lazy).
  final offlineMap = ToOne<OfflineMap>();

  int layerTypeIndex;
  int minZoom;
  int maxZoom;
  int statusIndex;
  int estimatedTileCount;
  int downloadedTileCount;

  OfflineMapLayer({
    this.id = 0,
    this.offlineMapId = 0,
    required this.layerTypeIndex,
    required this.minZoom,
    required this.maxZoom,
    required this.statusIndex,
    this.estimatedTileCount = 0,
    this.downloadedTileCount = 0,
  });

  factory OfflineMapLayer.create({
    required LayerType layerType,
    required int minZoom,
    required int maxZoom,
  }) {
    return OfflineMapLayer(
      layerTypeIndex: layerType.index,
      minZoom: minZoom,
      maxZoom: maxZoom,
      statusIndex: LayerDownloadStatus.pending.index,
    );
  }

  LayerType get layerType => LayerType.values[
      layerTypeIndex.clamp(0, LayerType.values.length - 1)];

  set layerType(LayerType value) {
    layerTypeIndex = value.index;
  }

  LayerDownloadStatus get downloadStatus => LayerDownloadStatus.values[
      statusIndex.clamp(0, LayerDownloadStatus.values.length - 1)];

  set downloadStatus(LayerDownloadStatus value) {
    statusIndex = value.index;
  }

  bool get isCompleted => downloadStatus == LayerDownloadStatus.completed;
  bool get isFailed => downloadStatus == LayerDownloadStatus.failed;
  bool get isSkipped => downloadStatus == LayerDownloadStatus.skipped;
  bool get isDownloading => downloadStatus == LayerDownloadStatus.downloading;
  bool get isPending => downloadStatus == LayerDownloadStatus.pending;

  @override
  String toString() =>
      'OfflineMapLayer(id=$id, type=${layerType.name}, status=${downloadStatus.name}, '
      'minZoom=$minZoom, maxZoom=$maxZoom, '
      'downloaded=$downloadedTileCount/$estimatedTileCount)';
}