import 'package:geolocator/geolocator.dart';

import '../domain/location_grid.dart';

/// Why no area could be found.
enum AreaProblem {
  /// Location permission was not given.
  denied,

  /// Permission was refused for good; only the phone's settings can change it.
  deniedForever,

  /// Location is switched off on the phone.
  serviceOff,

  /// The phone could not tell where it is.
  unavailable,
}

class AreaFix {
  const AreaFix.found(AreaCell this.cell) : problem = null;
  const AreaFix.failed(AreaProblem this.problem) : cell = null;

  final AreaCell? cell;
  final AreaProblem? problem;
}

/// The phone's approximate area, already rounded to a cell.
abstract interface class AreaLocator {
  /// With [ask], shows the system permission prompt when needed; without it,
  /// only uses a permission already given.
  Future<AreaFix> locate({required bool ask});

  Future<void> openSettings();
}

/// Coarse location only: Vawra never asks for precise or background location.
class GeolocatorAreaLocator implements AreaLocator {
  const GeolocatorAreaLocator();

  @override
  Future<AreaFix> locate({required bool ask}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const AreaFix.failed(AreaProblem.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const AreaFix.failed(AreaProblem.deniedForever);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const AreaFix.failed(AreaProblem.denied);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return AreaFix.found(snapToCell(position.latitude, position.longitude));
    } catch (_) {
      return const AreaFix.failed(AreaProblem.unavailable);
    }
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}

/// Replaced in tests.
AreaLocator areaLocator = const GeolocatorAreaLocator();
