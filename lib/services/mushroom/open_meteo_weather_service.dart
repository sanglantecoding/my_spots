import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/weather_service.dart';

/// Implémentation de [WeatherService] utilisant l'API Open-Meteo.
///
/// Modèle utilisé : `ecmwf_ifs025` avec :
/// - `past_days=60`
/// - `forecast_days=8`
/// - `timezone=auto`
///
/// Le client HTTP est long-lived (pas de close() prématuré). Un cache interne
/// évite les appels réseau redondants pour des positions proches.
class OpenMeteoWeatherService implements WeatherService {
  OpenMeteoWeatherService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const _model = 'ecmwf_ifs025';
  static const _cacheTtl = Duration(hours: 1);
  static const _coordPrecision = 3;

  final Map<String, _CachedResponse> _cache = {};

  String _cacheKey(double lat, double lng) {
    final latRounded = lat.toStringAsFixed(_coordPrecision);
    final lngRounded = lng.toStringAsFixed(_coordPrecision);
    return '$_model|$latRounded|$lngRounded';
  }

  Future<ParsedResponse> _fetchOrCache(double lat, double lng) async {
    final key = _cacheKey(lat, lng);
    final now = DateTime.now();
    final cached = _cache[key];
    if (cached != null && now.difference(cached.fetchedAt) < _cacheTtl) {
      return cached.data;
    }
    final data = await _fetchAndParse(lat, lng);
    _cache[key] = _CachedResponse(fetchedAt: now, data: data);
    return data;
  }

  Future<ParsedResponse> _fetchAndParse(double lat, double lng) async {
    final dailyParams = [
      'precipitation_sum',
      'temperature_2m_min',
      'temperature_2m_max',
      'temperature_2m_mean',
      'wind_speed_10m_max',
      'wind_gusts_10m_max',
      'et0_fao_evapotranspiration',
    ].join(',');

    final hourlyParams = [
      'relative_humidity_2m',
      'shortwave_radiation',
      'soil_moisture_0_1cm',
      'soil_moisture_1_3cm',
      'soil_moisture_3_9cm',
      'soil_moisture_9_27cm',
      'soil_moisture_27_81cm',
      'soil_temperature_6cm',
      'soil_temperature_18cm',
      'soil_temperature_54cm',
    ].join(',');

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'latitude': lat.toString(),
        'longitude': lng.toString(),
        'models': _model,
        'past_days': '60',
        'forecast_days': '8',
        'timezone': 'auto',
        'temperature_unit': 'celsius',
        'wind_speed_unit': 'ms',
        'precipitation_unit': 'mm',
        'daily': dailyParams,
        'hourly': hourlyParams,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Open-Meteo HTTP ${response.statusCode}: ${response.body}',
        uri,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return parseJson(json);
  }

  @override
  Future<List<WeatherDay>> getHistoricalWeather({
    required double lat,
    required double lng,
    required int days,
  }) async {
    final parsed = await _fetchOrCache(lat, lng);
    final result = parsed.weatherDays
        .where((d) => d.kind == WeatherDataKind.historical)
        .toList();
    if (days < result.length) {
      return result.sublist(result.length - days);
    }
    return result;
  }

  @override
  Future<List<WeatherDay>> getWeatherForecast({
    required double lat,
    required double lng,
    required int days,
  }) async {
    final parsed = await _fetchOrCache(lat, lng);
    final result = parsed.weatherDays
        .where((d) => d.kind == WeatherDataKind.forecast)
        .toList();
    final count = days + 1;
    if (count < result.length) {
      return result.sublist(0, count);
    }
    return result;
  }

  @override
  Future<List<SoilMoistureData>> getSoilMoisture({
    required double lat,
    required double lng,
  }) async {
    final parsed = await _fetchOrCache(lat, lng);
    return parsed.soilLayers;
  }

