import 'package:ember_app/domain/location_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rounds exactly as the server does', () {
    // Expected values printed by backend/src/location.ts for the same points.
    const cases = [
      (49.8951, -97.1384, AreaCell(49.887, -97.124437)),
      (27.7172, 85.324, AreaCell(27.711, 85.323198)),
      (-33.8688, 151.2093, AreaCell(-33.867, 151.215165)),
      (0.0001, -0.0001, AreaCell(0.009, -0.009)),
      (64.1466, -21.9426, AreaCell(64.143, -21.936293)),
      (-54.8019, -68.303, AreaCell(-54.801, -68.309797)),
      (51.5074, 179.999, AreaCell(51.507, -179.99104)),
      (37.7749, -122.4194, AreaCell(37.773, -122.410987)),
    ];
    for (final (lat, lng, cell) in cases) {
      expect(snapToCell(lat, lng), cell, reason: '$lat, $lng');
    }
  });

  test('a centre rounds to itself, so the server keeps the same cell', () {
    for (final (lat, lng) in [(49.8951, -97.1384), (-33.8688, 151.2093)]) {
      final cell = snapToCell(lat, lng);
      expect(snapToCell(cell.lat, cell.lng), cell);
    }
  });
}
