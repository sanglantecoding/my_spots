import 'dart:math' as math;

/// Fonctions de géométrie polygonale partagées par les services forestiers.
///
/// Fournit des algorithmes de point-in-polygon (ray casting) et de calcul
/// de distance aux bords de polygones, utilisés par OverpassForestService
/// et IgnBdForetForestService.

/// Représente un point géographique avec latitude et longitude.
class Point {
  const Point(this.lat, this.lon);
  final double lat;
  final double lon;
}

/// Teste si un point est à l'intérieur d'un anneau polygonal (ray casting).
///
/// [point] - Le point à tester
/// [ring] - L'anneau polygonal (liste de points)
/// [latFirst] - Si true, les coordonnées sont (lat, lon), sinon (lon, lat)
bool pointInRing(Point point, List<Point> ring, {bool latFirst = true}) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    final crosses =
        (a.lat > point.lat) != (b.lat > point.lat) &&
        point.lon <
            (b.lon - a.lon) * (point.lat - a.lat) / (b.lat - a.lat) + a.lon;
    if (crosses) inside = !inside;
  }
  return inside;
}

/// Teste si un point est à l'intérieur d'un anneau polygonal avec ordre d'axes explicite.
///
/// [lat] - Latitude du point
/// [lng] - Longitude du point
/// [ring] - L'anneau polygonal (liste de listes [lat, lng] ou [lng, lat])
/// [latFirst] - Si true, les coordonnées sont (lat, lon), sinon (lon, lat)
bool pointInRingRaw(double lat, double lng, List ring, {bool latFirst = true}) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    if (a is! List || b is! List || a.length < 2 || b.length < 2) continue;
    final ax = ((latFirst ? a[1] : a[0]) as num).toDouble();
    final ay = ((latFirst ? a[0] : a[1]) as num).toDouble();
    final bx = ((latFirst ? b[1] : b[0]) as num).toDouble();
    final by = ((latFirst ? b[0] : b[1]) as num).toDouble();
    if ((ay > lat) != (by > lat) &&
        lng < (bx - ax) * (lat - ay) / (by - ay) + ax) {
      inside = !inside;
    }
  }
  return inside;
}

/// Calcule la distance en mètres d'un point à un anneau polygonal.
///
/// [point] - Le point
/// [ring] - L'anneau polygonal
/// Retourne la distance minimale à n'importe quel segment de l'anneau.
double distanceToRingMeters(Point point, List<Point> ring) {
  const metersPerLatitudeDegree = 111320.0;
  final metersPerLongitudeDegree =
      metersPerLatitudeDegree * math.cos(point.lat * math.pi / 180).abs();
  var minimum = double.infinity;
  for (var i = 0; i < ring.length - 1; i++) {
    final a = ring[i];
    final b = ring[i + 1];
    final ax = (a.lon - point.lon) * metersPerLongitudeDegree;
    final ay = (a.lat - point.lat) * metersPerLatitudeDegree;
    final bx = (b.lon - point.lon) * metersPerLongitudeDegree;
    final by = (b.lat - point.lat) * metersPerLatitudeDegree;
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0).toDouble();
    final x = ax + t * dx;
    final y = ay + t * dy;
    final distanceSquared = x * x + y * y;
    if (distanceSquared < minimum) minimum = distanceSquared;
  }
  return math.sqrt(minimum);
}
