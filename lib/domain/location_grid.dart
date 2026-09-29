import 'dart:math' as math;

/// The same approximate-area grid as the server (backend/src/location.ts):
/// keep the two identical. The phone rounds to a cell before anything is
/// sent, so an exact location never leaves it.
class AreaCell {
  const AreaCell(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is AreaCell && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'AreaCell($lat, $lng)';
}

/// Cell height in degrees of latitude: about 2 km.
const cellDegrees = 0.018;

/// Matches JavaScript's Math.round (half rounds up), used by the server.
double _round6(double x) => (x * 1e6 + 0.5).floorToDouble() / 1e6;

AreaCell snapToCell(double lat, double lng) {
  final row = (lat / cellDegrees).floorToDouble();
  final centreLat = math.min(
    89.99,
    math.max(-89.99, (row + 0.5) * cellDegrees),
  );
  final lngStep =
      cellDegrees / math.max(math.cos(centreLat * math.pi / 180), 0.01);
  final wrapped = ((((lng + 180) % 360) + 360) % 360) - 180;
  final col = (wrapped / lngStep).floorToDouble();
  var centreLng = (col + 0.5) * lngStep;
  if (centreLng > 180) centreLng -= 360;
  if (centreLng < -180) centreLng += 360;
  return AreaCell(_round6(centreLat), _round6(centreLng));
}
