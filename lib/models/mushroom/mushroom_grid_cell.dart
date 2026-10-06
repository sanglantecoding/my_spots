import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';

/// Cellule de grille pour le calcul d'indice champignon sur une zone.
class MushroomGridCell {
  final LatLngBounds bounds;
  final MushroomForecast forecast;
  final DateTime calculationDate;

  MushroomGridCell({
    required this.bounds,
    required this.forecast,
    required this.calculationDate,
  });

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
