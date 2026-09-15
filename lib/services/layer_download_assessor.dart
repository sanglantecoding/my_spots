import 'package:flutter/foundation.dart';

class LayerDownloadResult {
  const LayerDownloadResult({
    required this.downloadedTileCount,
    required this.estimatedTileCount,
    required this.successful,
    this.negativeTileCount = 0,
    this.failedTileCount = 0,
  });

  final int downloadedTileCount;
  final int estimatedTileCount;
  final bool successful;
  final int negativeTileCount;
  final int failedTileCount;
}

class LayerDownloadAssessor {
  static const int maxTileCountCeiling = 12000;
  static const double negativeTolerance = 0.20;
  static const double networkFailureTolerance = 0.15;

  static LayerDownloadResult assessResult(
    int maxTiles,
    int successful,
    int failed,
    int negative,
  ) {
    final total = maxTiles > 0 ? maxTiles : (successful + failed + negative);
    if (total == 0) {
      return const LayerDownloadResult(
        downloadedTileCount: 0,
        estimatedTileCount: 0,
        successful: false,
      );
    }

    final failedRatio = failed / total;
    final ok = failedRatio <= networkFailureTolerance;

    if (!ok) {
      debugPrint(
        '[LayerDownloadAssessor] Layer assessed FAILED: '
        'successful=$successful failedRatio=${failedRatio.toStringAsFixed(3)} total=$total',
      );
    }

    return LayerDownloadResult(
      downloadedTileCount: successful,
      estimatedTileCount: total,
      successful: ok,
      negativeTileCount: negative,
      failedTileCount: failed,
    );
  }
}
