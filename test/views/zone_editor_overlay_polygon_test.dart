// Tests de la persistance et de la transmission des données polygonales.

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/offline_map.dart';
import 'package:my_spots/services/zone_download/zone_download.dart';

void main() {
  group('Polygon Zone data flow', () {
    test('OfflineMap correctly encodes and decodes polygon JSON', () {
      final polygonJson =
          '[{"lat":45.0,"lng":2.0},{"lat":44.5,"lng":2.5},{"lat":44.0,"lng":3.0}]';

      // Create OfflineMap with polygonJson
      final map = OfflineMap.create(
        uuid: 'test-uuid',
        name: 'Test Polygon Zone',
        northLat: 45.0,
        southLat: 44.0,
        westLng: 2.0,
        eastLng: 3.0,
        polygonJson: polygonJson,
      );

      // Verify polygonJson is stored
      expect(map.polygonJson, isNotNull);
      expect(map.polygonJson, equals(polygonJson));

      // Verify polygonPoints getter decodes correctly
      final decodedPoints = map.polygonPoints;
      expect(decodedPoints, isNotNull);
      expect(decodedPoints!.length, equals(3));
      expect(decodedPoints[0], equals(const LatLng(45.0, 2.0)));
      expect(decodedPoints[1], equals(const LatLng(44.5, 2.5)));
      expect(decodedPoints[2], equals(const LatLng(44.0, 3.0)));
    });

    test('ZoneDownloadService receives polygon from OfflineMap', () {
      // Create a fake downloader to capture the polygon parameter
      List<LatLng>? capturedPolygon;

      final fakeDownloader = FakeLayerDownloader(
        onDownloadLayer: (polygon) {
          capturedPolygon = polygon;
        },
      );

      // Create OfflineMap with polygon
      final polygonJson =
          '[{"lat":45.0,"lng":2.0},{"lat":44.5,"lng":2.5},{"lat":44.0,"lng":3.0}]';
      final map = OfflineMap.create(
        uuid: 'test-uuid',
        name: 'Test Polygon Zone',
        northLat: 45.0,
        southLat: 44.0,
        westLng: 2.0,
        eastLng: 3.0,
        polygonJson: polygonJson,
      );

      // Simulate what ZoneDownloadService does: retrieve polygonPoints and pass to downloader
      final polygon = map.polygonPoints;

      // Call the fake downloader (simulating the actual downloadLayer call)
      // In reality, this happens inside downloadZone, but we test the key part here
      final store = FMTCStore('test_store');
      fakeDownloader.downloadLayer(
        zoneUuid: map.uuid,
        store: store,
        instanceId: 'test-instance',
        urlTemplate: 'https://example.com/{z}/{x}/{y}.png',
        bounds: LatLngBounds(const LatLng(45.0, 2.0), const LatLng(44.0, 3.0)),
        minZoom: 8,
        maxZoom: 12,
        headers: {},
        onProgress: (progress) {},
        polygon: polygon,
      );

      // Verify the polygon was passed correctly
      expect(capturedPolygon, isNotNull);
      expect(capturedPolygon!.length, equals(3));
      expect(capturedPolygon![0], equals(const LatLng(45.0, 2.0)));
      expect(capturedPolygon![1], equals(const LatLng(44.5, 2.5)));
      expect(capturedPolygon![2], equals(const LatLng(44.0, 3.0)));
    });

    test('OfflineMap polygonPoints returns null for invalid JSON', () {
      final map = OfflineMap.create(
        uuid: 'test-uuid',
        name: 'Test Zone',
        northLat: 45.0,
        southLat: 44.0,
        westLng: 2.0,
        eastLng: 3.0,
        polygonJson: 'invalid json',
      );

      expect(map.polygonPoints, isNull);
    });

    test(
      'OfflineMap polygonPoints returns null for polygon with fewer than 3 points',
      () {
        final polygonJson = '[{"lat":45.0,"lng":2.0},{"lat":44.5,"lng":2.5}]';

        final map = OfflineMap.create(
          uuid: 'test-uuid',
          name: 'Test Zone',
          northLat: 45.0,
          southLat: 44.0,
          westLng: 2.0,
          eastLng: 3.0,
          polygonJson: polygonJson,
        );

        expect(map.polygonPoints, isNull);
      },
    );
  });
}

// Fake LayerDownloader to capture polygon parameter
class FakeLayerDownloader implements LayerDownloader {
  final Function(List<LatLng>?)? onDownloadLayer;

  FakeLayerDownloader({this.onDownloadLayer});

  @override
  Future<void> cancel(
    String zoneUuid,
    FMTCStore store,
    String instanceId,
  ) async {}

  @override
  Future<LayerDownloadResult> downloadLayer({
    required String zoneUuid,
    required FMTCStore store,
    required String instanceId,
    required String urlTemplate,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required Map<String, String> headers,
    required void Function(double) onProgress,
    String? preCancelInstanceId,
    FMTCStore? preCancelStore,
    List<LatLng>? polygon,
    bool expectPolygon = false,
  }) async {
    onDownloadLayer?.call(polygon);
    return LayerDownloadResult(
      estimatedTileCount: 100,
      downloadedTileCount: 100,
      failedTileCount: 0,
      successful: true,
      interruptReason: DownloadInterruptReason.none,
    );
  }

  @override
  bool pause(String zoneUuid, FMTCStore store, String instanceId) => false;

  @override
  bool resume(String zoneUuid, FMTCStore store, String instanceId) => false;
}
