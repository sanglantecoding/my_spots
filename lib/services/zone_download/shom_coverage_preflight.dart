import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:my_spots/services/marine_map_service.dart';

class ShomCoveragePreflight {
  ShomCoveragePreflight({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const Map<String, String> _headers = {
    'User-Agent': 'my_spots (Flutter Mobile App)',
    'Referer': 'https://data.shom.fr/',
  };

  static int _probeZoom(String layerName) => switch (layerName) {
    'RASTER_MARINE_25_WMTS_3857' => 13,
    'RASTER_MARINE_10_WMTS_3857' => 15,
    _ => 12,
  };

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

  /// `true` = couvert, `false` = non couvert (404), `null` = SHOM injoignable.
  ///
  /// Les 9 points sont sondés en PARALLÈLE. On attend que TOUTES les requêtes
  /// soient terminées avant de retourner, pour éviter de fermer le http.Client
  /// alors que des requêtes sont encore en vol.
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
      } catch (_) {
        // point injoignable : on ignore, les autres continuent
      }
    }

    // Attend que TOUTES les probes soient terminées avant de retourner.
    // Plus de court-circuit : le http.Client ne sera jamais fermé sous
    // des requêtes en vol.
    await Future.wait(points.map(probePoint));

    if (foundCoverage) return true;
    return serverReached ? false : null;
  }

  void close() => _client.close();
}
