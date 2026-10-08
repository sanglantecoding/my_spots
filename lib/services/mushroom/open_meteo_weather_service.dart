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
      'soil_moisture_0_to_7cm',
      'soil_moisture_7_to_28cm',
      'soil_moisture_28_to_100cm',
      'soil_moisture_100_to_255cm',
      'soil_temperature_0_to_7cm',
      'soil_temperature_7_to_28cm',
      'soil_temperature_28_to_100cm',
      'soil_temperature_100_to_255cm',
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
    final hourlySm07 = _toDoubleListOrNull(hourly['soil_moisture_0_to_7cm']);
    final hourlySm728 = _toDoubleListOrNull(hourly['soil_moisture_7_to_28cm']);
    final hourlySm28100 = _toDoubleListOrNull(
      hourly['soil_moisture_28_to_100cm'],
    );
    final hourlySm100255 = _toDoubleListOrNull(
      hourly['soil_moisture_100_to_255cm'],
    );
    final hourlySt07 = _toDoubleListOrNull(hourly['soil_temperature_0_to_7cm']);
    final hourlySt728 = _toDoubleListOrNull(
      hourly['soil_temperature_7_to_28cm'],
    );
    final hourlySt28100 = _toDoubleListOrNull(
      hourly['soil_temperature_28_to_100cm'],
    );
    final hourlySt100255 = _toDoubleListOrNull(
      hourly['soil_temperature_100_to_255cm'],
    );

    final humidityByDay = _dailyMeanFromHourly(hourlyTimes, hourlyHumidity);
    final solarByDay = _dailyMeanFromHourly(hourlyTimes, hourlySolar);

    final sm07ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySm07);
    final sm728ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySm728);
    final sm28100ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySm28100);
    final sm100255ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySm100255);
    final st07ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySt07);
    final st728ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySt728);
    final st28100ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySt28100);
    final st100255ByDay = _dailyMeanFromHourly(hourlyTimes, hourlySt100255);

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
      ...sm07ByDay.keys,
      ...sm728ByDay.keys,
      ...sm28100ByDay.keys,
      ...sm100255ByDay.keys,
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
        _LayerSpec(0, 7, sm07ByDay[date], st07ByDay[date]),
        _LayerSpec(7, 28, sm728ByDay[date], st728ByDay[date]),
        _LayerSpec(28, 100, sm28100ByDay[date], st28100ByDay[date]),
        _LayerSpec(100, 255, sm100255ByDay[date], st100255ByDay[date]),
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
