import 'package:flutter/material.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';
import 'dart:io';
import 'dart:async';

class WaypointExportScreen extends StatefulWidget {
  const WaypointExportScreen({super.key});

  @override
  State<WaypointExportScreen> createState() => _WaypointExportScreenState();
}

class _WaypointExportScreenState extends State<WaypointExportScreen> {
  final Map<int, bool> _selectedWaypoints = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    // Initialiser tous les waypoints comme non sélectionnés
    for (int i = 0; i < WaypointStore.waypoints.length; i++) {
      _selectedWaypoints[i] = false;
    }
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      for (int i = 0; i < WaypointStore.waypoints.length; i++) {
        _selectedWaypoints[i] = _selectAll;
      }
    });
  }

  void _toggleWaypoint(int index) {
    setState(() {
      _selectedWaypoints[index] = !_selectedWaypoints[index]!;
      // Mettre à jour l'état "Tout sélectionner"
      _selectAll = _selectedWaypoints.values.every((selected) => selected);
    });
  }

  int get _selectedCount {
    return _selectedWaypoints.values.where((selected) => selected).length;
  }

  String _generateGPX() {
    final selectedIndices = _selectedWaypoints.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedIndices.isEmpty) return '';

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'gpx',
      nest: () {
        builder.attribute('version', '1.1');
        builder.attribute('creator', 'MySpots');
        builder.attribute('xmlns', 'http://www.topografix.com/GPX/1/1');
        builder.attribute(
          'xmlns:xsi',
          'http://www.w3.org/2001/XMLSchema-instance',
        );
        builder.attribute(
          'xsi:schemaLocation',
          'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd',
        );

        for (final index in selectedIndices) {
          final waypoint = WaypointStore.waypoints[index];
          builder.element(
            'wpt',
            nest: () {
              builder.attribute('lat', waypoint.latitude.toStringAsFixed(6));
              builder.attribute('lon', waypoint.longitude.toStringAsFixed(6));

              builder.element('name', nest: waypoint.name);

              builder.element(
                'time',
                nest: waypoint.createdAt.toIso8601String(),
              );

              builder.element(
                'sym',
                nest: waypoint.category == WaypointCategory.fishing
                    ? 'Fishing'
                    : waypoint.category == WaypointCategory.mushrooms
                    ? 'Mushrooms'
                    : 'Other',
              );

              // Ajout du statut GPS dans les extensions GPX
              builder.element(
                'extensions',
                nest: () {
                  builder.element(
                    'gps-status',
                    nest: waypoint.gpsStatus ?? 'Inconnu',
                  );
                },
              );
            },
          );
        }
      },
    );

    final document = builder.buildDocument();
    return document.toXmlString(pretty: true);
  }

  Future<void> _exportGPX() async {
    if (_selectedCount == 0) return;

    try {
      final gpxContent = _generateGPX();
      if (gpxContent.isEmpty) return;

      // Créer un fichier temporaire
      final directory = await getTemporaryDirectory();
      final fileName = 'waypoints_${DateTime.now().millisecondsSinceEpoch}.gpx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(gpxContent);

      // Partager le fichier
      await Share.shareXFiles(
        [XFile(file.path, name: fileName, mimeType: 'application/gpx+xml')],
        subject: 'Waypoints MySpots',
        text: '$_selectedCount waypoint(s) de MySpots',
      );

      // Nettoyer le fichier temporaire après un délai
      Timer(const Duration(seconds: 30), () {
        if (file.existsSync()) {
          file.delete();
        }
      });
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

  Future<void> _importGPX() async {
    try {
      // Délai pour laisser l'interface se stabiliser
      await Future.delayed(const Duration(milliseconds: 100));

      // Utiliser FileType.any pour éviter que les fichiers soient grisés
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      // Vérifier manuellement l'extension du fichier
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name.toLowerCase();
        if (!fileName.endsWith('.gpx') && !fileName.endsWith('.xml')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Veuillez sélectionner un fichier .gpx ou .xml'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // Essayer de récupérer le contenu depuis le chemin d'abord
      String content;
      if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else if (file.bytes != null) {
        // Fallback: utiliser les octets si le chemin n'est pas disponible
        content = String.fromCharCodes(file.bytes!);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de lire le fichier sélectionné'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final document = XmlDocument.parse(content);
      int importedCount = 0;
      int duplicateCount = 0;

      // Parser les waypoints
      final wptElements = document.findAllElements('wpt');
      for (final wpt in wptElements) {
        try {
          final lat = double.parse(wpt.getAttribute('lat')!);
          final lon = double.parse(wpt.getAttribute('lon')!);

          // Nettoyer le nom avec trim()
          final name =
              (wpt.findElements('name').firstOrNull?.innerText ??
                      'Waypoint Importé')
                  .trim();

          // Vérifier si le point existe déjà (avec tolérance de 5 décimales)
          final isDuplicate = WaypointStore.waypoints.any((existingPoint) {
            // Comparaison avec tolérance de 5 décimales (~1.1m de précision)
            final latDiff = (existingPoint.latitude - lat).abs();
            final lonDiff = (existingPoint.longitude - lon).abs();
            return latDiff < 0.00001 && lonDiff < 0.00001;
          });

          if (isDuplicate) {
            duplicateCount++;
            continue; // Ignorer les doublons
          }

          // Récupérer la date si disponible, sinon utiliser maintenant
          String timeStr =
              wpt.findElements('time').firstOrNull?.innerText ??
              DateTime.now().toIso8601String();
          final time = DateTime.tryParse(timeStr) ?? DateTime.now();

          // Nettoyer le symbole avec trim()
          final sym = (wpt.findElements('sym').firstOrNull?.innerText ?? '')
              .trim();

          // Déterminer la catégorie avec logique améliorée
          WaypointCategory category;
          final symLower = sym.toLowerCase();

          if (symLower.isEmpty) {
            // Si symbole vide -> Autre par défaut
            category = WaypointCategory.other;
          } else if (symLower.contains('mushroom') ||
              symLower.contains('champignon')) {
            category = WaypointCategory.mushrooms;
          } else if (symLower.contains('fishing') ||
              symLower.contains('pêche') ||
              symLower.contains('peche')) {
            category = WaypointCategory.fishing;
          } else if (symLower.contains('other') || symLower.contains('autre')) {
            category = WaypointCategory.other;
          } else {
            // Par défaut si aucune des conditions ci-dessus -> Autre
            category = WaypointCategory.other;
          }

          // Déterminer la couleur depuis le GPX ou utiliser orange par défaut
          String colorHex =
              'FFFF9800'; // Orange par défaut pour les imports GPX

          // Essayer de récupérer la couleur depuis les balises GPX si disponibles
          final colorElement = wpt
              .findElements('extensions')
              .firstOrNull
              ?.findElements('color')
              .firstOrNull;
          if (colorElement != null) {
            final colorValue = colorElement.innerText.trim();
            if (colorValue.isNotEmpty &&
                RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(colorValue)) {
              colorHex = colorValue.startsWith('FF')
                  ? colorValue
                  : 'FF$colorValue';
            }
          } else {
            // Essayer de récupérer depuis la balise desc si elle contient des infos de couleur
            final descElement = wpt.findElements('desc').firstOrNull;
            if (descElement != null) {
              final descText = descElement.innerText.toLowerCase();
              // Chercher des patterns de couleur dans la description
              if (descText.contains('red') || descText.contains('rouge')) {
                colorHex = 'FFF44336';
              } else if (descText.contains('green') ||
                  descText.contains('vert')) {
                colorHex = 'FF4CAF50';
              } else if (descText.contains('blue') ||
                  descText.contains('bleu')) {
                colorHex = 'FF2196F3';
              } else if (descText.contains('yellow') ||
                  descText.contains('jaune')) {
                colorHex = 'FFFFEB3B';
              }
              // Sinon garde l'orange par défaut
            }
          }

          // Récupérer le statut GPS depuis les extensions GPX
          String? gpsStatus;
          final gpsStatusElement = wpt
              .findElements('extensions')
              .firstOrNull
              ?.findElements('gps-status')
              .firstOrNull;
          if (gpsStatusElement != null) {
            gpsStatus = gpsStatusElement.innerText.trim();
            if (gpsStatus.isEmpty) gpsStatus = null;
          }

          // Pour les imports GPX, forcer le statut à "Inconnu" car on ne connaît pas la précision d'origine
          gpsStatus ??= 'Inconnu';

          // Créer le waypoint
          final waypoint = Waypoint(
            name: name,
            latitude: lat,
            longitude: lon,
            createdAt: time,
            category: category,
            colorHex: colorHex,
            gpsStatus:
                gpsStatus, // Import du statut GPS avec "Inconnu" par défaut
          );

          // Ajouter au store
          WaypointStore.waypoints.add(waypoint);
          importedCount++;
        } catch (e) {
          // Ignorer les waypoints invalides et continuer
          continue;
        }
      }

      if (importedCount > 0 || duplicateCount > 0) {
        await WaypointStore.save();
        setState(() {}); // Mettre à jour l'interface

        // Notifier l'écran précédent que des waypoints ont été importés
        if (mounted) {
          Navigator.pop(
            context,
            true,
          ); // Retourner true pour indiquer une importation réussie

          String message;
          Color backgroundColor;

          if (importedCount > 0 && duplicateCount > 0) {
            message =
                '$importedCount nouveau(x) point(s) ajouté(s), $duplicateCount doublon(s) ignoré(s)';
            backgroundColor = Colors.green;
          } else if (importedCount > 0) {
            message =
                '$importedCount nouveau(x) point(s) ajouté(s) avec succès';
            backgroundColor = Colors.green;
          } else {
            message =
                '$duplicateCount doublon(s) ignoré(s), aucun nouveau point';
            backgroundColor = Colors.orange;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: backgroundColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun waypoint valide trouvé dans le fichier'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'importation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        title: Text('EXPORTER/IMPORTER ($_selectedCount)'),
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        actions: [
          IconButton(
            icon: Icon(_selectAll ? Icons.clear_all : Icons.select_all),
            onPressed: _toggleSelectAll,
            tooltip: _selectAll ? 'Tout désélectionner' : 'Tout sélectionner',
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _importGPX,
            tooltip: 'Importer des waypoints',
          ),
        ],
      ),
      body: WaypointStore.waypoints.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.white38),
                  SizedBox(height: 16),
                  Text(
                    'Aucun waypoint à exporter',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Importez des waypoints depuis un fichier GPX',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: WaypointStore.waypoints.length,
              itemBuilder: (context, index) {
                final waypoint = WaypointStore.waypoints[index];
                final isSelected = _selectedWaypoints[index] ?? false;

                return Card(
                  color: const Color(0xFF1A2F42),
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Colors.blueAccent : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) => _toggleWaypoint(index),
                    title: Text(
                      waypoint.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${waypoint.latitude.toStringAsFixed(6)}, ${waypoint.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(waypoint.createdAt),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    secondary: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: waypoint.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    activeColor: Colors.blueAccent,
                    checkColor: Colors.white,
                  ),
                );
              },
            ),
      floatingActionButton: _selectedCount > 0
          ? FloatingActionButton.extended(
              onPressed: _exportGPX,
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.share),
              label: Text('EXPORTER ($_selectedCount)'),
            )
          : null,
    );
  }

  String _formatDate(DateTime date) {
    return 'Créé le ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
