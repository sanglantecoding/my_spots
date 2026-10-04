import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/marine_layer.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';
import 'package:my_spots/services/zone_download/shom_coverage_preflight.dart';

class ZoneConfig {
  final String name;
  final List<LayerType> layers;
  final String zoneType;

  const ZoneConfig({
    required this.name,
    required this.layers,
    required this.zoneType,
  });

  /// Couches par défaut avant le preflight de couverture SHOM.
  /// Utilise les zooms natifs du catalogue centralisé.
  static List<OfflineMapLayer> defaultLayersForBounds(LatLngBounds bounds) {
    // ✅ Lecture depuis le catalogue centralisé
    final layers = <OfflineMapLayer>[
      for (final ml in MarineLayerCatalog.downloadableLayers)
        OfflineMapLayer.create(
          layerType: ml.layerType!,
          minZoom: ml.minNativeZoom < 8 ? 8 : ml.minNativeZoom,
          maxZoom: ml.maxNativeZoom,
        ),
    ];

    // Ajoute un OfflineMapLayer par campagne LiDAR disponible dans la zone
    final lidarRegions = LidarRegionCatalog.regionsIntersecting(bounds);
    for (final region in lidarRegions) {
      for (final layerId in region.layerIds) {
        final isOccitanieFallback =
            region.name == 'Occitanie' &&
            (layerId == 'occitanie_2009' || layerId == 'occitanie_2011');

        layers.add(
          OfflineMapLayer.create(
            layerType: LayerType.lidarLitto3d,
            minZoom: 11,
            maxZoom: isOccitanieFallback ? 15 : 16,
            lidarLayerId: layerId,
          ),
        );
      }
    }

    return layers;
  }

  /// Résout les couches à télécharger pour une zone après preflight SHOM :
  /// seules les échelles qui couvrent réellement la zone sont créées.
  ///
  /// - SHOM injoignable (tous les sondages `null`) → fail-open : comportement
  ///   actuel (toutes les couches), pour ne jamais bloquer la création ;
  /// - aucune échelle marine couverte → seule la partie LiDAR est conservée
  ///   (l'appelant affichera un message si la liste finale est vide).
  static Future<List<OfflineMapLayer>> resolveLayersForBounds(
    LatLngBounds bounds, {
    ShomCoveragePreflight? preflight,
  }) async {
    final shouldClose = preflight == null;
    final pf = preflight ?? ShomCoveragePreflight();
    final fallback = defaultLayersForBounds(bounds);
    final layers = <OfflineMapLayer>[];

    try {
      // ✅ Parallélise les sondages pour toutes les couches téléchargeables
      final futures = MarineLayerCatalog.downloadableLayers.map((ml) async {
        final covered = await pf.covers(bounds, ml.wmtsLayerName);
        return (ml: ml, covered: covered);
      }).toList();

      final scaleResults = await Future.wait(futures);

      // Fail-open : SHOM totalement injoignable → comportement actuel.
      final allNull = scaleResults.every((r) => r.covered == null);
      if (allNull) {
        layers.addAll(
          fallback.where((l) => l.layerType != LayerType.lidarLitto3d),
        );
      } else {
        // Ajoute uniquement les couches couvertes
        for (final result in scaleResults) {
          if (result.covered == true) {
            final ml = result.ml;
            // Force minZoom à au moins 8 pour éviter le téléchargement des zooms 0-7
            final effectiveMinZoom = ml.minNativeZoom < 8
                ? 8
                : ml.minNativeZoom;
            layers.add(
              OfflineMapLayer.create(
                layerType: ml.layerType!,
                minZoom: effectiveMinZoom,
                maxZoom: ml.maxNativeZoom,
              ),
            );
          }
        }
      }
    } finally {
      // Ferme le client HTTP si on l'a créé nous-mêmes
      if (shouldClose) {
        pf.close();
      }
    }

    // LiDAR : inchangé (déjà filtré par catalogue régional).
    layers.addAll(fallback.where((l) => l.layerType == LayerType.lidarLitto3d));
    return layers;
  }
}

