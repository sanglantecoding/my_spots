import 'package:latlong2/latlong.dart';

/// Fonction partagée pour générer la clé d'un point dans les services champignons.
/// Format : "lat,lng" avec 6 décimales pour correspondre à mushroomViewportPointKey.
String mushroomViewportPointKey(LatLng point) =>
    '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';
