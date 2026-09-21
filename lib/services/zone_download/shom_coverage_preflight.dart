import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:my_spots/services/marine_map_service.dart';

/// Pré-analyse de couverture SHOM par tuiles de sondage.
///
/// Avant de créer les couches de téléchargement d'une zone, on interroge
/// quelques tuiles représentatives de chaque échelle RasterMarine :
/// - HTTP 200 + vrais octets  → l'échelle couvre la zone ;
/// - HTTP 404                 → l'échelle ne couvre pas la zone ;
/// - aucune réponse (réseau)  → `null` = injoignable (fail-open côté appelant).
class ShomCoveragePreflight {
  ShomCoveragePreflight({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const Map<String, String> _headers = {
    'User-Agent': 'my_spots (Flutter Mobile App)',
    'Referer': 'https://data.shom.fr/',
  };

  /// Zoom de sondage par couche (zoom natif médian de l'échelle).
  static int _probeZoom(String layerName) => switch (layerName) {
    'RASTER_MARINE_25_WMTS_3857' => 13,
    'RASTER_MARINE_10_WMTS_3857' => 15,
    _ => 12,
  };

  /// 9 points de sondage : centre, 4 coins, 4 milieux de bords.
  /// Un seul point couvert suffit à déclarer l'échelle utile.
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
  Future<bool?> covers(LatLngBounds bounds, String layerName) async {
    final z = _probeZoom(layerName);
    var serverReached = false;
    for (final p in probePoints(bounds)) {
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
          return true; // un seul point couvert suffit
        }
      } catch (_) {
        // point injoignable : on essaie les suivants
      }
    }
    return serverReached ? false : null;
  }

  void close() => _client.close();
}
