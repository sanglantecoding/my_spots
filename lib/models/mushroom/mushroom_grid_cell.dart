import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';

/// Cellule de grille pour le calcul d'indice champignon sur une zone.
class MushroomGridCell {
  final LatLngBounds bounds;

  /// Prévisions pré-calculées J+0 à J+7.
  final List<MushroomForecast> forecasts;
  final DateTime calculationDate;

  /// Indique si les données d'altitude sont connues pour cette cellule.
  final bool terrainKnown;

  /// Indique si les données météo sont connues pour cette cellule.
  final bool weatherKnown;

  MushroomGridCell({
    required this.bounds,
    required this.forecasts,
    required this.calculationDate,
    this.terrainKnown = false,
    this.weatherKnown = false,
  });

  /// Centre de la cellule.
  LatLng get center => bounds.center;

  /// Prévision du jour J+0 (pour compatibilité).
  MushroomForecast get forecast => forecasts.first;

  /// Crée une instance mockée pour les tests/développement.
  factory MushroomGridCell.mock({
    LatLngBounds? bounds,
    MushroomForecast? forecast,
    DateTime? calculationDate,
    bool terrainKnown = false,
    bool weatherKnown = false,
  }) {
    return MushroomGridCell(
      bounds:
          bounds ??
          LatLngBounds(const LatLng(43.0, 3.0), const LatLng(44.0, 4.0)),
      forecasts: [forecast ?? MushroomForecast.mock()],
      calculationDate: calculationDate ?? DateTime.now(),
      terrainKnown: terrainKnown,
      weatherKnown: weatherKnown,
    );
  }
}
