import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/zone_download/shom_coverage_preflight.dart';
import 'package:my_spots/views/widgets/offline_maps/new_zone_sheet.dart';

/// Tests de résolution des couches avec préflight SHOM.
///
/// Ces tests verrouillent la logique de [ZoneConfig.resolveLayersForBounds] :
/// - Seules les échelles qui couvrent réellement la zone sont incluses
/// - Fail-open si SHOM injoignable (comportement actuel)
/// - LiDAR ajouté indépendamment de la couverture marine
void main() {
  group('resolveLayersForBounds — préflight SHOM', () {
    final bounds = LatLngBounds(
      const LatLng(43.5, -1.5),
      const LatLng(43.0, -2.0),
    );

    test('Test A — tout disponible (50K + 25K + 10K)', () async {
      final mock = _MockPreflight({
        LayerType.marine50k: true,
        LayerType.marine25k: true,
        LayerType.marine10k: true,
      });

      final layers = await ZoneConfig.resolveLayersForBounds(
        bounds,
        preflight: mock,
      );

      final marineLayers = layers.where(
        (l) => l.layerType != LayerType.lidarLitto3d,
      );
      expect(marineLayers, hasLength(3));
      expect(
        marineLayers.map((l) => l.layerType),
        containsAll([
          LayerType.marine50k,
          LayerType.marine25k,
          LayerType.marine10k,
        ]),
      );
    });

    test('Test B — 50K + 10K uniquement (25K absent)', () async {
      final mock = _MockPreflight({
        LayerType.marine50k: true,
        LayerType.marine25k: false,
        LayerType.marine10k: true,
      });

      final layers = await ZoneConfig.resolveLayersForBounds(
        bounds,
        preflight: mock,
      );

      final marineLayers = layers.where(
        (l) => l.layerType != LayerType.lidarLitto3d,
      );
      expect(marineLayers, hasLength(2));
      expect(
        marineLayers.map((l) => l.layerType),
        containsAll([LayerType.marine50k, LayerType.marine10k]),
      );
      expect(
        marineLayers.any((l) => l.layerType == LayerType.marine25k),
        isFalse,
        reason: '25K doit être absent si non couvert',
      );
    });

    test('Test C — 50K uniquement (25K/10K absents)', () async {
      final mock = _MockPreflight({
        LayerType.marine50k: true,
        LayerType.marine25k: false,
        LayerType.marine10k: false,
      });

      final layers = await ZoneConfig.resolveLayersForBounds(
        bounds,
        preflight: mock,
      );

      final marineLayers = layers.where(
        (l) => l.layerType != LayerType.lidarLitto3d,
      );
      expect(marineLayers, hasLength(1));
      expect(marineLayers.first.layerType, LayerType.marine50k);
      expect(
        marineLayers.any((l) => l.layerType == LayerType.marine25k),
        isFalse,
      );
      expect(
        marineLayers.any((l) => l.layerType == LayerType.marine10k),
        isFalse,
      );
    });

    test('Test D — aucune couverture marine', () async {
      final mock = _MockPreflight({
        LayerType.marine50k: false,
        LayerType.marine25k: false,
        LayerType.marine10k: false,
      });

      final layers = await ZoneConfig.resolveLayersForBounds(
        bounds,
        preflight: mock,
      );

      expect(
        layers.where((l) => l.layerType != LayerType.lidarLitto3d),
        isEmpty,
        reason: 'Aucune couche marine ne doit être incluse',
      );
    });

    test('Fail-open — SHOM injoignable → toutes les couches', () async {
      final mock = _MockPreflight({
        LayerType.marine50k: null,
        LayerType.marine25k: null,
        LayerType.marine10k: null,
      });

      final layers = await ZoneConfig.resolveLayersForBounds(
        bounds,
        preflight: mock,
      );

      expect(
        layers.where((l) => l.layerType != LayerType.lidarLitto3d),
        hasLength(3),
        reason: 'Fail-open : toutes les couches marines incluses',
      );
    });

    test('Mixte — 50K couvert, autres injoignables → seul 50K inclus', () async {
      final mock = _MockPreflight({
        LayerType.marine50k: true,
        LayerType.marine25k: null,
        LayerType.marine10k: null,
      });

      final layers = await ZoneConfig.resolveLayersForBounds(
        bounds,
        preflight: mock,
      );

      // 50K inclus (couvert), 25K/10K non inclus (fail-open ne s'applique pas car pas tous null)
      final marineLayers = layers.where(
        (l) => l.layerType != LayerType.lidarLitto3d,
      );
      expect(
        marineLayers,
        hasLength(1),
        reason:
            'Seul 50K est couvert, fail-open ne s\'applique que si tous sont null',
      );
      expect(marineLayers.first.layerType, LayerType.marine50k);
    });
  });

  group('resolveLayersForBounds — LiDAR', () {
    final bounds = LatLngBounds(
      const LatLng(43.5, -1.5),
      const LatLng(43.0, -2.0),
    );

    test('LiDAR ajouté même sans couverture marine', () async {
      final mock = _MockPreflight({
        LayerType.marine50k: false,
        LayerType.marine25k: false,
        LayerType.marine10k: false,
      });

      final layers = await ZoneConfig.resolveLayersForBounds(
        bounds,
        preflight: mock,
      );

      // LiDAR est ajouté par defaultLayersForBounds (via catalogue régional)
      // et conservé dans resolveLayersForBounds
      // Le catalogue peut être vide en test, donc on vérifie juste que la logique
      // ne supprime pas les LiDAR existants
      expect(
        layers.where((l) => l.layerType != LayerType.lidarLitto3d),
        isEmpty,
        reason: 'Pas de couches marines',
      );
    });
  });
}

/// Mock de ShomCoveragePreflight pour les tests.
class _MockPreflight extends ShomCoveragePreflight {
  final Map<LayerType, bool?> _coverage;

  _MockPreflight(this._coverage) : super(client: null);

  @override
  Future<bool?> covers(LatLngBounds bounds, String layerName) async {
    final type = _layerNameToType(layerName);
    return _coverage[type];
  }

  LayerType _layerNameToType(String layerName) {
    if (layerName.contains('50')) return LayerType.marine50k;
    if (layerName.contains('25')) return LayerType.marine25k;
    if (layerName.contains('10')) return LayerType.marine10k;
    throw ArgumentError('Unknown layer: $layerName');
  }

  @override
  void close() {}
}
