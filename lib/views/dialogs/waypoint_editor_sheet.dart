import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/gps_service.dart';
import 'package:my_spots/utils/gps_status_utils.dart';
import 'package:my_spots/widgets/satellite_status_dialog.dart';
import 'package:my_spots/controllers/gps_controller.dart';

class WaypointEditorOutcome {
  final Waypoint? waypoint;
  final bool deleted;
  const WaypointEditorOutcome._({
    required this.waypoint,
    required this.deleted,
  });
  const WaypointEditorOutcome.saved(Waypoint waypoint)
    : this._(waypoint: waypoint, deleted: false);
  const WaypointEditorOutcome.deleted() : this._(waypoint: null, deleted: true);
}

Future<WaypointEditorOutcome?> showWaypointEditorSheet({
  required BuildContext context,
  required String title,
  required IconData icon,
  required LatLng position,
  required String initialName,
  required WaypointCategory initialCategory,
  required String initialColorHex,
  required DateTime initialDate,
  required bool isEditing,
}) {
  return showModalBottomSheet<WaypointEditorOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _WaypointEditorSheet(
        title: title,
        icon: icon,
        position: position,
        initialName: initialName,
        initialCategory: initialCategory,
        initialColorHex: initialColorHex,
        initialDate: initialDate,
        isEditing: isEditing,
      );
    },
  );
}

class _WaypointEditorSheet extends StatefulWidget {
  final String title;
  final IconData icon;
  final LatLng position;
  final String initialName;
  final WaypointCategory initialCategory;
  final String initialColorHex;
  final DateTime initialDate;
  final bool isEditing;

  const _WaypointEditorSheet({
    required this.title,
    required this.icon,
    required this.position,
    required this.initialName,
    required this.initialCategory,
    required this.initialColorHex,
    required this.initialDate,
    required this.isEditing,
  });

  @override
  State<_WaypointEditorSheet> createState() => _WaypointEditorSheetState();
}

class _WaypointEditorSheetState extends State<_WaypointEditorSheet> {
  late WaypointCategory _category;
  late String _colorHex;
  late DateTime _createdAt;
  double? _currentAccuracy; // Précision GPS actuelle

  final Map<String, Color> _availableColors = const {
    'FFFFEB3B': Colors.yellow, // Jaune vif
    'FF4CAF50': Colors.green,
    'FF2196F3': Colors.blue,
    'FFFF9800': Colors.orange,
    'FFF44336': Colors.red, // Rouge en dernière position
  };

  static const List<String> _fishingSuggestions = [
    'Bonite',
    'Calamar',
    'Daurade',
    'Loup',
    'Maquereau',
    'Marbré',
    'Pagre',
    'Sar',
    'Seiche',
    'Thon',
  ];

  static const List<String> _mushroomSuggestions = [
    'Cèpes',
    'Chanterelles',
    'Girolles',
    'Morilles',
    'Pied de mouton',
    'Trompettes de la mort',
  ];

  static const List<String> _otherSuggestions = [
    'Voiture',
    'Parking',
    'Entrée',
    'Point de départ',
    'Base',
  ];

  late String _name;

  @override
  void initState() {
    super.initState();
    _name = widget.initialName;
    _category = widget.initialCategory;
    _colorHex = widget.initialColorHex;
    _createdAt = widget.initialDate;
    _updateCurrentAccuracy(); // Initialiser la précision
    // Forcer la couleur rouge pour la catégorie "Autre" avec "Voiture"
    if (_category == WaypointCategory.other &&
        _name.toLowerCase().contains('voiture') &&
        !widget.isEditing) {
      _colorHex = 'FFF44336'; // Rouge
    } else {
      _colorHex = widget.initialColorHex;
    }

    _createdAt = widget.initialDate;
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatDateShort(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _createdAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _createdAt.hour,
        _createdAt.minute,
        _createdAt.second,
      );
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 12),
            Text('SUPPRIMER', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Supprimer ce waypoint ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    Navigator.of(context).pop(const WaypointEditorOutcome.deleted());
  }

