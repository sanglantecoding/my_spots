import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/models/lidar_region_bounds.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';
import 'package:my_spots/services/zone_download/shom_coverage_preflight.dart';

/// Returned by [showNewZoneSheet] when the user confirms the zone name.
///
/// The [layers] field is empty when returned from the sheet - it is resolved
/// later in the caller using [ZoneConfig.defaultLayersForBounds].
class ZoneConfig {
  final String name;
  final List<LayerType> layers;

  const ZoneConfig({required this.name, required this.layers});

  /// Creates a copy with the given [layers] attached.
  ZoneConfig withLayers(List<LayerType> layers) =>
      ZoneConfig(name: name, layers: layers);

  /// Default layer types for a zone covering [bounds].
  ///
  /// Marine layers (50K + 25K + 10K) are always included.  LiDAR overlays are
  /// included only when the bounds intersect a known LiDAR region (see
  /// [LidarRegionCatalog.regionsIntersecting]).
  /// /// For LiDAR, creates one [OfflineMapLayer] per available campaign with
  /// [OfflineMapLayer.lidarLayerId] set to the campaign ID.
  static List<OfflineMapLayer> defaultLayersForBounds(LatLngBounds bounds) {
    final layers = <OfflineMapLayer>[
      OfflineMapLayer.create(
        layerType: LayerType.marine50k,
        minZoom: 11, // Zoom natif min
        maxZoom: 14, // Zoom natif max
      ),
      OfflineMapLayer.create(
        layerType: LayerType.marine25k,
        minZoom: 12,
        maxZoom: 15,
      ),
      OfflineMapLayer.create(
        layerType: LayerType.marine10k,
        minZoom: 14,
        maxZoom: 16,
      ),
    ];

    // Ajoute un OfflineMapLayer par campagne LiDAR disponible dans la zone
    final lidarRegions = LidarRegionCatalog.regionsIntersecting(bounds);
    for (final region in lidarRegions) {
      for (final layerId in region.layerIds) {
        layers.add(
          OfflineMapLayer.create(
            layerType: LayerType.lidarLitto3d,
            minZoom: 0,
            maxZoom: 18,
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
    final pf = preflight ?? ShomCoveragePreflight();
    final fallback = defaultLayersForBounds(bounds);
    final layers = <OfflineMapLayer>[];

    const scales = [
      ('RASTER_MARINE_50_WMTS_3857', LayerType.marine50k, 11, 14),
      ('RASTER_MARINE_25_WMTS_3857', LayerType.marine25k, 12, 15),
      ('RASTER_MARINE_10_WMTS_3857', LayerType.marine10k, 14, 16),
    ];

    final results = <LayerType, bool?>{};
    for (final (url, type, zmin, zmax) in scales) {
      results[type] = await pf.covers(bounds, url);
      if (results[type] == true) {
        layers.add(
          OfflineMapLayer.create(layerType: type, minZoom: zmin, maxZoom: zmax),
        );
      }
    }

    // Fail-open : SHOM totalement injoignable → comportement actuel.
    if (results.values.every((v) => v == null)) {
      layers.addAll(
        fallback.where((l) => l.layerType != LayerType.lidarLitto3d),
      );
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
    if (widget.checkNameExists(value)) {
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
    Navigator.of(
      context,
    ).pop(ZoneConfig(name: _nameController.text.trim(), layers: const []));
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
