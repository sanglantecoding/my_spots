import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/offline_map_layer.dart';

/// Tests d'unicité des instanceId FMTC.
///
/// Ces tests verrouillent la logique de génération des instanceId :
/// - Deux couches différentes du même run ont des IDs différents
/// - Deux runs de la même couche ont des IDs différents
/// - L'instanceId inclut la clé de couche (et campagne LiDAR si applicable)
///
/// Cela protège contre les bugs où deux couches partageraient le même ID,
/// ce qui causerait des conflits dans le tracking FMTC.
void main() {
  group('instanceId FMTC — unicité', () {
    const zoneUuid = 'zone123';

    test(
      'même zone, même run, deux couches différentes → instanceId différents',
      () {
        const runCount = 1;

        final layer50k = OfflineMapLayer.create(
          layerType: LayerType.marine50k,
          minZoom: 11,
          maxZoom: 14,
        );

        final layer25k = OfflineMapLayer.create(
          layerType: LayerType.marine25k,
          minZoom: 12,
          maxZoom: 15,
        );

        final id50k = _buildInstanceId(zoneUuid, runCount, layer50k);
        final id25k = _buildInstanceId(zoneUuid, runCount, layer25k);

        expect(
          id50k,
          isNot(equals(id25k)),
          reason: 'Deux couches différentes doivent avoir des IDs différents',
        );

        // Vérification du format attendu
        expect(id50k, contains('zone123'));
        expect(id50k, contains('#1#'));
        expect(id50k, contains('marine50k'));

        expect(id25k, contains('zone123'));
        expect(id25k, contains('#1#'));
        expect(id25k, contains('marine25k'));
      },
    );

    test('même zone, même run, trois couches → tous les IDs différents', () {
      const runCount = 1;

      final layer50k = OfflineMapLayer.create(
        layerType: LayerType.marine50k,
        minZoom: 11,
        maxZoom: 14,
      );

      final layer25k = OfflineMapLayer.create(
        layerType: LayerType.marine25k,
        minZoom: 12,
        maxZoom: 15,
      );

      final layer10k = OfflineMapLayer.create(
        layerType: LayerType.marine10k,
        minZoom: 14,
        maxZoom: 16,
      );

      final ids = [
        _buildInstanceId(zoneUuid, runCount, layer50k),
        _buildInstanceId(zoneUuid, runCount, layer25k),
        _buildInstanceId(zoneUuid, runCount, layer10k),
      ];

      // Tous les IDs doivent être uniques
      expect(ids.toSet(), hasLength(3));

      // Format attendu : zone#run#layerKey
      expect(ids[0], equals('zone123#1#marine50k'));
      expect(ids[1], equals('zone123#1#marine25k'));
      expect(ids[2], equals('zone123#1#marine10k'));
    });

    test('même zone, même couche, deux runs → instanceId différents', () {
      const run1 = 1;
      const run2 = 2;

      final layer = OfflineMapLayer.create(
        layerType: LayerType.marine50k,
        minZoom: 11,
        maxZoom: 14,
      );

      final idRun1 = _buildInstanceId(zoneUuid, run1, layer);
      final idRun2 = _buildInstanceId(zoneUuid, run2, layer);

      expect(
        idRun1,
        isNot(equals(idRun2)),
        reason: 'Deux runs de la même couche doivent avoir des IDs différents',
      );

      expect(idRun1, equals('zone123#1#marine50k'));
      expect(idRun2, equals('zone123#2#marine50k'));
    });

    test('couche LiDAR avec campagne → instanceId inclut la campagne', () {
      const runCount = 1;

      final lidarLayer = OfflineMapLayer.create(
        layerType: LayerType.lidarLitto3d,
        minZoom: 0,
        maxZoom: 18,
        lidarLayerId: 'Bretagne_Nord_2023',
      );

      final id = _buildInstanceId(zoneUuid, runCount, lidarLayer);

      expect(id, contains('lidarLitto3d'));
      expect(id, contains('Bretagne_Nord_2023'));
      expect(id, equals('zone123#1#lidarLitto3d:Bretagne_Nord_2023'));
    });

    test('deux couches LiDAR avec campagnes différentes → IDs différents', () {
      const runCount = 1;

      final lidar1 = OfflineMapLayer.create(
        layerType: LayerType.lidarLitto3d,
        minZoom: 0,
        maxZoom: 18,
        lidarLayerId: 'Bretagne_Nord_2023',
      );

      final lidar2 = OfflineMapLayer.create(
        layerType: LayerType.lidarLitto3d,
        minZoom: 0,
        maxZoom: 18,
        lidarLayerId: 'Normandie_2024',
      );

      final id1 = _buildInstanceId(zoneUuid, runCount, lidar1);
      final id2 = _buildInstanceId(zoneUuid, runCount, lidar2);

      expect(id1, isNot(equals(id2)));
      expect(id1, contains('Bretagne_Nord_2023'));
      expect(id2, contains('Normandie_2024'));
    });

    test('couche LiDAR sans campagne → instanceId sans suffixe', () {
      const runCount = 1;

      final lidarLayer = OfflineMapLayer.create(
        layerType: LayerType.lidarLitto3d,
        minZoom: 0,
        maxZoom: 18,
      );

      final id = _buildInstanceId(zoneUuid, runCount, lidarLayer);

      expect(id, equals('zone123#1#lidarLitto3d'));
      expect(id, isNot(contains(':')));
    });
  });
}

/// Helper pour construire un instanceId comme le fait ZoneDownloadService.
///
/// Reproduit la logique de :
/// final instanceId = '${map.uuid}#$runCount#${_layerKey(layer)}';
/// String _layerKey(OfflineMapLayer layer) =>
///     layer.layerType.name +
///     (layer.lidarLayerId != null ? ':${layer.lidarLayerId}' : '');
String _buildInstanceId(String zoneUuid, int runCount, OfflineMapLayer layer) {
  final layerKey =
      layer.layerType.name +
      (layer.lidarLayerId != null ? ':${layer.lidarLayerId}' : '');
  return '$zoneUuid#$runCount#$layerKey';
}
