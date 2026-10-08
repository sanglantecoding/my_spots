import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/services/mushroom/open_meteo_weather_service.dart';
import 'package:my_spots/services/mushroom/overpass_forest_service.dart';

/// Test réseau manuel :
/// RUN_LIVE_MUSHROOM_DIAGNOSTIC=1 flutter test --plain-name "Diagnostic réel"
/// Il reste ignoré par défaut pour que la suite ne dépende pas du réseau.
void main() {
  test(
    'Diagnostic réel Open-Meteo et Overpass à La Salvetat-sur-Agout',
    () async {
      const latitude = 43.57165;
      const longitude = 2.71734;
      const soilVariables = [
        'soil_moisture_0_1cm',
        'soil_moisture_1_3cm',
        'soil_moisture_3_9cm',
        'soil_moisture_9_27cm',
        'soil_moisture_27_81cm',
        'soil_temperature_6cm',
        'soil_temperature_18cm',
        'soil_temperature_54cm',
        'soil_moisture_0_to_7cm',
        'soil_moisture_7_to_28cm',
        'soil_moisture_28_to_100cm',
        'soil_moisture_100_to_255cm',
        'soil_temperature_0_to_7cm',
        'soil_temperature_7_to_28cm',
        'soil_temperature_28_to_100cm',
        'soil_temperature_100_to_255cm',
      ];

      final weatherHttp = _RecordingClient();
      try {
        final service = OpenMeteoWeatherService(client: weatherHttp);
        final historical = await service.getHistoricalWeather(
          lat: latitude,
          lng: longitude,
          days: 60,
        );
        final forecast = await service.getWeatherForecast(
          lat: latitude,
          lng: longitude,
          days: 7,
        );
        final soil = await service.getSoilMoisture(
          lat: latitude,
          lng: longitude,
        );
        // The service caches its first response. Fetch raw names side-by-side
        // once so the unsupported and documented ECMWF layer names are visible.
        final rawResponse = await weatherHttp.get(
          _openMeteoRawUri(soilVariables),
        );
        final raw = jsonDecode(rawResponse.body) as Map<String, dynamic>;
        final hourly = raw['hourly'] as Map<String, dynamic>;
        final times = (hourly['time'] as List)
            .map((value) => '$value')
            .toList();
        final dailyDates =
            (raw['daily'] as Map<String, dynamic>)['time'] as List;
        final forecastStart = dailyDates[dailyDates.length - 8].toString();

        // Production parser call status/body are recorded before the comparison
        // request; Open-Meteo's API returns HTTP status on the recorded request.
        // Print the live comparison response and the data actually passed to
        // model-facing SoilMoistureData.
        // ignore: avoid_print
        print(
          'OPEN_METEO production HTTP ${weatherHttp.responses.first.statusCode}',
        );
        // ignore: avoid_print
        print(
          'OPEN_METEO resolved=${raw['latitude']},${raw['longitude']} '
          'elevation=${raw['elevation']} timezone=${raw['timezone']} '
          'utc_offset_seconds=${raw['utc_offset_seconds']}',
        );
        // ignore: avoid_print
        print(
          'OPEN_METEO service history=${historical.length} forecast=${forecast.length} '
          'soilRows=${soil.length} soilNonNull=${soil.where(_hasSoilValue).length}',
        );

        final testNow = DateTime.now();
        final modelDay = DateTime.utc(testNow.year, testNow.month, testNow.day);
        final serviceTargetRows = soil.where(
          (row) => _utcCalendarDate(row.date) == modelDay,
        );
        // ignore: avoid_print
        print(
          'DATE_ALIGNMENT modelTarget=${modelDay.toIso8601String()} '
          'targetSoilRows=${serviceTargetRows.length} '
          'sampleRawTime=${times.isEmpty ? 'none' : times.first} '
          'rawTimeHasZone=${times.isNotEmpty && RegExp(r'(Z|[+-]\\d\\d:\\d\\d)$').hasMatch(times.first)} '
          'dailyForecastStart=$forecastStart; '
          'parser hours/daily keys use calendar fields, model _stripTime rebuilds UTC calendar keys.',
        );

        for (final variable in soilVariables) {
          final values = hourly[variable];
          if (values is! List) {
            // ignore: avoid_print
            print('SOIL $variable ABSENT from raw hourly object');
            continue;
          }
          final byDate = <String, ({int nulls, int absent, int total})>{};
          for (var i = 0; i < times.length; i++) {
            final date = times[i].substring(0, 10);
            final old = byDate[date] ?? (nulls: 0, absent: 0, total: 0);
            final missing = i >= values.length;
            byDate[date] = (
              nulls: old.nulls + (!missing && values[i] == null ? 1 : 0),
              absent: old.absent + (missing ? 1 : 0),
              total: old.total + 1,
            );
          }
          final history = byDate.entries
              .where((entry) => entry.key.compareTo(forecastStart) < 0)
              .toList();
          final future = byDate.entries
              .where((entry) => entry.key.compareTo(forecastStart) >= 0)
              .toList();
          final missingDates = _compactMissingDates(byDate);
          final totalNulls = values.where((value) => value == null).length;
          final absentCount = times.length > values.length
              ? times.length - values.length
              : 0;
          // ignore: avoid_print
          print(
            'SOIL $variable null=$totalNulls absent=$absentCount '
            'historical=${_sumNulls(history)}/${_sumHours(history)}h '
            'forecast=${_sumNulls(future)}/${_sumHours(future)}h '
            'datesWithMissing=[$missingDates] unit=${(raw['hourly_units'] as Map?)?[variable]}',
          );
        }
      } finally {
        weatherHttp.close();
      }

      final temporary = await Directory.systemTemp.createTemp(
        'overpass-live-diag-',
      );
      final forestHttp = _RecordingClient();
      try {
        const tileSouth = 43.55;
        const tileWest = 2.7;
        const tileNorth = 43.6;
        const tileEast = 2.75;
        final service = OverpassForestService(
          client: forestHttp,
          cacheDirectory: temporary,
          endpoint: OverpassForestService.defaultEndpoint,
          fallbackEndpoint: Uri.https(
            'overpass.private.coffee',
            '/api/interpreter',
          ),
          retryBackoff: const [],
        );
        final forest = await service.getForestData(
          lat: latitude,
          lng: longitude,
        );
        final response = forestHttp.responses.lastOrNull;
        final body = response?.body ?? '';
        var remark = false;
        var forestDiagnostics = 'response unavailable';
        try {
          final json = jsonDecode(body) as Map<String, dynamic>;
          remark = json.containsKey('remark');
          forestDiagnostics = _forestDiagnostics(
            json,
            latitude: latitude,
            longitude: longitude,
          );
        } catch (_) {}
        // ignore: avoid_print
        print(
          'OVERPASS tile=$tileSouth,$tileWest,$tileNorth,$tileEast '
          'httpStatuses=${forestHttp.responses.map((r) => r.statusCode).join(',')} '
          'bodyBytes=${utf8.encode(body).length} jsonValid=${_isJson(body)} '
          'bodyPreview=${body.replaceAll(RegExp(r'\s+'), ' ').substring(0, math.min(body.length, 180))} '
          'remark=$remark $forestDiagnostics '
          'serviceResult=(isForest:${forest.isForest}, type:${forest.forestType}, source:${forest.source})',
        );
      } finally {
        forestHttp.close();
        await temporary.delete(recursive: true);
      }
    },
    skip: Platform.environment['RUN_LIVE_MUSHROOM_DIAGNOSTIC'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'Comparaison manuelle des modèles ECMWF IFS et IFS 0.25° pour le sol',
    () async {
      final client = http.Client();
      const variables = [
        'soil_moisture_0_to_7cm',
        'soil_moisture_7_to_28cm',
        'soil_moisture_28_to_100cm',
        'soil_moisture_100_to_255cm',
        'soil_temperature_0_to_7cm',
        'soil_temperature_7_to_28cm',
        'soil_temperature_28_to_100cm',
        'soil_temperature_100_to_255cm',
      ];
      const resolutionByModel = {
        'ecmwf_ifs025': 'IFS open-data 0.25° (~25 km)',
        'ecmwf_ifs': 'IFS HRES 9 km',
      };
      try {
        for (final model in resolutionByModel.keys) {
          final response = await client.get(
            _openMeteoModelComparisonUri(model, variables),
          );
          final body = jsonDecode(response.body);
          // ignore: avoid_print
          print(
            'MODEL_COMPARISON model=$model '
            'documentedResolution=${resolutionByModel[model]} '
            'http=${response.statusCode}',
          );
          if (body is! Map<String, dynamic>) {
            // ignore: avoid_print
            print('MODEL_COMPARISON model=$model invalidJsonBody');
            continue;
          }
          final hourly = body['hourly'];
          if (hourly is! Map<String, dynamic>) {
            // ignore: avoid_print
            print(
              'MODEL_COMPARISON model=$model apiError=${body['reason'] ?? body['error'] ?? 'hourly absent'}',
            );
            continue;
          }
          final times = (hourly['time'] as List? ?? const [])
              .map((value) => value.toString())
              .toList();
          final available = variables.where(hourly.containsKey).toList();
          // ignore: avoid_print
          print(
            'MODEL_COMPARISON model=$model '
            'gridCell=${body['latitude']},${body['longitude']} '
            'timezone=${body['timezone']} variables=${available.join(',')}',
          );
          for (final variable in variables) {
            final values = hourly[variable];
            if (values is! List) {
              // ignore: avoid_print
              print(
                'MODEL_NULLS model=$model variable=$variable available=false',
              );
              continue;
            }
            final nullCount = values.where((value) => value == null).length;
            // ignore: avoid_print
            print(
              'MODEL_NULLS model=$model variable=$variable '
              'available=true null=$nullCount total=${values.length}',
            );
          }
          for (final variable in const [
            'soil_moisture_0_to_7cm',
            'soil_moisture_7_to_28cm',
          ]) {
            final values = hourly[variable];
            final byDate = _dailyPercentMeans(times, values);
            final dates = byDate.keys.toList()..sort();
            // ignore: avoid_print
            print(
              'MODEL_LAST_10_DAYS model=$model variable=$variable '
              '${dates.skip(math.max(0, dates.length - 10)).map((date) => '$date:${byDate[date]?.toStringAsFixed(1) ?? 'n/d'}%').join(',')}',
            );
          }
        }
      } finally {
        client.close();
      }
    },
    skip: Platform.environment['RUN_LIVE_MUSHROOM_DIAGNOSTIC'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

String _forestDiagnostics(
  Map<String, dynamic> document, {
  required double latitude,
  required double longitude,
}) {
  final elements = (document['elements'] as List? ?? const [])
      .whereType<Map>()
      .toList();
  final forestElements = elements.where((element) {
    final tags = element['tags'];
    return tags is Map &&
        (tags['landuse'] == 'forest' || tags['natural'] == 'wood');
  }).toList();
  final ways = forestElements.where((element) => element['type'] == 'way');
  final relations = forestElements.where(
    (element) =>
        element['type'] == 'relation' &&
        (element['tags'] as Map?)?['type'] == 'multipolygon',
  );
  final closedRings = <List<_Point>>[];
  for (final way in ways) {
    final ring = _points(way['geometry']);
    if (_isClosed(ring)) closedRings.add(ring);
  }

  final relationReports = <String>[];
  final incompleteRelations = <String>[];
  for (final relation in relations) {
    final id = relation['id'] ?? 'unknown';
    final members = (relation['members'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final outerMembers = members.where((member) => member['role'] == 'outer');
    final innerMembers = members.where((member) => member['role'] == 'inner');
    final outerGeometries = outerMembers
        .map((member) => _points(member['geometry']))
        .toList();
    final innerGeometries = innerMembers
        .map((member) => _points(member['geometry']))
        .toList();
    final outerSegments = outerGeometries
        .where((points) => points.length >= 2)
        .toList();
    final innerSegments = innerGeometries
        .where((points) => points.length >= 2)
        .toList();
    final outerAssembly = _stitch(outerSegments);
    final innerAssembly = _stitch(innerSegments);
    final outerRings = outerAssembly.rings;
    final innerRings = innerAssembly.rings;
    final allClosed =
        outerSegments.length == outerMembers.length &&
        innerSegments.length == innerMembers.length &&
        outerRings.isNotEmpty &&
        outerAssembly.incompleteSegments == 0 &&
        innerAssembly.incompleteSegments == 0;
    if (!allClosed) incompleteRelations.add('$id');
    relationReports.add(
      'relation#$id outerMembers=${outerMembers.length} '
      'innerMembers=${innerMembers.length} '
      'outerGeometryPoints=${outerGeometries.fold<int>(0, (n, ring) => n + ring.length)} '
      'innerGeometryPoints=${innerGeometries.fold<int>(0, (n, ring) => n + ring.length)} '
      'outerRingsClosed=${outerRings.isNotEmpty && outerAssembly.incompleteSegments == 0} '
      '(count=${outerRings.length}, incompleteSegments=${outerAssembly.incompleteSegments}) '
      'innerRingsClosed=${innerMembers.isEmpty || (innerAssembly.incompleteSegments == 0 && innerRings.isNotEmpty)} '
      '(count=${innerRings.length}, incompleteSegments=${innerAssembly.incompleteSegments})',
    );
    closedRings.addAll(outerRings.where(_isClosed));
  }

  final point = (lat: latitude, lon: longitude);
  final closestMeters = closedRings.isEmpty
      ? null
      : closedRings
            .map((ring) => _distanceToRing(point, ring))
            .reduce(math.min);
  return 'forestWays=${ways.length} forestMultipolygonRelations=${relations.length} '
      'nearestForestBoundaryMeters=${closestMeters?.toStringAsFixed(1) ?? 'unknown'} '
      'incompleteForestRelations=${incompleteRelations.isEmpty ? 'none' : incompleteRelations.join(',')} '
      '${relationReports.join(' | ')}';
}

typedef _Point = ({double lat, double lon});

List<_Point> _points(dynamic geometry) => (geometry as List? ?? const [])
    .whereType<Map>()
    .where((point) => point['lat'] is num && point['lon'] is num)
    .map(
      (point) => (
        lat: (point['lat'] as num).toDouble(),
        lon: (point['lon'] as num).toDouble(),
      ),
    )
    .toList();

bool _samePoint(_Point a, _Point b) =>
    (a.lat - b.lat).abs() < 1e-9 && (a.lon - b.lon).abs() < 1e-9;

bool _isClosed(List<_Point> ring) =>
    ring.length >= 4 && _samePoint(ring.first, ring.last);

({List<List<_Point>> rings, int incompleteSegments}) _stitch(
  List<List<_Point>> input,
) {
  final segments = input.map(List<_Point>.from).toList();
  final rings = <List<_Point>>[];
  var incompleteSegments = 0;
  while (segments.isNotEmpty) {
    final ring = segments.removeAt(0);
    var changed = true;
    while (!_samePoint(ring.first, ring.last) && changed) {
      changed = false;
      for (var i = 0; i < segments.length; i++) {
        final candidate = segments[i];
        if (_samePoint(ring.last, candidate.first)) {
          ring.addAll(candidate.skip(1));
        } else if (_samePoint(ring.last, candidate.last)) {
          ring.addAll(candidate.reversed.skip(1));
        } else if (_samePoint(ring.first, candidate.last)) {
          ring.insertAll(0, candidate.take(candidate.length - 1));
        } else if (_samePoint(ring.first, candidate.first)) {
          ring.insertAll(0, candidate.reversed.take(candidate.length - 1));
        } else {
          continue;
        }
        segments.removeAt(i);
        changed = true;
        break;
      }
    }
    if (_isClosed(ring)) {
      rings.add(ring);
    } else {
      incompleteSegments += 1;
    }
  }
  return (rings: rings, incompleteSegments: incompleteSegments);
}

double _distanceToRing(_Point point, List<_Point> ring) {
  const metersPerDegree = 111320.0;
  final lonScale = metersPerDegree * math.cos(point.lat * math.pi / 180).abs();
  var minimum = double.infinity;
  for (var i = 0; i < ring.length - 1; i++) {
    final a = ring[i];
    final b = ring[i + 1];
    final ax = (a.lon - point.lon) * lonScale;
    final ay = (a.lat - point.lat) * metersPerDegree;
    final bx = (b.lon - point.lon) * lonScale;
    final by = (b.lat - point.lat) * metersPerDegree;
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0).toDouble();
    minimum = math.min(
      minimum,
      math.sqrt(math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2)),
    );
  }
  return minimum;
}

Uri _openMeteoRawUri(List<String> variables) =>
    Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '43.57165',
      'longitude': '2.71734',
      'hourly': variables.join(','),
      'daily': 'precipitation_sum',
      'models': 'ecmwf_ifs025',
      'past_days': '60',
      'forecast_days': '8',
      'timezone': 'auto',
      'temperature_unit': 'celsius',
      'precipitation_unit': 'mm',
    });

Uri _openMeteoModelComparisonUri(String model, List<String> variables) =>
    Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '43.57165',
      'longitude': '2.71734',
      'hourly': variables.join(','),
      'models': model,
      'past_days': '10',
      'forecast_days': '1',
      'timezone': 'auto',
    });

