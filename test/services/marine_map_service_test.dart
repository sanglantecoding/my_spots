import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/litto3d_layer.dart';
import 'package:my_spots/models/marine_layer.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/marine_map_service.dart';

/// France métropolitaine : intersecte garanti au moins une région LiDAR.
final LatLngBounds _franceBounds = LatLngBounds(
  const LatLng(41.0, -5.5),
  const LatLng(51.5, 9.8),
);

/// Milieu de l'Atlantique : n'intersecte aucune région LiDAR.
final LatLngBounds _midAtlanticBounds = LatLngBounds(
  const LatLng(45.0, -25.0),
  const LatLng(46.0, -24.0),
);

/// Fabrique une couche lidar « téléchargée » valide pour les tests.
OfflineMapLayer _completedLidarLayer(
  String campaignId, {
  int minZoom = 11,
  int maxZoom = 16,
}) {
  final layer = OfflineMapLayer.create(
    layerType: LayerType.lidarLitto3d,
    lidarLayerId: campaignId,
    minZoom: minZoom,
    maxZoom: maxZoom,
  );
  layer.downloadStatus = LayerDownloadStatus.completed;
  layer.downloadedTileCount = 100;
  return layer;
}

void main() {
  // Noms réels issus du catalogue (source unique de vérité).
  final n50 = MarineLayerCatalog.marine50k.wmtsLayerName;
  final n25 = MarineLayerCatalog.marine25k.wmtsLayerName;
  final n10 = MarineLayerCatalog.marine10k.wmtsLayerName;
  final n100 = MarineLayerCatalog.marine100k.wmtsLayerName;
  final n350 = MarineLayerCatalog.marine350k.wmtsLayerName;
  final nOverview = MarineLayerCatalog.overview.wmtsLayerName;

  // Campagnes LiDAR réelles du catalogue.
  final campaignA = Litto3DCatalog.allLayers.first.id;
  final campaignB = Litto3DCatalog.allLayers.length > 1
      ? Litto3DCatalog.allLayers[1].id
      : campaignA;

  group('MarineMapService - layerOrderForZoom', () {
    test('zoom >= 14.0 online → 50k, 25k, 10k', () {
      expect(MarineMapService.layerOrderForZoom(14.0), equals([n50, n25, n10]));
    });

    test('zoom >= 14.0 offline → 50k, 25k, 10k', () {
      expect(
        MarineMapService.layerOrderForZoom(14.0, offline: true),
        equals([n50, n25, n10]),
      );
    });

    test('zoom >= 12.0 online → 50k, 25k', () {
      expect(MarineMapService.layerOrderForZoom(12.0), equals([n50, n25]));
    });

    // ⚠️ À zoom >= 12, l'offline empile AUSSI 50k+25k (couches téléchargées) :
    // le fallback 50k seul ne concerne que les zooms < 12.
    test('zoom >= 12.0 offline → 50k, 25k', () {
      expect(
        MarineMapService.layerOrderForZoom(12.0, offline: true),
        equals([n50, n25]),
      );
    });

    test('zoom 11.0 online → 50k', () {
      expect(MarineMapService.layerOrderForZoom(11.0), equals([n50]));
    });

    test('zoom 11.0 offline → 50k', () {
      expect(
        MarineMapService.layerOrderForZoom(11.0, offline: true),
        equals([n50]),
      );
    });

    test('zoom 9.0 online → 100k', () {
      expect(MarineMapService.layerOrderForZoom(9.0), equals([n100]));
    });

    test('zoom 9.0 offline → 50k (fallback)', () {
      expect(
        MarineMapService.layerOrderForZoom(9.0, offline: true),
        equals([n50]),
      );
    });

    test('zoom 7.0 online → 350k', () {
      expect(MarineMapService.layerOrderForZoom(7.0), equals([n350]));
    });

    test('zoom 7.0 offline → 50k (fallback)', () {
      expect(
        MarineMapService.layerOrderForZoom(7.0, offline: true),
        equals([n50]),
      );
    });

    test('zoom < 7.0 online → overview', () {
      expect(MarineMapService.layerOrderForZoom(6.0), equals([nOverview]));
    });

    test('zoom < 7.0 offline → 50k (fallback)', () {
      expect(
        MarineMapService.layerOrderForZoom(6.0, offline: true),
        equals([n50]),
      );
    });
  });

  group('MarineMapService - getActiveMarineTileLayers (online)', () {
    test('returns layers for high zoom', () {
      final layers = MarineMapService.getActiveMarineTileLayers(15.0);
      expect(layers.length, 3);
      expect(layers[0].key.toString(), contains('marine_layer_'));
    });

    test('returns layers for medium zoom', () {
      final layers = MarineMapService.getActiveMarineTileLayers(12.5);
      expect(layers.length, 2);
    });

    test('returns layers for low zoom', () {
      final layers = MarineMapService.getActiveMarineTileLayers(10.0);
      expect(layers.length, 1);
    });

    test('with zoneUuids parameter', () {
      final layers = MarineMapService.getActiveMarineTileLayers(
        15.0,
        zoneUuids: ['zone1', 'zone2'],
      );
      expect(layers.length, 3);
    });

    test('with errorTileCallback', () {
      final layers = MarineMapService.getActiveMarineTileLayers(
        15.0,
        errorTileCallback: (tile, error, stackTrace) {},
      );
      expect(layers.length, 3);
    });
  });

  group('MarineMapService - getOfflineMarineTileLayers', () {
    test('returns layers with zoneUuids', () {
      final layers = MarineMapService.getOfflineMarineTileLayers(15.0, [
        'zone1',
      ]);
      // message base + 50k + 25k + 10k
      expect(layers.length, 4);
    });

    // ⚠️ L'ordre offline ne dépend PAS de zoneUuids : même avec une liste
    // vide, on obtient message base + 3 couches (le provider sans store
    // ne matche rien, mais les TileLayers existent).
    test('empty zoneUuids still builds message base + marine layers', () {
      final layers = MarineMapService.getOfflineMarineTileLayers(15.0, []);
      expect(layers.length, 4);
      expect(layers[0].key, const Key('offline_message_base'));
    });

    test('low zoom offline fallback to 50k', () {
      final layers = MarineMapService.getOfflineMarineTileLayers(8.0, [
        'zone1',
      ]);
      // message base + 50k
      expect(layers.length, 2);
    });

    test('with errorTileCallback', () {
      final layers = MarineMapService.getOfflineMarineTileLayers(15.0, [
        'zone1',
      ], errorTileCallback: (tile, error, stackTrace) {});
      expect(layers.length, 4);
    });
  });

  group('MarineMapService - getActiveLidarLayers (online)', () {
    testWidgets('returns empty when bathymetry disabled', (tester) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = false;
        final layers = MarineMapService.getActiveLidarLayers(_franceBounds);
        expect(layers, isEmpty);
      });
    });

    testWidgets('returns empty when visibleBounds is null', (tester) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = true;
        final layers = MarineMapService.getActiveLidarLayers(null);
        expect(layers, isEmpty);
      });
    });

    testWidgets('returns layers when enabled and bounds provided', (
      tester,
    ) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = true;
        final layers = MarineMapService.getActiveLidarLayers(_franceBounds);
        expect(layers.length, greaterThan(0));
      });
    });

    testWidgets('respects custom opacity parameter', (tester) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = true;
        final layers = MarineMapService.getActiveLidarLayers(
          _franceBounds,
          opacity: 0.8,
        );
        expect(layers.length, greaterThan(0));
      });
    });

    testWidgets('with zoneUuids parameter', (tester) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = true;
        final layers = MarineMapService.getActiveLidarLayers(
          _franceBounds,
          zoneUuids: ['zone1'],
        );
        expect(layers.length, greaterThan(0));
      });
    });
  });

  group('MarineMapService - getOfflineLidarLayers', () {
    testWidgets('returns empty when bathymetry disabled', (tester) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = false;
        final layers = MarineMapService.getOfflineLidarLayers(null, {});
        expect(layers, isEmpty);
      });
    });

    testWidgets('returns empty when no lidar layers by zone', (tester) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = true;
        final layers = MarineMapService.getOfflineLidarLayers(null, {});
        expect(layers, isEmpty);
      });
    });

    testWidgets('returns layers for available zones', (tester) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = true;
        final layers = MarineMapService.getOfflineLidarLayers(null, {
          'zone1': [_completedLidarLayer(campaignA)],
        });
        expect(layers.length, 1);
      });
    });

    testWidgets('keeps layers when visible bounds intersect the campaign', (
      tester,
    ) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = true;
        final layers = MarineMapService.getOfflineLidarLayers(_franceBounds, {
          'zone1': [_completedLidarLayer(campaignA)],
        });
        expect(layers.length, 1);
      });
    });

    testWidgets('filters out layers not in visible bounds', (tester) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = true;
        final layers = MarineMapService.getOfflineLidarLayers(
          _midAtlanticBounds,
          {
            'zone1': [_completedLidarLayer(campaignA)],
          },
        );
        expect(layers, isEmpty);
      });
    });

    testWidgets('respects custom opacity parameter', (tester) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = true;
        final layers = MarineMapService.getOfflineLidarLayers(null, {
          'zone1': [_completedLidarLayer(campaignA)],
        }, opacity: 0.8);
        expect(layers.length, 1);
      });
    });

    testWidgets('sorts layers by sortOrder', (tester) async {
      await tester.runAsync(() async {
        if (Litto3DCatalog.allLayers.length < 2) return; // skip si 1 campagne
        AppSettings.bathymetryOverlayEnabled = true;
        final layers = MarineMapService.getOfflineLidarLayers(null, {
          'zone1': [
            _completedLidarLayer(campaignA),
            _completedLidarLayer(campaignB),
          ],
        });
        final expected = [
          Litto3DCatalog.findById(campaignA)!,
          Litto3DCatalog.findById(campaignB)!,
        ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        expect(layers.length, 2);
        expect(layers[0].key, Key('lidar_${expected[0].id}'));
        expect(layers[1].key, Key('lidar_${expected[1].id}'));
      });
    });

    testWidgets('uses minZoom/maxZoom from layer metadata', (tester) async {
      await tester.runAsync(() async {
        AppSettings.bathymetryOverlayEnabled = true;
        final layers = MarineMapService.getOfflineLidarLayers(null, {
          'zone1': [_completedLidarLayer(campaignA, minZoom: 12, maxZoom: 15)],
        });
        expect(layers.length, 1);
        expect(layers[0].minNativeZoom, 12);
        expect(layers[0].maxNativeZoom, 15);
      });
    });
  });

  group('MarineMapService - URL helpers', () {
    test('clevisuWmtsUrl returns correct URL', () {
      final url = MarineMapService.clevisuWmtsUrl(n50);
      expect(url, contains(n50));
      expect(url, contains('services.data.shom.fr'));
    });

    test('inspireWmtsUrl returns correct URL', () {
      final url = MarineMapService.inspireWmtsUrl(campaignA);
      expect(url, contains(campaignA));
      expect(url, contains('INSPIRE'));
    });
  });
}
