import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';

/// Cellule de grille pour le calcul d'indice champignon sur une zone.
class MushroomGridCell {
  final LatLngBounds bounds;
  final MushroomForecast forecast;

  /// Prévisions pré-calculées J+0 à J+7 ; [forecast] reste J+0 pour compatibilité.
  final List<MushroomForecast> forecasts;
  final DateTime calculationDate;

  MushroomGridCell({
    required this.bounds,
    required this.forecast,
    List<MushroomForecast>? forecasts,
    required this.calculationDate,
  }) : forecasts = forecasts ?? [forecast];

  /// Centre de la cellule.
  LatLng get center => bounds.center;

  /// Crée une instance mockée pour les tests/développement.
  factory MushroomGridCell.mock({
    LatLngBounds? bounds,
    MushroomForecast? forecast,
    DateTime? calculationDate,
  }) {
    return MushroomGridCell(
      bounds:
          bounds ??
          LatLngBounds(const LatLng(43.0, 3.0), const LatLng(44.0, 4.0)),
      forecast: forecast ?? MushroomForecast.mock(),
      calculationDate: calculationDate ?? DateTime.now(),
    );
  }
}