Map<String, double?> _dailyPercentMeans(List<String> times, dynamic rawValues) {
  if (rawValues is! List) return const {};
  final valuesByDate = <String, List<double>>{};
  final count = math.min(times.length, rawValues.length);
  for (var i = 0; i < count; i++) {
    final value = rawValues[i];
    if (value is! num) continue;
    final date = times[i].split('T').first;
    valuesByDate.putIfAbsent(date, () => []).add(value.toDouble() * 100);
  }
  return valuesByDate.map(
    (date, values) => MapEntry(
      date,
      values.reduce((sum, value) => sum + value) / values.length,
    ),
  );
}

bool _hasSoilValue(SoilMoistureData row) =>
    row.soilMoisture != null || row.soilTemperature != null;

DateTime _utcCalendarDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

int _sumNulls(
  List<MapEntry<String, ({int nulls, int absent, int total})>> dates,
) => dates.fold(0, (sum, entry) => sum + entry.value.nulls);

int _sumHours(
  List<MapEntry<String, ({int nulls, int absent, int total})>> dates,
) => dates.fold(0, (sum, entry) => sum + entry.value.total);

String _compactMissingDates(
  Map<String, ({int nulls, int absent, int total})> byDate,
) {
  final missing = byDate.entries
      .where((entry) => entry.value.nulls + entry.value.absent > 0)
      .toList();
  if (missing.isEmpty) return 'none';
  final ranges = <String>[];
  var first = missing.first;
  var last = first;
  for (final current in missing.skip(1)) {
    final consecutive =
        DateTime.parse(
          current.key,
        ).difference(DateTime.parse(last.key)).inDays ==
        1;
    final sameCounts =
        current.value.nulls == first.value.nulls &&
        current.value.absent == first.value.absent &&
        current.value.total == first.value.total;
    if (consecutive && sameCounts) {
      last = current;
      continue;
    }
    ranges.add(_formatMissingRange(first, last));
    first = current;
    last = current;
  }
  ranges.add(_formatMissingRange(first, last));
  return ranges.join(',');
}

String _formatMissingRange(
  MapEntry<String, ({int nulls, int absent, int total})> first,
  MapEntry<String, ({int nulls, int absent, int total})> last,
) {
  final dates = first.key == last.key ? first.key : '${first.key}..${last.key}';
  return '$dates:${first.value.nulls}null/${first.value.absent}abs/'
      '${first.value.total}h';
}

bool _isJson(String body) {
  try {
    jsonDecode(body);
    return true;
  } catch (_) {
    return false;
  }
}

class _RecordedResponse {
  const _RecordedResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

class _RecordingClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final List<_RecordedResponse> responses = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final streamed = await _inner.send(request);
    final bytes = await streamed.stream.toBytes();
    final body = utf8.decode(bytes);
    responses.add(_RecordedResponse(streamed.statusCode, body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      streamed.statusCode,
      contentLength: bytes.length,
      request: streamed.request,
      headers: streamed.headers,
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
      reasonPhrase: streamed.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
