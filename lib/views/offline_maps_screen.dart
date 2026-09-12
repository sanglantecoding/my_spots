import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';
import 'package:my_spots/services/zone_download_service.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/views/map_screen.dart';
import 'package:my_spots/views/widgets/offline_maps/zone_list_tile.dart';

/// Ecran de gestion des zones cartographiques hors-ligne.
class OfflineMapsScreen extends StatefulWidget {
  const OfflineMapsScreen({super.key});
  @override
  State<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends State<OfflineMapsScreen> {
  List<OfflineMap> _zones = [];
  final Map<String, List<OfflineMapLayer>> _layers = {};
  final Map<String, double> _progress = {};
  final Map<String, int?> _zoneSizesBytes = {};
  final Set<String> _downloadingUuids = {};
  final Map<String, String> _activeLabels = {};
  bool _isLoading = true;
  bool _hasError = false;

  late final ZoneDownloadService _zoneService;
  OfflineMapRepository? _offlineMapRepo;

  @override
  void initState() {
    super.initState();
    _offlineMapRepo = OfflineMapRepository.instance;
    _zoneService = ZoneDownloadService(
      repository: _offlineMapRepo ?? _FailRepo(),
    );
    _loadZones();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadZones() async {
    final repo = _offlineMapRepo;
    if (repo == null) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      return;
    }
    final zones = repo.findAll();
    final layerMap = <String, List<OfflineMapLayer>>{};
    for (final z in zones) {
      layerMap[z.uuid] = repo.findLayersForMap(z);
    }
    if (mounted) {
      setState(() {
        _zones = zones;
        _layers.clear();
        _layers.addAll(layerMap);
        _isLoading = false;
        _hasError = false;
      });
    }
    _computeZoneSizes();
  }

  Future<void> _computeZoneSizes() async {
    for (final zone in _zones) {
      final bytes = await MapTileCacheService.getZoneSizeBytes(zone.uuid);
      if (!mounted) return;
      setState(() => _zoneSizesBytes[zone.uuid] = bytes);
    }
  }

  Future<void> _handleDownload(
    OfflineMap map,
    List<OfflineMapLayer> layers,
  ) async {
    debugPrint(
      '[UI][${map.uuid}] _handleDownload ENTER _downloadingUuids=${_downloadingUuids.toList()}',
    );
    if (_downloadingUuids.contains(map.uuid)) {
      debugPrint('[UI][${map.uuid}] _handleDownload already in set, EXIT');
      return;
    }
    setState(() {
      _downloadingUuids.add(map.uuid);
      _progress[map.uuid] = 0.0;
      _activeLabels[map.uuid] = '';
    });

    debugPrint(
      '🚨 [DEBUG] Bounds sauvegardés dans OfflineMap: N:${map.northLat}, S:${map.southLat}, E:${map.eastLng}, W:${map.westLng}',
    );

    // Reconstruct the zone bounds from the persisted OfflineMap coordinates.
    // This ensures _layerUrl() selects the correct Litto3D dataset
    // (via LidarRegionCatalog / Litto3DCatalog) during "Mettre à jour la zone".
    final zoneBounds = LatLngBounds(
      LatLng(map.southLat, map.westLng),
      LatLng(map.northLat, map.eastLng),
    );
    _zoneService
        .downloadZone(
          map: map,
          layers: layers,
          zoneBounds: zoneBounds,
          onProgress: ({required double progress, required String layerLabel}) {
            if (!mounted) return;
            setState(() {
              _progress[map.uuid] = progress;
              _activeLabels[map.uuid] = layerLabel;
            });
          },
          onError: (String message) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 5),
              ),
            );
          },
        )
        .whenComplete(() {
          if (!mounted) return;
          _loadZones().then((_) {
            if (!mounted) return;
            setState(() {
              _downloadingUuids.remove(map.uuid);
              _progress.remove(map.uuid);
              _activeLabels.remove(map.uuid);
            });
          });
        });
  }

  Future<void> _handleCancel(String uuid) async {
    await _zoneService.cancelDownload(uuid);
    if (!mounted) return;
    setState(() => _downloadingUuids.remove(uuid));
    _loadZones();
    _snack('Telechargement annule');
  }

  void _handlePause(String uuid) {
    _zoneService.pauseDownload(uuid);
    _snack('Telechargement en pause');
  }

  void _handleResume(OfflineMap map, List<OfflineMapLayer> layers) {
    debugPrint(
      '[UI][${map.uuid}] _handleResume ENTER map.status=${map.status.name}',
    );
    debugPrint(
      '[UI][${map.uuid}] _handleResume calling _handleDownload (new downloadZone attempt)',
    );
    _handleDownload(map, layers);
  }

  Future<void> _handleDelete(OfflineMap map) async {
    debugPrint(
      '[DELETE][${map.uuid}] START _zoneService=${_zoneService.hashCode}',
    );
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        title: const Text(
          'Supprimer la zone ?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Supprimer "${map.name}" supprimera aussi les tuiles FMTC et l\'enregistrement dans la base de donnees.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'SUPPRIMER',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    debugPrint('[DELETE][${map.uuid}] CANCEL DOWNLOAD START');
    await _zoneService.cancelDownload(map.uuid);
    debugPrint('[DELETE][${map.uuid}] CANCEL DOWNLOAD DONE');
    debugPrint('[DELETE][${map.uuid}] DELETE STORES START');
    await MapTileCacheService.deleteStoresForZone(map.uuid);
    debugPrint('[DELETE][${map.uuid}] DELETE STORES DONE');
    _offlineMapRepo!.deleteByUuid(map.uuid);
    debugPrint('[DELETE][${map.uuid}] OBJECTBOX DELETE DONE');
    await _loadZones();
    debugPrint('[DELETE][${map.uuid}] LOAD ZONES DONE _zones.keys (svc)');
    debugPrint('[DELETE][${map.uuid}] END');
    _snack('Zone supprimee');
  }

  /// Navigates immediately to the map screen. The map will open the
  /// zone-name sheet right after the first frame renders (via
  /// [MapScreen.triggerZoneCreation]), then enter zone-edit mode on
  /// confirmation.
  ///
  /// The current [_zoneService] instance is forwarded to [MapScreen] so
  /// the zone-creation flow on the map side uses the same
  /// [ZoneDownloadService] as the one tracking the lifecycle of all
  /// zones here (downloads, cancellations, resumes, run counters).
  void _showNewZoneSheet() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            MapScreen(triggerZoneCreation: true, zoneService: _zoneService),
      ),
    );
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1E3A5F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Zones hors-ligne'),
      backgroundColor: const Color(0xFF0D1B2A),
      foregroundColor: Colors.white,
    ),
    backgroundColor: const Color(0xFF1B2838),
    body: _buildBody(),
  );

  /// Layout principal : bouton "Creer une zone" fixe en haut, liste
  /// (ou etat vide / degrade) dans la zone defilable en dessous.
  /// Le bouton reste visible que la liste soit vide ou non.
  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_hasError || _offlineMapRepo == null) {
      // En mode degrade, on garde quand meme le bouton pour permettre a
      // l'utilisateur d'essayer ulterieurement.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCreateZoneButton(),
          Expanded(child: _buildDegraded()),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCreateZoneButton(),
        Expanded(child: _zones.isEmpty ? _buildEmpty() : _buildList()),
      ],
    );
  }

  /// Bouton "Creer une zone" fixe en haut de l'ecran, sous l'AppBar.
  /// Toujours visible, independamment du nombre de zones deja creees.
  Widget _buildCreateZoneButton() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: const BoxDecoration(
      color: Color(0xFF0D1B2A),
      border: Border(bottom: BorderSide(color: Color(0xFF1E3A5F), width: 1)),
    ),
    child: ElevatedButton.icon(
      onPressed: _showNewZoneSheet,
      icon: const Icon(Icons.add),
      label: const Text('Creer une zone'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _buildDegraded() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Base de donnees indisponible',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Impossible d\'acceder a ObjectBox.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadZones, child: const Text('Reessayer')),
        ],
      ),
    ),
  );

  /// Etat vide discret : aucun asset lourd, juste un message. Le bouton
  /// de creation reste visible au-dessus (gere par [_buildBody]).
  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.map_outlined,
            color: Colors.white.withValues(alpha: 0.3),
            size: 64,
          ),
          const SizedBox(height: 12),
          const Text(
            'Aucune zone enregistree',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Utilisez le bouton ci-dessus pour en creer une.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildList() => RefreshIndicator(
    onRefresh: _loadZones,
    color: Colors.blueAccent,
    child: ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: _zones.length,
      itemBuilder: (context, index) {
        final map = _zones[index];
        final layers = _layers[map.uuid] ?? [];
        final progress = _progress[map.uuid] ?? 0.0;
        final isDownloading = _downloadingUuids.contains(map.uuid);
        final activeLabel = _activeLabels[map.uuid] ?? '';
        final sizeBytes = _zoneSizesBytes[map.uuid];
        return ZoneListTile(
          key: ValueKey(map.uuid),
          map: map,
          layers: layers,
          progress: progress,
          isDownloading: isDownloading,
          activeLayerLabel: activeLabel,
          totalSizeBytes: sizeBytes,
          onDownload: () => _handleDownload(map, layers),
          onCancel: () => _handleCancel(map.uuid),
          onPause: () => _handlePause(map.uuid),
          onResume: () => _handleResume(map, layers),
          onDelete: () => _handleDelete(map),
        );
      },
    ),
  );
}

/// No-op repository for graceful degradation when ObjectBox is unavailable.
class _FailRepo implements MapLayerRepository {
  @override
  OfflineMap? findByUuid(String uuid) => null;
  @override
  OfflineMapLayer? findLayerById(int id) => null;
  @override
  void save(OfflineMap map) {}
  @override
  void saveLayer(OfflineMap map, OfflineMapLayer layer) {}
}
