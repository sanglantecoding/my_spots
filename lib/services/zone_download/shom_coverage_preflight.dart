import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/marine_layer.dart';
import 'package:my_spots/services/marine_map_service.dart';

class ShomCoveragePreflight {
  ShomCoveragePreflight({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const Map<String, String> _headers = {
    'User-Agent': 'my_spots (Flutter Mobile App)',
    'Referer': 'https://data.shom.fr/',
  };

  /// Retourne 12 par défaut si la couche n'est pas trouvée (ne devrait jamais arriver).
  static int _probeZoom(String layerName) =>
      MarineLayerCatalog.findByWmtsName(layerName)?.probeZoom ?? 12;

  static List<LatLng> probePoints(LatLngBounds b) {
    final midLat = (b.north + b.south) / 2;
    final midLon = (b.east + b.west) / 2;
    return [
      LatLng(midLat, midLon),
      LatLng(b.north, b.west),
      LatLng(b.north, b.east),
      LatLng(b.south, b.west),
      LatLng(b.south, b.east),
      LatLng(b.north, midLon),
      LatLng(b.south, midLon),
      LatLng(midLat, b.west),
      LatLng(midLat, b.east),
    ];
  }

  static (int, int) _tileCoords(LatLng p, int z) {
    final n = math.pow(2, z).toDouble();
    final x = ((p.longitude + 180) / 360 * n).floor();
    final latRad = p.latitude * math.pi / 180;
    final y =
        ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
                2 *
                n)
            .floor();
    return (x, y);
  }

  Future<bool?> covers(LatLngBounds bounds, String layerName) async {
    final z = _probeZoom(layerName);
    final points = probePoints(bounds);

    bool foundCoverage = false;
    bool serverReached = false;

    Future<void> probePoint(LatLng p) async {
      try {
        final (x, y) = _tileCoords(p, z);
        final url = MarineMapService.clevisuWmtsUrl(layerName)
            .replaceAll('{z}', '$z')
            .replaceAll('{x}', '$x')
            .replaceAll('{y}', '$y');
        final resp = await _client
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 8));
        serverReached = true;
        if (resp.statusCode == 200 && resp.bodyBytes.length > 200) {
          foundCoverage = true;
        }
      } catch (_) {}
    }

    await Future.wait(points.map(probePoint));

    if (foundCoverage) return true;
    return serverReached ? false : null;
  }

  void close() => _client.close();
}