  void _save() async {
    final name = _name.trim();
    if (name.isEmpty) return;

    // Définir le seuil de sécurité (15 mètres)
    const double safetyThreshold = 15.0;

    try {
      // Obtenir la position actuelle la plus précise possible
      final currentPosition = await GpsController.instance.getCurrentPosition();

      if (currentPosition == null) {
        // Si impossible d'obtenir la position, continuer avec l'enregistrement
        debugPrint('Impossible d\'obtenir la position GPS');
        _createWaypoint(name);
        return;
      }

      // Rafraîchir la position une dernière fois pour être le plus précis possible
      await _updateCurrentAccuracy();

      // Vérifier la précision GPS pour l'alerte de sécurité
      final accuracy = currentPosition.accuracy;

      if (accuracy > safetyThreshold) {
        // Afficher l'alerte de sécurité
        _showSafetyAccuracyDialog(accuracy, name);
        return;
      }

      // Si la précision est acceptable, enregistrer directement
      _createWaypoint(name);
    } catch (e) {
      // Si impossible d'obtenir la position, continuer avec l'enregistrement
      debugPrint('Impossible d\'obtenir la précision GPS: $e');
      _createWaypoint(name);
    }
  }

  Future<void> _updateCurrentAccuracy() async {
    try {
      final position = await GpsController.instance.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _currentAccuracy = position.accuracy;
        });
      }
    } catch (e) {
      // Erreur silencieuse
    }
  }

  void _showSafetyAccuracyDialog(double accuracy, String name) {
    showDialog(
      context: context,
      barrierDismissible: false, // Empêcher la fermeture accidentelle
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('⚠️ Précision faible'),
            ],
          ),
          content: Text(
            'Votre précision actuelle est de ${accuracy.toStringAsFixed(1)}m. Le point risque d\'être mal placé sur la carte.\n\nVoulez-vous quand même créer ce waypoint ?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fermer la boîte de dialogue
              },
              child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fermer la boîte de dialogue
                _createWaypoint(name); // Forcer l'enregistrement
              },
              child: Text(
                'Créer quand même',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Obtient la couleur de précision GPS (utilise la logique unifiée)
  Color _getAccuracyColor() {
    return GpsService.getAccuracyColor(_currentAccuracy);
  }

  /// Obtient le texte de précision GPS (utilise la logique unifiée)
  String _getAccuracyText() {
    return GpsService.getAccuracyDetailedText(_currentAccuracy);
  }

  void _createWaypoint(String name) {
    final waypoint = Waypoint(
      name: name,
      latitude: widget.position.latitude,
      longitude: widget.position.longitude,
      createdAt: _createdAt,
      colorHex: _colorHex,
      category: _category,
      creationAccuracy: _currentAccuracy, // Enregistrement de la précision GPS
      gpsStatus: GpsStatusUtils.getGpsStatusLabel(
        _currentAccuracy,
      ), // Enregistrement du statut GPS
    );

    Navigator.of(context).pop(WaypointEditorOutcome.saved(waypoint));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Material(
                color: const Color(0xFF1A2F42),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(widget.icon, color: Colors.blueAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NOM',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Autocomplete<String>(
                              optionsBuilder: (TextEditingValue value) {
                                List<String> base;
                                if (_category == WaypointCategory.fishing) {
                                  base = _fishingSuggestions;
                                } else if (_category ==
                                    WaypointCategory.mushrooms) {
                                  base = _mushroomSuggestions;
                                } else {
                                  base = _otherSuggestions;
                                }
                                final query = value.text.trim().toLowerCase();
                                if (query.isEmpty) {
                                  return const Iterable<String>.empty();
                                }
                                return base.where(
                                  (s) => s.toLowerCase().contains(query),
                                );
                              },
                              onSelected: (selection) {
                                setState(() {
                                  _name = selection;
                                  // Si catégorie "Autre" et "Voiture" sélectionné, basculer sur Rouge
                                  if (_category == WaypointCategory.other &&
                                      selection.toLowerCase().contains(
                                        'voiture',
                                      )) {
                                    _colorHex = 'FFF44336'; // Rouge
                                  }
                                });
                              },
                              fieldViewBuilder:
                                  (
                                    BuildContext context,
                                    TextEditingController textController,
                                    FocusNode focusNode,
                                    VoidCallback onFieldSubmitted,
                                  ) {
                                    if (textController.text.isEmpty &&
                                        _name.isNotEmpty) {
                                      textController.text = _name;
                                      textController.selection =
                                          TextSelection.collapsed(
                                            offset: textController.text.length,
                                          );
                                    }

                                    final List<String> base;
                                    if (_category == WaypointCategory.fishing) {
                                      base = _fishingSuggestions;
                                    } else if (_category ==
                                        WaypointCategory.mushrooms) {
                                      base = _mushroomSuggestions;
                                    } else {
                                      base = _otherSuggestions;
                                    }
                                    final quick = base.take(6).toList();

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: quick
                                              .map(
                                                (label) => ActionChip(
                                                  label: Text(
                                                    label,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _name = label;
                                                      // Si catégorie "Autre" et "Voiture" sélectionné, basculer sur Rouge
                                                      if (_category ==
                                                              WaypointCategory
                                                                  .other &&
                                                          label
                                                              .toLowerCase()
                                                              .contains(
                                                                'voiture',
                                                              )) {
                                                        _colorHex =
                                                            'FFF44336'; // Rouge
                                                      }
                                                    });
                                                    textController.text = label;
                                                    textController.selection =
                                                        TextSelection.collapsed(
                                                          offset: label.length,
                                                        );
                                                  },
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                        const SizedBox(height: 8),
                                        // Indicateur de précision GPS
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.3,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                          ),
                                          child: GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    const SatelliteStatusDialog(),
                                              );
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.gps_fixed,
                                                  size: 16,
                                                  color: _getAccuracyColor(),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  _getAccuracyText(),
                                                  style: TextStyle(
                                                    color: _getAccuracyColor(),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.info_outline,
                                                  size: 12,
                                                  color: _getAccuracyColor()
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: textController,
                                          focusNode: focusNode,
                                          onChanged: (value) {
                                            setState(() {
                                              _name = value;
                                              // Si catégorie "Autre" et "Voiture" tapé, basculer sur Rouge
                                              if (_category ==
                                                      WaypointCategory.other &&
                                                  value.toLowerCase().contains(
                                                    'voiture',
                                                  )) {
                                                _colorHex = 'FFF44336'; // Rouge
                                              }
                                            });
                                          },
                                          onSubmitted: (_) =>
                                              onFieldSubmitted(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Colors.black26,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: Colors.white.withValues(
                                                  alpha: 0.2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                              optionsViewBuilder:
                                  (
                                    BuildContext context,
                                    AutocompleteOnSelected<String> onSelected,
                                    Iterable<String> options,
                                  ) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        color: const Color(0xFF1A2F42),
                                        elevation: 4,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 200,
                                          ),
                                          child: ListView(
                                            shrinkWrap: true,
                                            padding: EdgeInsets.zero,
                                            children: options
                                                .map(
                                                  (opt) => ListTile(
                                                    title: Text(
                                                      opt,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    onTap: () =>
                                                        onSelected(opt),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'CATÉGORIE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                ChoiceChip(
                                  label: const Text('Pêche'),
                                  avatar: const Icon(Icons.anchor, size: 18),
                                  selected:
                                      _category == WaypointCategory.fishing,
                                  onSelected: (s) {
                                    if (!s) return;
                                    setState(
                                      () =>
                                          _category = WaypointCategory.fishing,
                                    );
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Champignons'),
                                  avatar: const Icon(Icons.grass, size: 18),
                                  selected:
                                      _category == WaypointCategory.mushrooms,
                                  onSelected: (s) {
                                    if (!s) return;
                                    setState(
                                      () => _category =
                                          WaypointCategory.mushrooms,
                                    );
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Autre'),
                                  avatar: const Icon(Icons.category, size: 18),
                                  selected: _category == WaypointCategory.other,
                                  onSelected: (s) {
                                    if (!s) return;
                                    setState(
                                      () => _category = WaypointCategory.other,
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'DATE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _formatDateShort(_createdAt),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white54,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'COULEUR',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _availableColors.entries.map((entry) {
                                final isSelected = _colorHex == entry.key;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _colorHex = entry.key),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: entry.value,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'COORDONNÉES',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Lat: ${widget.position.latitude.toStringAsFixed(6)}°',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Text(
                                    'Lon: ${widget.position.longitude.toStringAsFixed(6)}°',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        children: [
                          if (widget.isEditing)
                            IconButton(
                              onPressed: _confirmDelete,
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              tooltip: 'Supprimer',
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Annuler',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Enregistrer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
