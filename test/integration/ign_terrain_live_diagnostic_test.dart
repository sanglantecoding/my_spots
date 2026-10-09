import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_spots/services/mushroom/ign_open_elevation_terrain_service.dart';

/// Sonda IGN manuelle. Exécution : RUN_LIVE_IGN_DIAGNOSTIC=1 flutter test
/// --plain-name "Diagnostic live IGN" test/integration/ign_terrain_live_diagnostic_test.dart
void main() {
  test(
    'Diagnostic live IGN pour le patch 3x3 de La Salvetat-sur-Agout',
    () async {
      const latitude = 43.57158;
      const longitude = 2.71777;
      final patch = IgnOpenElevationTerrainService.patch3x3(
        latitude,
        longitude,
      );
      final body = jsonEncode({
        'lon': patch.map((point) => point.$2).join('|'),
        'lat': patch.map((point) => point.$1).join('|'),
        'resource': 'ign_rge_alti_wld',
        'delimiter': '|',
      });
      final client = http.Client();
      final stopwatch = Stopwatch()..start();
      try {
        final response = await client
            .post(
              Uri.https(
                'data.geopf.fr',
                '/altimetrie/1.0/calcul/alti/rest/elevation.json',
              ),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'my_spots/1.0 (Flutter; live terrain diagnostic)',
                'Accept': 'application/json',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 30));
        stopwatch.stop();
        var sentinelCount = 0;
        var returnedCount = 0;
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final elevations = decoded['elevations'];
          if (elevations is List) {
            returnedCount = elevations.length;
            sentinelCount = elevations.where((entry) {
              if (entry is! Map) return false;
              final value = entry['z'];
              return value is num && value.toDouble() == -99999;
            }).length;
          }
        }
        // ignore: avoid_print
        print(
          'IGN_DIAGNOSTIC HTTP=${response.statusCode} '
          'elapsedMs=${stopwatch.elapsedMilliseconds} '
          'center=$latitude,$longitude patch=${patch.length} '
          'returned=$returnedCount sentinel(-99999)=$sentinelCount '
          'requestBody=$body',
        );
        // ignore: avoid_print
        print('IGN_DIAGNOSTIC rawBody=${response.body}');
      } finally {
        client.close();
      }
    },
    skip: Platform.environment['RUN_LIVE_IGN_DIAGNOSTIC'] != '1',
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