  /// Parse une réponse Open-Meteo en listes typées.
  ///
  /// [forecastDays] indique combien des derniers jours de `daily.time`
  /// correspondent au segment prévision. Par défaut 8 (J+0 à J+7).
  /// Les jours précédents sont `historical`, ce qui garantit la
  /// déduplication J+0 (présent seulement côté forecast).
  static ParsedResponse parseJson(
    Map<String, dynamic> json, {
    int forecastDays = 8,
    String sourceModel = _model,
  }) {
    final daily = json['daily'] as Map<String, dynamic>?;
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (daily == null || hourly == null) {
      throw const FormatException('Open-Meteo response missing daily/hourly');
    }

    final dailyDates = _parseDateList(daily['time'] as List<dynamic>);
    final hourlyTimes = _parseDateTimeList(hourly['time'] as List<dynamic>);
    final forecastStartIdx = dailyDates.length - forecastDays;

    final dailyPrecip = _toDoubleListOrNull(daily['precipitation_sum']);
    final dailyTmin = _toDoubleListOrNull(daily['temperature_2m_min']);
    final dailyTmax = _toDoubleListOrNull(daily['temperature_2m_max']);
    final dailyTmean = _toDoubleListOrNull(daily['temperature_2m_mean']);
    final dailyWindMax = _toDoubleListOrNull(daily['wind_speed_10m_max']);
    final dailyGustMax = _toDoubleListOrNull(daily['wind_gusts_10m_max']);
    final dailyEt0 = _toDoubleListOrNull(daily['et0_fao_evapotranspiration']);

    final hourlyHumidity = _toDoubleListOrNull(hourly['relative_humidity_2m']);
    final hourlySolar = _toDoubleListOrNull(hourly['shortwave_radiation']);
    final hourlySm01 = _toDoubleListOrNull(hourly['soil_moisture_0_1cm']);
    final hourlySm13 = _toDoubleListOrNull(hourly['soil_moisture_1_3cm']);
    final hourlySm39 = _toDoubleListOrNull(hourly['soil_moisture_3_9cm']);
    final hourlySm927 = _toDoubleListOrNull(hourly['soil_moisture_9_27cm']);
    final hourlySm2781 = _toDoubleListOrNull(hourly['soil_moisture_27_81cm']);
    final hourlySt6 = _toDoubleListOrNull(hourly['soil_temperature_6cm']);
    final hourlySt18 = _toDoubleListOrNull(hourly['soil_temperature_18cm']);
    final hourlySt54 = _toDoubleListOrNull(hourly['soil_temperature_54cm']);

    final humidityByDay = _dailyMeanFromHourly(hourlyTimes, hourlyHumidity);
    final solarByDay = _dailyMeanFromHourly(hourlyTimes, hourlySolar);

    final sm01ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySm01);
    final sm13ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySm13);
    final sm39ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySm39);
    final sm927ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySm927);
    final sm2781ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySm2781);
    final st6ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySt6);
    final st18ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySt18);
    final st54ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySt54);

    final weatherDays = <WeatherDay>[];
    for (var i = 0; i < dailyDates.length; i++) {
      final date = dailyDates[i];
      final isForecast = i >= forecastStartIdx;
      weatherDays.add(
        WeatherDay(
          date: date,
          kind: isForecast
              ? WeatherDataKind.forecast
              : WeatherDataKind.historical,
          precipitation: dailyPrecip?.elementAtOrNull(i),
          temperatureMin: dailyTmin?.elementAtOrNull(i),
          temperatureMax: dailyTmax?.elementAtOrNull(i),
          temperatureMean: dailyTmean?.elementAtOrNull(i),
          windSpeed: dailyWindMax?.elementAtOrNull(i),
          windGust: dailyGustMax?.elementAtOrNull(i),
          et0: dailyEt0?.elementAtOrNull(i),
          humidity: humidityByDay[date],
          solarRadiation: solarByDay[date],
        ),
      );
    }

    final soilLayers = <SoilMoistureData>[];
    final allSoilDates = <DateTime>{
      ...sm01ByDay.keys,
      ...sm13ByDay.keys,
      ...sm39ByDay.keys,
      ...sm927ByDay.keys,
      ...sm2781ByDay.keys,
    }.toList()..sort();

    final forecastStartDate =
        forecastStartIdx >= 0 && forecastStartIdx < dailyDates.length
        ? dailyDates[forecastStartIdx]
        : null;

    for (final date in allSoilDates) {
      final isForecast =
          forecastStartDate != null && !date.isBefore(forecastStartDate);
      final kind = isForecast
          ? SoilMoistureDataKind.forecast
          : SoilMoistureDataKind.historical;

      final layerSpecs = <_LayerSpec>[
        _LayerSpec(0, 1, sm01ByDay[date], null),
        _LayerSpec(1, 3, sm13ByDay[date], null),
        _LayerSpec(3, 9, sm39ByDay[date], st6ByDay[date]),
        _LayerSpec(9, 27, sm927ByDay[date], st18ByDay[date]),
        _LayerSpec(27, 81, sm2781ByDay[date], st54ByDay[date]),
      ];

      for (final spec in layerSpecs) {
        final moistureVol = spec.moistureM3;
        soilLayers.add(
          SoilMoistureData(
            date: date,
            kind: kind,
            depthStart: spec.startCm.toDouble(),
            depthEnd: spec.endCm.toDouble(),
            soilMoisture: moistureVol == null ? null : moistureVol * 100.0,
            soilTemperature: spec.temperatureC,
            soilWaterIndex: null,
            source: sourceModel,
          ),
        );
      }
    }

    return ParsedResponse(weatherDays: weatherDays, soilLayers: soilLayers);
  }

  static List<DateTime> _parseDateList(List<dynamic> raw) {
    return raw.map((e) {
      final s = e.toString();
      final parts = s.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }).toList();
  }

  static List<DateTime> _parseDateTimeList(List<dynamic> raw) {
    return raw.map((e) => DateTime.parse(e.toString())).toList();
  }

  static List<double?>? _toDoubleListOrNull(dynamic raw) {
    if (raw is! List) return null;
    return raw.map((e) => e == null ? null : (e as num).toDouble()).toList();
  }

  static Map<DateTime, double?> _dailyMeanFromHourly(
    List<DateTime> hourlyTimes,
    List<double?>? hourlyValues,
  ) {
    final buckets = <DateTime, List<double>>{};
    if (hourlyValues == null) return {};
    final len = min(hourlyTimes.length, hourlyValues.length);
    for (var i = 0; i < len; i++) {
      final t = hourlyTimes[i];
      final v = hourlyValues[i];
      if (v == null) continue;
      final day = DateTime(t.year, t.month, t.day);
      buckets.putIfAbsent(day, () => []).add(v);
    }
    return buckets.map((day, values) {
      if (values.isEmpty) return MapEntry(day, null);
      final sum = values.reduce((a, b) => a + b);
      return MapEntry(day, sum / values.length);
    });
  }
}

class _LayerSpec {
  _LayerSpec(this.startCm, this.endCm, this.moistureM3, this.temperatureC);
  final int startCm;
  final int endCm;
  final double? moistureM3;
  final double? temperatureC;
}

class _CachedResponse {
  _CachedResponse({required this.fetchedAt, required this.data});
  final DateTime fetchedAt;
  final ParsedResponse data;
}

/// Résultat du parsing d'une réponse Open-Meteo.
class ParsedResponse {
  ParsedResponse({required this.weatherDays, required this.soilLayers});
  final List<WeatherDay> weatherDays;
  final List<SoilMoistureData> soilLayers;
}
