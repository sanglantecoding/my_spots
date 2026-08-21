import 'package:flutter/material.dart';
import 'package:my_spots/models/shom_10k_catalog.dart';
import 'package:my_spots/models/shom_offline_region_state.dart';
import 'package:my_spots/services/shom_download_service.dart';

/// Gestion du stockage hors-ligne — cartes 1:10 000 et relief LiDAR séparés.
class OfflineManagementScreen extends StatefulWidget {
  const OfflineManagementScreen({super.key});

  @override
  State<OfflineManagementScreen> createState() =>
      _OfflineManagementScreenState();
}

class _OfflineManagementScreenState extends State<OfflineManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Shom10kRegion> _regions = Shom10kCatalog.allRegions;
  Map<String, ShomRegionCacheStatus> _cacheStatus = {};
  String _searchQuery = '';

  final Set<String> _downloadingRegionIds = {};
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    _refreshCacheStatuses();
  }

  @override
  void dispose() {
    if (_downloadingRegionIds.isNotEmpty) {
      ShomDownloadService.cancelDownload();
    }
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  ShomOfflineLayer get _currentTabLayer => _tabController.index == 0
      ? ShomOfflineLayer.marine
      : ShomOfflineLayer.lidar;

  Future<void> _refreshCacheStatuses() async {
    _cacheStatus = await ShomDownloadService.loadAllCacheStatuses(
      _regions.map((r) => r.id),
    );
    if (mounted) setState(() {});
  }

  List<Shom10kRegion> get _visibleRegions {
    if (_searchQuery.trim().isEmpty) return _regions;
    return _regions.where((r) => r.matchesQuery(_searchQuery)).toList();
  }

  bool _isDownloaded(Shom10kRegion region, ShomOfflineLayer layer) {
    final status = _cacheStatus[region.id] ?? ShomRegionCacheStatus.empty;
    return switch (layer) {
      ShomOfflineLayer.marine => status.marineDownloaded,
      ShomOfflineLayer.lidar => status.lidarDownloaded,
    };
  }

  int _cacheBytes(Shom10kRegion region, ShomOfflineLayer layer) {
    final status = _cacheStatus[region.id] ?? ShomRegionCacheStatus.empty;
    return switch (layer) {
      ShomOfflineLayer.marine => status.marineBytes,
      ShomOfflineLayer.lidar => status.lidarBytes,
    };
  }

  String _statusLabel(Shom10kRegion region, ShomOfflineLayer layer) {
    final regionKey = '${region.id}_${layer.name}';
    if (_downloadingRegionIds.contains(regionKey)) {
      final progress = _downloadProgress[regionKey] ?? 0;
      return 'Téléchargement… ${(progress * 100).round()} %';
    }
    if (_isDownloaded(region, layer)) {
      return '${formatOfflineCacheBytes(_cacheBytes(region, layer))} · Téléchargé';
    }
    return 'Non téléchargé';
  }

  void _onToggle(Shom10kRegion region, ShomOfflineLayer layer, bool? checked) {
    if (checked == null) return;

    final regionKey = '${region.id}_${layer.name}';

    if (checked) {
      // Téléchargement : ajouter immédiatement à la liste et lancer en arrière-plan
      if (_downloadingRegionIds.contains(regionKey)) return;
      if (_isDownloaded(region, layer)) return;

      setState(() {
        _downloadingRegionIds.add(regionKey);
        _downloadProgress[regionKey] = 0;
      });

      _downloadRegion(region, layer);
      return;
    }

    // Décochage : annuler le téléchargement ou supprimer le cache
    if (_downloadingRegionIds.contains(regionKey)) {
      // Annuler le téléchargement en cours
      ShomDownloadService.cancelDownload(layer: layer);
      setState(() {
        _downloadingRegionIds.remove(regionKey);
        _downloadProgress.remove(regionKey);
      });
      return;
    }

    if (_isDownloaded(region, layer)) {
      // Supprimer le cache existant
      _deleteRegionCache(region, layer);
    }
  }

  Future<void> _deleteRegionCache(
    Shom10kRegion region,
    ShomOfflineLayer layer,
  ) async {
    final bytes = _cacheBytes(region, layer);
    final approxMo = bytes > 0 ? (bytes / (1024 * 1024)).round() : 20;
    final layerLabel = layer == ShomOfflineLayer.marine
        ? 'carte 1:10 000'
        : 'relief LiDAR';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text('Supprimer le cache $layerLabel ?'),
        content: Text(
          'Supprimer le cache $layerLabel pour ${region.name} '
          '(~$approxMo Mo) ?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      if (layer == ShomOfflineLayer.marine) {
        await ShomDownloadService.purgeMarineCacheForRegion(region);
      } else {
        await ShomDownloadService.deleteLidarCacheForRegion(region);
      }
      await _refreshCacheStatuses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cache supprimé pour ${region.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $error'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _downloadRegion(
    Shom10kRegion region,
    ShomOfflineLayer layer,
  ) async {
    final regionKey = '${region.id}_${layer.name}';

    try {
      await ShomDownloadService.downloadPlans(
        [
          ShomRegionDownloadPlan(
            region: region,
            downloadMarine: layer == ShomOfflineLayer.marine,
            downloadLidar: layer == ShomOfflineLayer.lidar,
          ),
        ],
        onProgress: (_, __, progress) {
          if (!mounted) return;
          setState(() {
            _downloadProgress[regionKey] = progress.percentageProgress / 100;
          });
        },
      );
      await _refreshCacheStatuses();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${region.name} téléchargé.'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $error'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingRegionIds.remove(regionKey);
          _downloadProgress.remove(regionKey);
        });
      }
    }
  }

  Widget _buildRegionList(ShomOfflineLayer layer) {
    final regions = _visibleRegions;

    if (regions.isEmpty) {
      return const Center(
        child: Text(
          'Aucune zone correspondante.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: regions.length,
      itemBuilder: (context, index) {
        final region = regions[index];
        final regionKey = '${region.id}_${layer.name}';
        final checked = _isDownloaded(region, layer);
        final downloading = _downloadingRegionIds.contains(regionKey);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: checked || downloading
                  ? Colors.blueAccent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: CheckboxListTile(
            value: checked || downloading,
            tristate: downloading,
            onChanged: (value) => _onToggle(region, layer, value),
            activeColor: layer == ShomOfflineLayer.marine
                ? Colors.blueAccent
                : Colors.tealAccent,
            title: Text(
              region.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${region.facade.label} · ${_statusLabel(region, layer)}',
              style: TextStyle(
                color: checked ? Colors.greenAccent : Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text('Stockage hors-ligne'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'Cartes 1:10 000'),
            Tab(text: 'Relief Lidar'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher un port ou une zone…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_downloadingRegionIds.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_downloadingRegionIds.length} téléchargement(s) en cours',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ..._downloadingRegionIds.map((regionKey) {
                    final progress = _downloadProgress[regionKey] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        backgroundColor: Colors.white12,
                        color: Colors.blueAccent,
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
          Expanded(child: _buildRegionList(_currentTabLayer)),
        ],
      ),
    );
  }
}
