import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_provider.dart';
import 'package:my_spots/views/mushroom/mushroom_observation_form.dart';
import 'package:my_spots/views/mushroom/mushroom_observations_screen.dart';

const _observationActionBarHeight = 56.0;

Future<void> showMushroomForecastSheet(BuildContext context, LatLng point) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1929),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => MushroomForecastSheet(point: point),
    );

class MushroomForecastSheet extends StatefulWidget {
  const MushroomForecastSheet({super.key, required this.point});

  final LatLng point;

  @override
  State<MushroomForecastSheet> createState() => _MushroomForecastSheetState();
}

class _MushroomForecastSheetState extends State<MushroomForecastSheet> {
  List<MushroomForecast>? _forecasts;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (!AppSettings.offlineModeEnabled) _loadForecasts();
  }

  Future<void> _loadForecasts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final forecasts = await MushroomForecastProvider.forecastBoletusRange(
        latitude: widget.point.latitude,
        longitude: widget.point.longitude,
        startDate: DateTime.now(),
      );
      if (mounted) setState(() => _forecasts = forecasts);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = AppSettings.offlineModeEnabled;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Prévision cèpe de Bordeaux',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${widget.point.latitude.toStringAsFixed(5)}, '
                '${widget.point.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 12),
              if (offline)
                const _StatusMessage(
                  icon: Icons.wifi_off,
                  message:
                      'Prévision indisponible en mode hors-ligne. '
                      'Désactivez le mode hors-ligne pour charger les données.',
                )
              else if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                _StatusMessage(
                  icon: Icons.cloud_off,
                  message:
                      'Impossible de récupérer la prévision. Vérifiez votre '
                      'connexion puis réessayez.',
                  action: TextButton.icon(
                    onPressed: _loadForecasts,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                )
              else if (_forecasts != null) ...[
                Builder(
                  builder: (context) {
                    if (_forecasts!.first.habitat == HabitatStatus.excluded) {
                      return const SizedBox.shrink();
                    }
                    final bestDay = _forecasts!.asMap().entries.reduce(
                      (best, entry) =>
                          entry.value.index > best.value.index ? entry : best,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Meilleur jour estimé : J+${bestDay.key} '
                        '(indice ${bestDay.value.index})',
                        style: const TextStyle(
                          color: Color(0xFF80CBC4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(
                      bottom: _observationActionBarHeight,
                    ),
                    itemCount: _forecasts!.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) => _ForecastDayExpansion(
                      dayOffset: index,
                      forecast: _forecasts![index],
                    ),
                  ),
                ),
              ],
              SizedBox(
                height: _observationActionBarHeight,
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MushroomObservationsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Observations'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () async {
                        final saved = await showMushroomObservationForm(
                          context,
                          latitude: widget.point.latitude,
                          longitude: widget.point.longitude,
                        );
                        if (saved == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Observation enregistrée.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Noter une observation'),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 20),
              const Text(
                'Indice indicatif de conditions favorables (modèle provisoire).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (_forecasts != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _sourcesSummary(_forecasts!.first),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sourcesSummary(MushroomForecast forecast) {
  final sources = forecast.dataSources;
  final soilStatus = forecast.soilMoistureAvailable
      ? 'disponible'
      : 'indisponible';
  final tileKnown = sources['forestTileKnown'] == 'true';
  final areaCount = int.tryParse(sources['forestAreasInTile'] ?? '');
  final distance = double.tryParse(
    sources['nearestForestDistanceMeters'] ?? '',
  );
  final forestOsm = !tileKnown
      ? 'Forêt OSM : donnée non disponible'
      : areaCount == null || areaCount == 0
      ? 'Forêt OSM : aucune zone forestière dans la tuile'
      : 'Forêt OSM : $areaCount zones dans la tuile, la plus proche à '
            '${distance == null ? 'n/d' : '${distance.toStringAsFixed(0)} m'}';
  return 'Sources : météo ${sources['weather'] ?? 'inconnue'} '
      '(sol : $soilStatus) · altitude ${sources['terrain'] ?? 'inconnue'} · '
      'forêt ${sources['forest'] ?? 'inconnue'} · $forestOsm';
}

class _ForecastDayExpansion extends StatelessWidget {
  const _ForecastDayExpansion({
    required this.dayOffset,
    required this.forecast,
  });

  final int dayOffset;
  final MushroomForecast forecast;

  @override
  Widget build(BuildContext context) {
    final f = forecast.factors;
    final excluded = forecast.habitat == HabitatStatus.excluded;
    final date =
        '${forecast.date.day.toString().padLeft(2, '0')}/'
        '${forecast.date.month.toString().padLeft(2, '0')}';
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        children: [
          Expanded(child: Text('J+$dayOffset · $date')),
          Text(
            excluded ? 'Hors habitat' : '${forecast.index}',
            style: TextStyle(
              color: excluded ? Colors.grey : Color(0xFF80CBC4),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (forecast.index / 100).clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              backgroundColor: excluded ? Colors.grey.shade700 : Colors.white12,
              color: excluded ? Colors.grey.shade500 : const Color(0xFF80CBC4),
            ),
            if (excluded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Hors habitat : ${forecast.habitatReason ?? 'raison inconnue'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            if (forecast.habitat == HabitatStatus.unknown)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Habitat non vérifié',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
      children: [
        if ((forecast.hydricGate ?? 1.0) < 1.0)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Humidité insuffisante : indice limité',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _shockDescription(forecast),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        if (excluded)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Hors habitat : ${forecast.habitatReason ?? 'raison inconnue'} · '
              'Confiance : '
              '${(forecast.confidence * 100).round()} %',
              style: const TextStyle(color: Colors.white70),
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Indice : ${forecast.index}/100 · Confiance : '
              '${(forecast.confidence * 100).round()} %',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        const SizedBox(height: 8),
        _FactorRow(
          label: mushroomWaterFactorLabel(forecast.soilMoistureAvailable),
          value: f.waterFactor,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            forecast.wetStreak == null
                ? 'Humidité maintenue : donnée non disponible'
                : 'Humidité maintenue : ${forecast.wetStreak} '
                      '${forecast.wetStreak == 1 ? 'jour' : 'jours'}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        _FactorRow(
          label: forecast.temperatureSource == 'soil_0_7cm'
              ? 'Température du sol (0–7 cm)'
              : 'Température de l’air',
          value: f.temperatureFactor,
        ),
        _FactorRow(label: 'Dessèchement', value: f.dryingFactor),
        _FactorRow(label: 'Choc déclencheur', value: f.shockFactor),
        _FactorRow(label: 'Terrain', value: f.terrainFactor),
        _FactorRow(label: 'Forêt', value: f.forestFactor),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            mushroomSoilValuesLabel(forecast),
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            mushroomSoilHistoryStatsLabel(forecast),
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

/// Libellé du facteur eau selon la disponibilité d'une mesure du sol.
String mushroomWaterFactorLabel(bool soilMoistureAvailable) =>
    soilMoistureAvailable ? 'Eau' : 'Eau (sans mesure du sol)';

/// Valeurs observées dans les réponses de sol pour le jour de la fiche.
String mushroomSoilValuesLabel(MushroomForecast forecast) =>
    'Sol 0-7 cm : ${_formatSoilValue(forecast.soilMoisture0To7Percent)} % · '
    '7-28 cm : ${_formatSoilValue(forecast.soilMoisture7To28Percent)} % · '
    'température sol 0-7 cm : '
    '${_formatSoilValue(forecast.soilTemperature0To7C)} °C';

String mushroomSoilHistoryStatsLabel(MushroomForecast forecast) =>
    'Sol 7-28 cm sur 60 j : min '
    '${_formatSoilValue(forecast.soilMoisture7To28Min60dPercent)} % · médiane '
    '${_formatSoilValue(forecast.soilMoisture7To28Median60dPercent)} % · max '
    '${_formatSoilValue(forecast.soilMoisture7To28Max60dPercent)} % · '
    "aujourd'hui au "
    '${forecast.soilMoisture7To28Percentile60d == null ? 'n/d' : '${forecast.soilMoisture7To28Percentile60d!.round()}e'} percentile';

String _formatSoilValue(double? value) =>
    value == null ? 'n/d' : value.toStringAsFixed(1);

String _shockDescription(MushroomForecast forecast) {
  final eventDate = forecast.shockDate;
  final score = forecast.factors.shockFactor;
  if (eventDate == null || score == null || score <= 0) {
    return 'Aucun choc dans la fenêtre';
  }
  final targetDay = DateTime.utc(
    forecast.date.year,
    forecast.date.month,
    forecast.date.day,
  );
  final shockDay = DateTime.utc(eventDate.year, eventDate.month, eventDate.day);
  final daysAgo = targetDay.difference(shockDay).inDays;
  final rain =
      forecast.shockRainMm?.toStringAsFixed(1) ?? 'donnée non disponible';
  final drop = forecast.shockTempDropC == null
      ? 'donnée non disponible'
      : forecast.shockTempDropC!.toStringAsFixed(1);
  return 'Choc déclencheur il y a $daysAgo jours '
      '(pluie $rain mm, baisse $drop °C)';
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.label, required this.value});

  final String label;
  final double? value;
  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          '$label : donnée non disponible',
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              '$label : ${(value! * 100).round()} %',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value!.clamp(0.0, 1.0).toDouble(),
              minHeight: 5,
              backgroundColor: Colors.white12,
              color: const Color(0xFF80CBC4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        Icon(icon, color: Colors.orangeAccent),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        ?action,
      ],
    ),
  );
}
