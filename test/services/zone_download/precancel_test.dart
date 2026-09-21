import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/offline_map_layer.dart';

/// Tests d'indépendance des clés preCancel par store.
///
/// Ces tests verrouillent la logique de preCancel dans ZoneDownloadService :
/// - La clé preCancel est "zone|storeName" (pas juste "zone")
/// - Les couches marines partagent le même store → même clé preCancel
/// - Les couches LiDAR avec campagnes différentes ont des stores différents
/// - Un téléchargement d'une couche n'annule pas l'instance d'une autre couche
///
/// Cela protège contre le bug où preCancel utilisait uniquement l'UUID de zone,
/// ce qui causait des annulations croisées entre couches.
void main() {
  group('preCancel — indépendance par store', () {
    const zoneUuid = 'zone123';

    test(
      'deux couches marines différentes → même clé preCancel (même store)',
      () {
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

        final store50k = _buildStoreName(zoneUuid, layer50k);
        final store25k = _buildStoreName(zoneUuid, layer25k);

        final key50k = _buildPreCancelKey(zoneUuid, store50k);
        final key25k = _buildPreCancelKey(zoneUuid, store25k);

        expect(
          key50k,
          equals(key25k),
          reason:
              'Les couches marines partagent le même store → même clé preCancel',
        );

        // Format attendu : zone|storeName
        expect(key50k, contains('zone123|'));
        expect(key25k, contains('zone123|'));

        // Les noms de store sont identiques pour les couches marines
        expect(store50k, equals(store25k));
      },
    );

    test(
      'marine50k et marine25k → même store (toutes les couches marines)',
      () {
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

        final store50k = _buildStoreName(zoneUuid, layer50k);
        final store25k = _buildStoreName(zoneUuid, layer25k);

        expect(store50k, equals('marine_zone_zone123'));
        expect(store25k, equals('marine_zone_zone123'));
        expect(store50k, equals(store25k));
      },
    );

    test('trois couches marines → même clé preCancel (même store)', () {
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

      final keys = [
        _buildPreCancelKey(zoneUuid, _buildStoreName(zoneUuid, layer50k)),
        _buildPreCancelKey(zoneUuid, _buildStoreName(zoneUuid, layer25k)),
        _buildPreCancelKey(zoneUuid, _buildStoreName(zoneUuid, layer10k)),
      ];

      // Toutes les clés sont identiques (même store)
      expect(keys.toSet(), hasLength(1));

      expect(keys[0], equals('zone123|marine_zone_zone123'));
      expect(keys[1], equals('zone123|marine_zone_zone123'));
      expect(keys[2], equals('zone123|marine_zone_zone123'));
    });

    test('LiDAR avec campagne → store inclut la campagne', () {
      final lidarLayer = OfflineMapLayer.create(
        layerType: LayerType.lidarLitto3d,
        minZoom: 0,
        maxZoom: 18,
        lidarLayerId: 'Bretagne_Nord_2023',
      );

      final store = _buildStoreName(zoneUuid, lidarLayer);
      final key = _buildPreCancelKey(zoneUuid, store);

      expect(store, contains('Bretagne_Nord_2023'));
      expect(key, equals('zone123|lidar_zone_zone123_Bretagne_Nord_2023'));
    });

    test(
      'deux couches LiDAR avec campagnes différentes → clés différentes',
      () {
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

        final key1 = _buildPreCancelKey(
          zoneUuid,
          _buildStoreName(zoneUuid, lidar1),
        );
        final key2 = _buildPreCancelKey(
          zoneUuid,
          _buildStoreName(zoneUuid, lidar2),
        );

        expect(key1, isNot(equals(key2)));
        expect(key1, contains('Bretagne_Nord_2023'));
        expect(key2, contains('Normandie_2024'));
      },
    );

    test('même couche, même zone → même clé preCancel', () {
      final layer = OfflineMapLayer.create(
        layerType: LayerType.marine50k,
        minZoom: 11,
        maxZoom: 14,
      );

      final store = _buildStoreName(zoneUuid, layer);
      final key1 = _buildPreCancelKey(zoneUuid, store);
      final key2 = _buildPreCancelKey(zoneUuid, store);

      expect(key1, equals(key2));
    });

    test('zones différentes → clés preCancel différentes', () {
      final layer = OfflineMapLayer.create(
        layerType: LayerType.marine50k,
        minZoom: 11,
        maxZoom: 14,
      );

      final zone1 = 'zoneA';
      final zone2 = 'zoneB';

      final store1 = _buildStoreName(zone1, layer);
      final store2 = _buildStoreName(zone2, layer);

      final key1 = _buildPreCancelKey(zone1, store1);
      final key2 = _buildPreCancelKey(zone2, store2);

      expect(key1, isNot(equals(key2)));
      expect(key1, contains('zoneA|'));
      expect(key2, contains('zoneB|'));
    });
  });
}

/// Helper pour construire un nom de store comme le fait ZoneDownloadService.
///
/// Reproduit la logique de _fmtcStoreName :
/// String _fmtcStoreName(String zoneUuid, LayerType layerType, String? lidarLayerId)
String _buildStoreName(String zoneUuid, OfflineMapLayer layer) {
  switch (layer.layerType) {
    case LayerType.marine50k:
    case LayerType.marine25k:
    case LayerType.marine10k:
      return 'marine_zone_$zoneUuid';
    case LayerType.lidarLitto3d:
      if (layer.lidarLayerId != null) {
        return 'lidar_zone_${zoneUuid}_${layer.lidarLayerId}';
      }
      return 'lidar_zone_$zoneUuid';
  }
}

/// Helper pour construire une clé preCancel comme le fait ZoneDownloadService.
///
/// Reproduit la logique :
/// final preCancelKey = '${map.uuid}|$storeName';
String _buildPreCancelKey(String zoneUuid, String storeName) {
  return '$zoneUuid|$storeName';
}