/// Callback type used by [_NewZoneSheet] to test name uniqueness.
///
/// Separated from [OfflineMapRepository] so the sheet remains unit-testable:
/// a test can inject a stub that always returns `false`, while production code
/// passes [_defaultNameExists] which reads from the singleton repository.
typedef NameUniquenessChecker = bool Function(String name);

/// Default uniqueness implementation — delegates to [OfflineMapRepository.instance].
/// Returns `false` when the repository is not yet initialised (app bootstrap not
/// complete) so we never block the user on a premature null dereference.
bool _defaultNameExists(String name) {
  return OfflineMapRepository.instance?.nameExists(name) ?? false;
}

/// Shows the zone-name + layer-selection bottom sheet.
///
/// Returns a [ZoneConfig] on confirmation, or `null` on cancel / backdrop dismiss.
/// An optional [checkNameExists] function can replace the default repository
/// lookup; if absent, the sheet uses [OfflineMapRepository.instance].
Future<ZoneConfig?> showNewZoneSheet(
  BuildContext context, {
  NameUniquenessChecker? checkNameExists,
}) {
  return showModalBottomSheet<ZoneConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _NewZoneSheet(checkNameExists: checkNameExists ?? _defaultNameExists),
  );
}

class _NewZoneSheet extends StatefulWidget {
  /// Repository-backed name-uniqueness check. Defaults to [_defaultNameExists]
  /// (reads [OfflineMapRepository.instance]).
  final NameUniquenessChecker checkNameExists;

  const _NewZoneSheet({required this.checkNameExists});

  @override
  State<_NewZoneSheet> createState() => _NewZoneSheetState();
}

class _NewZoneSheetState extends State<_NewZoneSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedZoneType = 'Rectangle';

  /// Non-null error message when the current name is already taken.
  /// Set by [_validateName] and cleared by [_onNameChanged].
  String? _duplicateError;

  @override
  void initState() {
    super.initState();
    // Clear the duplicate warning as soon as the user starts typing again.
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (_duplicateError != null) {
      setState(() => _duplicateError = null);
    }
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0D6999), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  /// Synchronous validator called by [FormState.validate()].
  ///
  /// 1. Checks that the name is non-empty.
  /// 2. Calls [widget.checkNameExists] to detect duplicates.
  ///    If the name already exists, stores the error in [_duplicateError]
  ///    and returns the user-facing message.
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Obligatoire';
    }
    if (widget.checkNameExists(value.trim().toLowerCase())) {
      _duplicateError =
          'Une zone porte déjà ce nom. Veuillez en choisir un autre.';
      return _duplicateError;
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // Layers are resolved later in the caller using
    // [ZoneConfig.defaultLayersForBounds] once the user has drawn the zone
    // bounds.  Passing an empty list here is intentional.
    Navigator.of(context).pop(
      ZoneConfig(
        name: _nameController.text.trim(),
        layers: const [],
        zoneType: _selectedZoneType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nom de la zone',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: _input('Ma zone', Icons.edit_location_alt_outlined),
                textCapitalization: TextCapitalization.words,
                validator: _validateName,
              ),
              const SizedBox(height: 12),
              const Text(
                'Type de zone',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ZoneTypeButton(
                      label: 'Rectangle',
                      icon: Icons.crop_free,
                      isSelected: _selectedZoneType == 'Rectangle',
                      onTap: () =>
                          setState(() => _selectedZoneType = 'Rectangle'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ZoneTypeButton(
                      label: 'Main levée',
                      icon: Icons.draw,
                      isSelected: _selectedZoneType == 'Main levée',
                      onTap: () =>
                          setState(() => _selectedZoneType = 'Main levée'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D6999).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0D6999).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFF0D6999).withValues(alpha: 0.8),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Les cartes marines (50K/25K/10K) et les donnees LiDAR '
                        'disponibles pour votre zone seront telechargees '
                        'automatiquement.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6999),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Suivant : Tracer la zone sur la carte',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton rectangulaire de sélection du mode de tracé.
/// État sélectionné : fond teinté + bordure épaisse + icône/texte colorés.
class _ZoneTypeButton extends StatelessWidget {
  const _ZoneTypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF0D6999);
    return Material(
      color: isSelected
          ? selectedColor.withValues(alpha: 0.25)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? selectedColor
                  : const Color(0xFF0D6999).withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? selectedColor : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
