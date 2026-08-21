import 'package:flutter/material.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/models/fishing_port.dart';
import 'package:my_spots/offline_management_screen.dart';
import 'package:my_spots/widgets/port_search_field.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SpeedUnit _selectedUnit = AppSettings.speedUnit;
  String? _selectedPortKey = AppSettings.selectedPortKey;
  bool _showWaypointNamesOnMap = AppSettings.showWaypointNamesOnMap;
  bool _showWaypointDateOnMap = AppSettings.showWaypointDateOnMap;
  DistanceUnit _distanceUnit = AppSettings.distanceUnit;
  double _labelFontSize = AppSettings.waypointLabelFontSize;
  bool _proximityAlarmEnabled = AppSettings.proximityAlarmEnabled;
  final TextEditingController _proximityXController = TextEditingController();
  final TextEditingController _proximityYController = TextEditingController();
  final TextEditingController _proximityZController = TextEditingController();
  bool _energySavingMode = AppSettings.energySavingMode;
  bool _showFishingWaypointsOnMap = AppSettings.showFishingWaypointsOnMap;
  bool _showMushroomWaypointsOnMap = AppSettings.showMushroomWaypointsOnMap;
  bool _showOtherWaypointsOnMap = AppSettings.showOtherWaypointsOnMap;
  bool _showSpeedOnMap = AppSettings.showSpeedOnMap;
  MapType _selectedMapType = AppSettings.mapType;

  @override
  void initState() {
    super.initState();
    _proximityXController.text = AppSettings.proximityDistanceX
        .round()
        .toString();
    _proximityYController.text = AppSettings.proximityDistanceY
        .round()
        .toString();
    _proximityZController.text = AppSettings.proximityDistanceZ
        .round()
        .toString();
  }

  @override
  void dispose() {
    _proximityXController.dispose();
    _proximityYController.dispose();
    _proximityZController.dispose();
    super.dispose();
  }

  Future<void> _exportAllData() async {
    try {
      // Créer le dictionnaire de données complètes
      final backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'waypoints': WaypointStore.waypoints.map((wp) => wp.toJson()).toList(),
        'settings': {
          'speedUnit': AppSettings.speedUnit.index,
          'selectedPortKey': AppSettings.selectedPortKey,
          'waypointsVisible': AppSettings.waypointsVisible,
          'showWaypointNamesOnMap': AppSettings.showWaypointNamesOnMap,
          'showWaypointDateOnMap': AppSettings.showWaypointDateOnMap,
          'distanceUnit': AppSettings.distanceUnit.index,
          'waypointLabelFontSize': AppSettings.waypointLabelFontSize,
          'mapType': AppSettings.mapType.index,
          'bathymetryOverlayEnabled': AppSettings.bathymetryOverlayEnabled,
          'bathymetryOverlayOpacity': AppSettings.bathymetryOverlayOpacity,
          'showSpeedOnMap': AppSettings.showSpeedOnMap,
          'proximityAlarmEnabled': AppSettings.proximityAlarmEnabled,
          'proximityDistanceX': AppSettings.proximityDistanceX,
          'proximityDistanceY': AppSettings.proximityDistanceY,
          'proximityDistanceZ': AppSettings.proximityDistanceZ,
          'showFishingWaypointsOnMap': AppSettings.showFishingWaypointsOnMap,
          'showMushroomWaypointsOnMap': AppSettings.showMushroomWaypointsOnMap,
          'energySavingMode': AppSettings.energySavingMode,
          'favoritePorts': AppSettings.favoritePorts
              .map((p) => {'name': p.name, 'url': p.url})
              .toList(),
        },
      };

      // Convertir en JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

      // Créer un fichier temporaire
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/my_spots_backup_$timestamp.json');
      await file.writeAsString(jsonString);

      // Partager le fichier
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Sauvegarde complète My Spots');

      // Nettoyer après 30 secondes
      Future.delayed(const Duration(seconds: 30), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sauvegarde exportée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'exportation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importAllData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null && file.bytes == null) return;

      String content;
      if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        content = String.fromCharCodes(file.bytes!);
      }

      final data = jsonDecode(content) as Map<String, dynamic>;

      // Validation des clés principales
      if (!data.containsKey('version') ||
          !data.containsKey('waypoints') ||
          !data.containsKey('settings')) {
        throw Exception('Fichier de sauvegarde incomplet ou corrompu');
      }

      // Vérifier la version
      if (data['version'] != '1.0') {
        throw Exception('Version de sauvegarde incompatible');
      }

      // Importer les waypoints avec validation
      final waypointsData = data['waypoints'] as List<dynamic>?;
      if (waypointsData == null) {
        throw Exception('Aucune donnée de waypoints trouvée');
      }

      final importedWaypoints = waypointsData
          .whereType<Map<String, dynamic>>()
          .map((wpData) => Waypoint.fromJson(wpData))
          .toList();

      // Remplacer les waypoints existants
      WaypointStore.waypoints.clear();
      WaypointStore.waypoints.addAll(importedWaypoints);
      await WaypointStore.save();

      // Importer les réglages avec null safety
      final settings = data['settings'] as Map<String, dynamic>? ?? {};

      // Valeurs par défaut sécurisées avec opérateur ??
      AppSettings.speedUnit =
          SpeedUnit.values[(settings['speedUnit'] as int?) ?? 1];
      AppSettings.selectedPortKey = settings['selectedPortKey'] as String?;
      AppSettings.waypointsVisible =
          settings['waypointsVisible'] as bool? ?? true;
      AppSettings.showWaypointNamesOnMap =
          settings['showWaypointNamesOnMap'] as bool? ?? true;
      AppSettings.showWaypointDateOnMap =
          settings['showWaypointDateOnMap'] as bool? ?? false;
      AppSettings.distanceUnit =
          DistanceUnit.values[(settings['distanceUnit'] as int?) ?? 0];
      AppSettings.waypointLabelFontSize =
          (settings['waypointLabelFontSize'] as num?)?.toDouble() ?? 15.0;
      AppSettings.mapType = MapType.values[(settings['mapType'] as int?) ?? 0];
      AppSettings.bathymetryOverlayEnabled =
          settings['bathymetryOverlayEnabled'] as bool? ?? false;
      AppSettings.bathymetryOverlayOpacity =
          ((settings['bathymetryOverlayOpacity'] as num?)?.toDouble() ?? 0.7)
              .clamp(0.0, 1.0);
      AppSettings.showSpeedOnMap = settings['showSpeedOnMap'] as bool? ?? false;
      AppSettings.proximityAlarmEnabled =
          settings['proximityAlarmEnabled'] as bool? ?? false;
      AppSettings.proximityDistanceX =
          (settings['proximityDistanceX'] as num?)?.toDouble() ?? 100.0;
      AppSettings.proximityDistanceY =
          (settings['proximityDistanceY'] as num?)?.toDouble() ?? 20.0;
      AppSettings.proximityDistanceZ =
          (settings['proximityDistanceZ'] as num?)?.toDouble() ?? 5.0;
      AppSettings.showFishingWaypointsOnMap =
          settings['showFishingWaypointsOnMap'] as bool? ?? true;
      AppSettings.showMushroomWaypointsOnMap =
          settings['showMushroomWaypointsOnMap'] as bool? ?? true;
      AppSettings.showOtherWaypointsOnMap =
          settings['showOtherWaypointsOnMap'] as bool? ?? true;
      AppSettings.energySavingMode =
          settings['energySavingMode'] as bool? ?? false;

      // Import des ports favoris avec validation
      final portsData = settings['favoritePorts'] as List<dynamic>?;
      if (portsData != null) {
        AppSettings.favoritePorts = portsData
            .whereType<Map<String, dynamic>>()
            .where(
              (pData) => pData.containsKey('name') && pData.containsKey('url'),
            )
            .map(
              (pData) => FishingPort.legacy(
                name: pData['name'] as String? ?? '',
                url: pData['url'] as String? ?? '',
              ),
            )
            .where((port) => port.name.isNotEmpty && port.url.isNotEmpty)
            .toList();
      } else {
        AppSettings.favoritePorts = [];
      }

      // Sauvegarder tous les réglages
      await AppSettings.saveSpeedUnit(AppSettings.speedUnit);
      await AppSettings.saveWaypointsVisibility(AppSettings.waypointsVisible);
      await AppSettings.saveWaypointCategoryVisibility(
        showFishing: AppSettings.showFishingWaypointsOnMap,
        showMushrooms: AppSettings.showMushroomWaypointsOnMap,
        showOther: AppSettings.showOtherWaypointsOnMap,
      );
      await AppSettings.saveDistanceUnit(AppSettings.distanceUnit);
      await AppSettings.saveWaypointLabelFontSize(
        AppSettings.waypointLabelFontSize,
      );
      await AppSettings.saveMapType(AppSettings.mapType);
      await AppSettings.saveBathymetryOverlayEnabled(
        AppSettings.bathymetryOverlayEnabled,
      );
      await AppSettings.saveBathymetryOverlayOpacity(
        AppSettings.bathymetryOverlayOpacity,
      );
      await AppSettings.saveSpeedOnMap(AppSettings.showSpeedOnMap);
      await AppSettings.saveProximityAlarmEnabled(
        AppSettings.proximityAlarmEnabled,
      );
      await AppSettings.saveProximityDistances(
        x: AppSettings.proximityDistanceX,
        y: AppSettings.proximityDistanceY,
        z: AppSettings.proximityDistanceZ,
      );
      await AppSettings.saveEnergySavingMode(AppSettings.energySavingMode);
      await AppSettings.saveFavoritePorts(AppSettings.favoritePorts);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${importedWaypoints.length} waypoints et tous les réglages importés',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Erreur : Le fichier de sauvegarde est corrompu ou incomplet.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _saveProximityDistances() async {
    final x = double.tryParse(_proximityXController.text) ?? 100.0;
    final y = double.tryParse(_proximityYController.text) ?? 20.0;
    final z = double.tryParse(_proximityZController.text) ?? 5.0;

    // Validation de la logique X > Y > Z
    if (y >= x) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erreur de logique : La zone Intermédiaire (Y) doit être plus petite que la zone Loin (X)',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (z >= y) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erreur de logique : La zone Proche (Z) doit être plus petite que la zone Intermédiaire (Y)',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    await AppSettings.saveProximityDistances(x: x, y: y, z: z);
    setState(() {
      _proximityXController.text = AppSettings.proximityDistanceX
          .round()
          .toString();
      _proximityYController.text = AppSettings.proximityDistanceY
          .round()
          .toString();
      _proximityZController.text = AppSettings.proximityDistanceZ
          .round()
          .toString();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Distances d\'alarme enregistrées avec succès'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PARAMÈTRES'),
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1929), Color(0xFF1A2F42)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const SizedBox(height: 16),
            const Text(
              'METEO PORT FAVORI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedPortKey,
                  hint: const Text(
                    'Sélectionner un port',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                  dropdownColor: const Color(0xFF1A2F42),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                    size: 32,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'Aucun (météo générale)',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    ...AppSettings.favoritePorts.map((port) {
                      return DropdownMenuItem<String>(
                        value: port.key,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.anchor,
                              color: Colors.blueAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(port.name),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (String? newValue) async {
                    setState(() {
                      _selectedPortKey = newValue;
                    });
                    await AppSettings.saveSelectedPort(newValue);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.manage_search, color: Colors.white70),
              title: const Text(
                'Gérer mes ports',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManagePortsScreen(),
                  ),
                );
                // Rafraîchir l'état après retour de l'écran de gestion
                setState(() {
                  _selectedPortKey = AppSettings.selectedPortKey;
                });
              },
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.speed, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'UNITÉ DE VITESSE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  RadioListTile<SpeedUnit>(
                    title: const Text(
                      'Nœuds (nds)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'Unité maritime standard',
                      style: TextStyle(color: Colors.white54),
                    ),
                    value: SpeedUnit.knots,
                    groupValue: _selectedUnit,
                    toggleable: true,
                    activeColor: Colors.blueAccent,
                    onChanged: (SpeedUnit? value) async {
                      if (value != null) {
                        setState(() {
                          _selectedUnit = value;
                        });
                        await AppSettings.saveSpeedUnit(value);
                      }
                    },
                  ),
                  const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  RadioListTile<SpeedUnit>(
                    title: const Text(
                      'Kilomètres/heure (km/h)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'Unité terrestre',
                      style: TextStyle(color: Colors.white54),
                    ),
                    value: SpeedUnit.kmh,
                    groupValue: _selectedUnit,
                    activeColor: Colors.blueAccent,
                    onChanged: (SpeedUnit? value) async {
                      if (value != null) {
                        setState(() {
                          _selectedUnit = value;
                        });
                        await AppSettings.saveSpeedUnit(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.map, color: Colors.blueAccent, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'TYPE DE CARTE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  RadioListTile<MapType>(
                    title: const Text(
                      'Standard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'OpenStreetMap classique',
                      style: TextStyle(color: Colors.white54),
                    ),
                    value: MapType.standard,
                    groupValue: _selectedMapType,
                    activeColor: Colors.blueAccent,
                    onChanged: (MapType? value) async {
                      if (value != null) {
                        setState(() {
                          _selectedMapType = value;
                        });
                        await AppSettings.saveMapType(value);
                      }
                    },
                  ),
                  const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  RadioListTile<MapType>(
                    title: const Text(
                      'Relief',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'OpenTopoMap - avec relief',
                      style: TextStyle(color: Colors.white54),
                    ),
                    value: MapType.relief,
                    groupValue: _selectedMapType,
                    activeColor: Colors.blueAccent,
                    onChanged: (MapType? value) async {
                      if (value != null) {
                        setState(() {
                          _selectedMapType = value;
                        });
                        await AppSettings.saveMapType(value);
                      }
                    },
                  ),
                  const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  RadioListTile<MapType>(
                    title: const Text(
                      'Randonnée',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'Thunderforest Outdoors',
                      style: TextStyle(color: Colors.white54),
                    ),
                    value: MapType.hiking,
                    groupValue: _selectedMapType,
                    activeColor: Colors.blueAccent,
                    onChanged: (MapType? value) async {
                      if (value != null) {
                        setState(() {
                          _selectedMapType = value;
                        });
                        await AppSettings.saveMapType(value);
                      }
                    },
                  ),
                  const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  RadioListTile<MapType>(
                    title: const Text(
                      'Carte Marine (SHOM)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'Assemblage RasterMarine SHOM (1:1 000 000 à 1:10 000)',
                      style: TextStyle(color: Colors.white54),
                    ),
                    value: MapType.marine,
                    groupValue: _selectedMapType,
                    activeColor: Colors.blueAccent,
                    onChanged: (MapType? value) async {
                      if (value != null) {
                        setState(() {
                          _selectedMapType = value;
                        });
                        await AppSettings.saveMapType(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: const Icon(Icons.storage, color: Colors.blueAccent),
                title: const Text(
                  'Gestion du stockage hors-ligne',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                subtitle: const Text(
                  'Télécharger ou supprimer les cartes 1:10 000 et le relief LiDAR',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OfflineManagementScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.place, color: Colors.orangeAccent, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'AFFICHAGE WAYPOINTS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orangeAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Afficher le nom des spots sur la carte',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: _showWaypointNamesOnMap,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (bool value) async {
                      setState(() {
                        _showWaypointNamesOnMap = value;
                      });
                      await AppSettings.saveWaypointMapDisplayOptions(
                        showNames: _showWaypointNamesOnMap,
                        showDates: _showWaypointDateOnMap,
                      );
                    },
                  ),
                  const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Afficher la date des spots sur la carte',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: _showWaypointDateOnMap,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (bool value) async {
                      setState(() {
                        _showWaypointDateOnMap = value;
                      });
                      await AppSettings.saveWaypointMapDisplayOptions(
                        showNames: _showWaypointNamesOnMap,
                        showDates: _showWaypointDateOnMap,
                      );
                    },
                  ),
                  const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Afficher les spots de Pêche',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: _showFishingWaypointsOnMap,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (bool value) async {
                      setState(() {
                        _showFishingWaypointsOnMap = value;
                      });
                      await AppSettings.saveWaypointCategoryVisibility(
                        showFishing: _showFishingWaypointsOnMap,
                        showMushrooms: _showMushroomWaypointsOnMap,
                        showOther: _showOtherWaypointsOnMap,
                      );
                    },
                  ),
                  const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Afficher les coins à Champignons',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: _showMushroomWaypointsOnMap,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (bool value) async {
                      setState(() {
                        _showMushroomWaypointsOnMap = value;
                      });
                      await AppSettings.saveWaypointCategoryVisibility(
                        showFishing: _showFishingWaypointsOnMap,
                        showMushrooms: _showMushroomWaypointsOnMap,
                        showOther: _showOtherWaypointsOnMap,
                      );
                    },
                  ),
                  const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Afficher les points "Autre"',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: _showOtherWaypointsOnMap,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (bool value) async {
                      setState(() {
                        _showOtherWaypointsOnMap = value;
                      });
                      await AppSettings.saveWaypointCategoryVisibility(
                        showFishing: _showFishingWaypointsOnMap,
                        showMushrooms: _showMushroomWaypointsOnMap,
                        showOther: _showOtherWaypointsOnMap,
                      );
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Afficher la vitesse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: _showSpeedOnMap,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (bool value) async {
                      setState(() {
                        _showSpeedOnMap = value;
                      });
                      await AppSettings.saveSpeedOnMap(value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'TAILLE DE LA POLICE (ÉTIQUETTES)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Taille des étiquettes sur la carte',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_labelFontSize.round()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _labelFontSize,
                    min: 10,
                    max: 20,
                    divisions: 10,
                    activeColor: Colors.blueAccent,
                    onChanged: (double value) async {
                      setState(() {
                        _labelFontSize = value;
                      });
                      await AppSettings.saveWaypointLabelFontSize(value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'ALARME SONORE DE PROXIMITÉ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Activer l\'alarme sonore',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: _proximityAlarmEnabled,
                    activeThumbColor: Colors.blueAccent,
                    onChanged: (bool value) async {
                      setState(() => _proximityAlarmEnabled = value);
                      await AppSettings.saveProximityAlarmEnabled(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Distances des zones (m)',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blueAccent,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Logique : X > Y > Z (Loin > Intermédiaire > Proche)',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _proximityXController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'X (Lent)',
                            hintText: '100',
                            border: OutlineInputBorder(),
                            helperText: 'Zone la plus éloignée',
                            helperStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          onSubmitted: (v) => _saveProximityDistances(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _proximityYController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Y (Double)',
                            hintText: '20',
                            border: OutlineInputBorder(),
                            helperText: 'Zone intermédiaire',
                            helperStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          onSubmitted: (v) => _saveProximityDistances(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _proximityZController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Z (Continu)',
                            hintText: '5',
                            border: OutlineInputBorder(),
                            helperText: 'Zone la plus proche',
                            helperStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          onSubmitted: (v) => _saveProximityDistances(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _saveProximityDistances,
                    icon: const Icon(
                      Icons.save,
                      color: Colors.blueAccent,
                      size: 20,
                    ),
                    label: const Text(
                      'Enregistrer les distances',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'UNITÉ DE DISTANCE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  RadioListTile<DistanceUnit>(
                    title: const Text(
                      'Mètres / Kilomètres',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'm jusqu\'à 1000 m, puis km',
                      style: TextStyle(color: Colors.white54),
                    ),
                    value: DistanceUnit.metric,
                    groupValue: _distanceUnit,
                    activeColor: Colors.blueAccent,
                    onChanged: (DistanceUnit? value) async {
                      if (value != null) {
                        setState(() {
                          _distanceUnit = value;
                        });
                        await AppSettings.saveDistanceUnit(value);
                      }
                    },
                  ),
                  const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  RadioListTile<DistanceUnit>(
                    title: const Text(
                      'Milles nautiques',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'nm (navigation maritime)',
                      style: TextStyle(color: Colors.white54),
                    ),
                    value: DistanceUnit.nautical,
                    groupValue: _distanceUnit,
                    activeColor: Colors.blueAccent,
                    onChanged: (DistanceUnit? value) async {
                      if (value != null) {
                        setState(() {
                          _distanceUnit = value;
                        });
                        await AppSettings.saveDistanceUnit(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'MODE ÉCONOMIE D\'ÉNERGIE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Mode économie d\'énergie',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Réduit la fréquence du GPS pour économiser la batterie\n(pratique quand le téléphone est dans la poche).',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                value: _energySavingMode,
                activeThumbColor: Colors.lightGreenAccent,
                onChanged: (bool value) async {
                  setState(() => _energySavingMode = value);
                  await AppSettings.saveEnergySavingMode(value);
                },
              ),
            ),
            const SizedBox(height: 32),

            // Section Sauvegarde Complète
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.backup, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'SAUVEGARDE COMPLÈTE',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Exportez ou importez tous vos waypoints et réglages en un seul fichier.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _exportAllData,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Exporter tout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _importAllData,
                          icon: const Icon(Icons.download),
                          label: const Text('Importer tout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blueAccent, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Les paramètres sont appliqués immédiatement',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManagePortsScreen extends StatefulWidget {
  const ManagePortsScreen({super.key});

  @override
  State<ManagePortsScreen> createState() => _ManagePortsScreenState();
}

class _ManagePortsScreenState extends State<ManagePortsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  late List<FishingPort> _ports;

  @override
  void initState() {
    super.initState();
    _ports = List<FishingPort>.from(AppSettings.getEffectiveFavoritePorts());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _savePorts() async {
    await AppSettings.saveFavoritePorts(_ports);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ports enregistrés'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _addPort() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (name.isEmpty || url.isEmpty) return;
    setState(() {
      _ports.add(FishingPort.legacy(name: name, url: url));
    });
    _nameController.clear();
    _urlController.clear();
    _savePorts();
  }

  void _removePort(int index) {
    final removedPort = _ports[index];
    setState(() {
      _ports.removeAt(index);
    });

    // Si le port supprimé était le port sélectionné, réinitialiser
    if (AppSettings.selectedPortKey == removedPort.key) {
      AppSettings.selectedPortKey = null;
      AppSettings.saveSelectedPort(null);
    }

    _savePorts();
  }

  void _editPort(int index) {
    final port = _ports[index];
    _nameController.text = port.name;
    _urlController.text = port.url;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F42),
        title: const Text(
          'Modifier le port',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PortSearchWidget(
              nameController: _nameController,
              urlController: _urlController,
              labelText: 'Nom du port',
              hintText: 'Rechercher un port...',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'URL météo marine',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _nameController.clear();
              _urlController.clear();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              final url = _urlController.text.trim();
              if (name.isEmpty || url.isEmpty) return;

              setState(() {
                _ports[index] = FishingPort.legacy(name: name, url: url);
              });

              _nameController.clear();
              _urlController.clear();
              Navigator.of(context).pop();
              _savePorts();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GÉRER MES PORTS'),
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1929), Color(0xFF1A2F42)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ajouter un port',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PortSearchWidget(
                    nameController: _nameController,
                    urlController: _urlController,
                    labelText: 'Nom du port',
                    hintText: 'Rechercher un port...',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'URL météo marine',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _addPort,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: _ports.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun port favori.\nAjoutez-en un ci-dessus.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _ports.length,
                      itemBuilder: (context, index) {
                        final port = _ports[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.anchor,
                            color: Colors.white70,
                          ),
                          title: Text(
                            port.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            port.url,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () => _editPort(index),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _removePort(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
