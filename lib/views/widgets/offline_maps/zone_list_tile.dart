import 'package:flutter/material.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';

/// A single zone row for the offline-maps zone list.
class ZoneListTile extends StatelessWidget {
  const ZoneListTile({
    super.key,
    required this.map,
    required this.layers,
    required this.progress,
    required this.isDownloading,
    required this.isPaused,
    required this.activeLayerLabel,
    required this.onDownload,
    required this.onCancel,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
    this.totalSizeBytes,
  });

  final OfflineMap map;
  final List<OfflineMapLayer> layers;
  final double progress;
  final bool isDownloading;
  final bool isPaused;
  final String activeLayerLabel;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  /// Total size of downloaded tiles in bytes (null if not yet computed).
  final int? totalSizeBytes;

  int get _totalEstimated => layers.fold(0, (s, l) => s + l.estimatedTileCount);
  int get _totalDownloaded =>
      layers.fold(0, (s, l) => s + l.downloadedTileCount);
  bool get _hasFailedLayer => layers.any((l) => l.isFailed);

  String get _statusText {
    if (isDownloading) {
      final pct = (progress * 100).round();
      if (activeLayerLabel.isNotEmpty) return '$activeLayerLabel - $pct %';
      return 'Telechargement... $pct %';
    }
    return switch (map.status) {
      OfflineMapStatus.notStarted => 'Non demarre',
      OfflineMapStatus.downloading => 'En cours...',
      OfflineMapStatus.ready => 'Pret',
      OfflineMapStatus.partial =>
        'Partiel - $_totalDownloaded / $_totalEstimated tuiles',
      OfflineMapStatus.failed =>
        'Echoue${_hasFailedLayer ? ' - verifiez les couches' : ''}',
    };
  }

  Color get _statusColor {
    if (isDownloading) return Colors.amber;
    return switch (map.status) {
      OfflineMapStatus.notStarted => Colors.grey,
      OfflineMapStatus.downloading => Colors.amber,
      OfflineMapStatus.ready => Colors.greenAccent,
      OfflineMapStatus.partial => Colors.orangeAccent,
      OfflineMapStatus.failed => Colors.redAccent,
    };
  }

  IconData get _statusIcon => switch (map.status) {
    OfflineMapStatus.notStarted => Icons.download_outlined,
    OfflineMapStatus.downloading => Icons.cloud_download,
    OfflineMapStatus.ready => Icons.check_circle,
    OfflineMapStatus.partial => Icons.warning_amber,
    OfflineMapStatus.failed => Icons.error,
  };

  String get _boundsHint =>
      '${map.southLat.toStringAsFixed(3)} - '
      '${map.northLat.toStringAsFixed(3)} N, '
      '${map.westLng.toStringAsFixed(3)} - ${map.eastLng.toStringAsFixed(3)} E';

  /// Returns a localized size suffix like " - 14,2 Mo" or empty if not available.
  String _formatSizeSuffix() {
    if (totalSizeBytes == null || totalSizeBytes! <= 0) return '';
    return ' - ${_formatBytes(totalSizeBytes!)}';
  }

  /// Lightweight byte-to-Mo formatter. Falls back to Ko / o for smaller values.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1).replaceAll('.', ',')} Ko';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1B2A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isDownloading
            ? Colors.amber.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.07),
        width: isDownloading ? 1.5 : 1,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      map.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(_statusIcon, color: _statusColor, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _statusText,
                            style: TextStyle(
                              color: _statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _boundsHint,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [_buildStatusChip()],
              ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                backgroundColor: Colors.white12,
                color: Colors.blueAccent,
                minHeight: 6,
              ),
            ),
            if (isPaused) ...[
              const SizedBox(height: 4),
              const Text(
                'En pause',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (_totalEstimated > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$_totalDownloaded / $_totalEstimated tuiles${_formatSizeSuffix()}',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ] else if (_totalDownloaded > 0 || _totalEstimated > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$_totalDownloaded / $_totalEstimated tuiles${_formatSizeSuffix()}',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
          const SizedBox(height: 12),
          // Action row fits 3 buttons on one line, wraps to 2 lines
          // on extremely narrow screens (never overflows).
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 0,
              runSpacing: 6,
              children: _buildActions(),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildStatusChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _statusColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
    ),
    child: Text(
      map.status.name,
      style: TextStyle(
        color: _statusColor,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
  );

  List<Widget> _buildActions() {
    final buttons = <Widget>[];

    if (isDownloading && !isPaused) {
      // En cours de téléchargement (pas en pause)
      buttons.add(
        _actionBtn(
          icon: Icons.pause,
          label: 'Pause',
          color: Colors.orangeAccent,
          onTap: onPause,
        ),
      );
      buttons.add(
        _actionBtn(
          icon: Icons.cancel,
          label: 'Annuler',
          color: Colors.redAccent,
          onTap: onCancel,
        ),
      );
    } else if (isDownloading && isPaused) {
      // En pause
      buttons.add(
        _actionBtn(
          icon: Icons.play_arrow,
          label: 'Reprendre',
          color: Colors.greenAccent,
          onTap: onResume,
        ),
      );
      buttons.add(
        _actionBtn(
          icon: Icons.cancel,
          label: 'Annuler',
          color: Colors.redAccent,
          onTap: onCancel,
        ),
      );
    } else {
      // Pas en cours de téléchargement
      if (map.status == OfflineMapStatus.notStarted) {
        buttons.add(
          _actionBtn(
            icon: Icons.download,
            label: 'Telecharger',
            color: Colors.blueAccent,
            onTap: onDownload,
          ),
        );
      } else if (map.status == OfflineMapStatus.partial ||
          map.status == OfflineMapStatus.failed) {
        buttons.add(
          _actionBtn(
            icon: Icons.refresh,
            label: 'Mettre à jour la zone',
            color: Colors.blueAccent,
            onTap: onDownload,
          ),
        );
      }
    }

    // "Supprimer" est toujours visible
    buttons.add(
      _actionBtn(
        icon: Icons.delete_outline,
        label: 'Supprimer',
        color: Colors.redAccent,
        onTap: onDelete,
      ),
    );
    return buttons;
  }

  /// Compact action button: reduced padding + font to fit 3 buttons in one row.
  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
