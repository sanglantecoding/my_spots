import 'package:my_spots/models/shom_10k_catalog.dart';

/// Couche téléchargeable hors-ligne pour une zone SHOM 1:10 000.
enum ShomOfflineLayer { marine, lidar }

/// Issue d'un téléchargement de zone (carte marine et/ou LiDAR).
enum ShomDownloadOutcome { success, cancelled, failed }

/// Résultat explicite d'un téléchargement hors-ligne SHOM.
class ShomDownloadResult {
  const ShomDownloadResult._(this.outcome, [this.errorMessage]);

  final ShomDownloadOutcome outcome;
  final String? errorMessage;

  bool get isSuccess => outcome == ShomDownloadOutcome.success;
  bool get isCancelled => outcome == ShomDownloadOutcome.cancelled;
  bool get isFailed => outcome == ShomDownloadOutcome.failed;

  static const ShomDownloadResult success = ShomDownloadResult._(
    ShomDownloadOutcome.success,
  );
  static const ShomDownloadResult cancelled = ShomDownloadResult._(
    ShomDownloadOutcome.cancelled,
  );

  factory ShomDownloadResult.failed(String errorMessage) =>
      ShomDownloadResult._(ShomDownloadOutcome.failed, errorMessage);
}

/// Plan de téléchargement pour une zone (carte et/ou LiDAR).
class ShomRegionDownloadPlan {
  const ShomRegionDownloadPlan({
    required this.region,
    required this.downloadMarine,
    required this.downloadLidar,
  });

  final Shom10kRegion region;
  final bool downloadMarine;
  final bool downloadLidar;

  bool get hasWork => downloadMarine || downloadLidar;
}

/// Tailles estimées ou mesurées du cache par couche (octets).
class ShomRegionLayerSizes {
  const ShomRegionLayerSizes({this.marineBytes = 0, this.lidarBytes = 0});

  final int marineBytes;
  final int lidarBytes;

  int get totalBytes => marineBytes + lidarBytes;

  ShomRegionLayerSizes copyWith({int? marineBytes, int? lidarBytes}) {
    return ShomRegionLayerSizes(
      marineBytes: marineBytes ?? this.marineBytes,
      lidarBytes: lidarBytes ?? this.lidarBytes,
    );
  }
}

/// État cache affiché pour une zone.
class ShomRegionCacheStatus {
  const ShomRegionCacheStatus({
    required this.marineDownloaded,
    required this.lidarDownloaded,
    required this.marineBytes,
    required this.lidarBytes,
  });

  final bool marineDownloaded;
  final bool lidarDownloaded;
  final int marineBytes;
  final int lidarBytes;

  static const empty = ShomRegionCacheStatus(
    marineDownloaded: false,
    lidarDownloaded: false,
    marineBytes: 0,
    lidarBytes: 0,
  );
}

/// Formate une taille en octets pour l'affichage (Ko / Mo).
String formatOfflineCacheBytes(int bytes) {
  if (bytes <= 0) return '0 Mo';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).round()} Ko';
  }
  return '${(bytes / (1024 * 1024)).round()} Mo';
}
