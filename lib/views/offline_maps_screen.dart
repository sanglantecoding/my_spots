import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/core/app_initialization_status.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';
import 'package:my_spots/services/zone_download/zone_download.dart';
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

  StreamSubscription<ZoneProgressEvent>? _progressSubscription;
  StreamSubscription<ZoneErrorEvent>? _errorSubscription;
  StreamSubscription<String>? _completionSubscription;

  _ListenerSubscription? _objectBoxReadySubscription;

  bool _isLoading = true;
  bool _hasError = false;
  late final ZoneDownloadService _zoneService;
  OfflineMapRepository? _offlineMapRepo;

  @override
  void initState() {
    super.initState();
    _zoneService = ZoneDownloadService.instance;

    // 1) Tentative immédiate (rapide si ObjectBox est déjà prêt).
    _tryLoadZones();

    // 2) Si ObjectBox n'est pas encore prêt, on s'abonne au notifier
    // pour recharger dès qu'il le devient (cas du timeout 5s dépassé).
    final status = AppInitializationStatus.instance;
    if (!status.objectBoxReady) {
      void listener() {
        if (status.objectBoxReady) {
          status.removeListener(listener);
          if (mounted) _tryLoadZones();
        }
      }

      status.addListener(listener);
      // Garde la référence pour cleanup dans dispose().
      _objectBoxReadySubscription = _ListenerSubscription(status, listener);
    }

    _progressSubscription = _zoneService.progressStream.listen((event) {
      if (!mounted) return;
      setState(() {
        _progress[event.zoneUuid] = event.progress;
        _activeLabels[event.zoneUuid] = event.layerLabel;
      });
    });

    _errorSubscription = _zoneService.errorStream.listen((event) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(event.message),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    });

    _completionSubscription = _zoneService.completionStream.listen((uuid) {
      if (!mounted) return;
      _refreshZone(uuid);
    });
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _errorSubscription?.cancel();
    _completionSubscription?.cancel();
    _objectBoxReadySubscription?.cancel();
    super.dispose();
  }

  /// Charge les zones UNIQUEMENT si le repository est disponible.
  /// Sinon, ne fait rien : le listener du notifier réessaiera plus tard.
  void _tryLoadZones() {
    final repo = OfflineMapRepository.instance;
    if (repo == null) return;
    _offlineMapRepo = repo;
    _loadZones();
  }

  Future<void> _refreshZone(String uuid) async {
    final repo = _offlineMapRepo;
    if (repo == null) return;

    final map = repo.findByUuid(uuid);
    if (map == null) {
      if (mounted) {
        setState(() {
          _zones.removeWhere((z) => z.uuid == uuid);
          _layers.remove(uuid);
          _zoneSizesBytes.remove(uuid);
          _downloadingUuids.remove(uuid);
          _progress.remove(uuid);
          _activeLabels.remove(uuid);
        });
      }
      return;
    }

    final layers = repo.findLayersForMap(map);
    final bytes = await MapTileCacheService.getZoneSizeBytes(uuid);

    if (!mounted) return;

    setState(() {
      final index = _zones.indexWhere((z) => z.uuid == uuid);
      if (index != -1) {
        _zones[index] = map;
      } else {
        _zones.add(map);
      }
      _layers[uuid] = layers;
      _zoneSizesBytes[uuid] = bytes;

      _downloadingUuids.remove(uuid);
      _progress.remove(uuid);
      _activeLabels.remove(uuid);
    });
  }

  Future<void> _loadZones() async {
    final repo = _offlineMapRepo;
    if (repo == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }
    final zones = repo.findAll();
    final layerMap = <String, List<OfflineMapLayer>>{};
    for (final z in zones) {
      layerMap[z.uuid] = repo.findLayersForMap(z);
    }

    if (!mounted) return;

    setState(() {
      _zones = zones;
      _layers.clear();
      _layers.addAll(layerMap);
      _isLoading = false;
      _hasError = false;
    });
    _computeZoneSizes();
  }

  Future<void> _computeZoneSizes() async {
    final results = <String, int?>{};
    final futures = <Future<void>>[];

    for (final zone in _zones) {
      futures.add(() async {
        final bytes = await MapTileCacheService.getZoneSizeBytes(zone.uuid);
        results[zone.uuid] = bytes;
      }());
    }

    await Future.wait(futures);

    if (!mounted) return;

    // 🟢 OPTIMISATION : Un seul setState() avec tous les résultats
    setState(() {
      _zoneSizesBytes.addAll(results);
    });
  }

  Future<void> _handleDownload(
    OfflineMap map,
    List<OfflineMapLayer> layers,
  ) async {
    if (_downloadingUuids.contains(map.uuid)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _downloadingUuids.add(map.uuid);
      _progress[map.uuid] = 0.0;
      _activeLabels[map.uuid] = '';
    });

    final zoneBounds = LatLngBounds(
      LatLng(map.southLat, map.westLng),
      LatLng(map.northLat, map.eastLng),
    );

    _zoneService.downloadZone(map: map, layers: layers, zoneBounds: zoneBounds);
  }

  Future<void> _handleCancel(String uuid) async {
    await _zoneService.cancelDownload(uuid);
    if (!mounted) return;
    _snack('Telechargement annule');
  }

  void _handlePause(String uuid) {
    final success = _zoneService.pauseDownload(uuid);
    if (success) {
      if (!mounted) return;
      setState(() {});
      _snack('Telechargement en pause');
    } else {
      _snack(
        'Pause impossible : telechargement deja termine ou inactif',
        isError: true,
      );
    }
  }

  void _handleResume(String uuid) {
    final success = _zoneService.resumeDownload(uuid);
    if (success) {
      if (!mounted) return;
      setState(() {});
      _snack('Telechargement repris');
    } else {
      _snack('Reprise impossible : telechargement non en pause', isError: true);
    }
  }

  Future<void> _handleDelete(OfflineMap map) async {
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

    // 🟢 Annulation avec vérification aggressive de l'arrêt
    await _zoneService.cancelAndAwaitEnd(map.uuid);

    // Vérification finale : le téléchargement est-il vraiment arrêté ?
    final stillDownloading = _zoneService.isDownloading(map.uuid);
    if (stillDownloading) {
      debugPrint(
        '[OfflineMapsScreen] WARNING: Suppression de ${map.uuid} alors que '
        'le téléchargement est toujours actif. Tentative d\'arrêt forcé.',
      );

      // Tentative d'arrêt forcé si le timeout initial n'a pas suffi
      final stopped = await _zoneService.forceStopDownload(map.uuid);

      if (!stopped) {
        debugPrint(
          '[OfflineMapsScreen] CRITICAL: Impossible d\'arrêter le téléchargement '
          '${map.uuid} après arrêt forcé. Suppression annulée.',
        );

        if (mounted) {
          _snack(
            'Suppression impossible : le téléchargement est toujours actif',
            isError: true,
          );
        }

        // IMPORTANT : ne surtout pas supprimer FMTC/ObjectBox
        return;
      }
    }

    await MapTileCacheService.deleteStoresForZone(map.uuid);
    _offlineMapRepo!.deleteByUuid(map.uuid);

    _zoneService.clearZoneHistory(map.uuid);

    if (!mounted) return;
    setState(() {
      _zones.removeWhere((z) => z.uuid == map.uuid);
      _layers.remove(map.uuid);
      _zoneSizesBytes.remove(map.uuid);
      _downloadingUuids.remove(map.uuid);
      _progress.remove(map.uuid);
      _activeLabels.remove(map.uuid);
    });
    _snack('Zone supprimee');
  }

  /// Si hors-ligne, affiche un dialog proposant de passer en ligne (comme MapScreen).
  Future<void> _handleCreateZone() async {
    if (!AppSettings.offlineModeEnabled) {
      _showNewZoneSheet();
      return;
    }

    final switchOnline = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mode hors-ligne actif',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: const Text(
          'La création d\'une zone hors-ligne nécessite une connexion internet '
          '(téléchargement des tuiles SHOM). Passez en mode en ligne pour '
          'continuer.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Passer en ligne',
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (switchOnline != true) return;
    await AppSettings.saveOfflineMode(false);
    if (!mounted) return;
    _showNewZoneSheet();
  }

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

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_hasError || _offlineMapRepo == null) {
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

  Widget _buildCreateZoneButton() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: const BoxDecoration(
      color: Color(0xFF0D1B2A),
      border: Border(bottom: BorderSide(color: Color(0xFF1E3A5F), width: 1)),
    ),
    child: ElevatedButton.icon(
      onPressed: _handleCreateZone,
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

        final isDownloading =
            _zoneService.isDownloading(map.uuid) ||
            _downloadingUuids.contains(map.uuid);
        final isPaused = _zoneService.isPaused(map.uuid);

        final activeLabel = _activeLabels[map.uuid] ?? '';
        final sizeBytes = _zoneSizesBytes[map.uuid];

        return ZoneListTile(
          key: ValueKey(map.uuid),
          map: map,
          layers: layers,
          progress: progress,
          isDownloading: isDownloading,
          isPaused: isPaused,
          activeLayerLabel: activeLabel,
          totalSizeBytes: sizeBytes,
          onDownload: () => _handleDownload(map, layers),
          onCancel: () => _handleCancel(map.uuid),
          onPause: () => _handlePause(map.uuid),
          onResume: () => _handleResume(map.uuid),
          onDelete: () => _handleDelete(map),
        );
      },
    ),
  );
}

/// Petit wrapper pour pouvoir cancel() un addListener manuel.
class _ListenerSubscription {
  _ListenerSubscription(this._notifier, this._listener);
  final Listenable _notifier;
  final VoidCallback _listener;
  void cancel() => _notifier.removeListener(_listener);
}
