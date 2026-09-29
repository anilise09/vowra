import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/location_grid.dart';

/// Distance choices kept only on this phone: whether distance is wanted, and
/// private places (such as home) where it is always hidden. The server never
/// learns where the private places are.
class AreaPrefs {
  const AreaPrefs({this.wanted, this.zones = const []});

  /// Null before the person ever chose.
  final bool? wanted;
  final List<AreaCell> zones;

  static const maxZones = 3;

  /// Distance stays hidden within this distance of a private place.
  static const zoneKm = 3.0;

  AreaPrefs copyWith({bool? wanted, List<AreaCell>? zones}) =>
      AreaPrefs(wanted: wanted ?? this.wanted, zones: zones ?? this.zones);

  bool isPrivate(AreaCell cell) =>
      zones.any((zone) => distanceKm(zone, cell) <= zoneKm);
}

double distanceKm(AreaCell a, AreaCell b) {
  const rad = math.pi / 180;
  final dLat = (b.lat - a.lat) * rad;
  final dLng = (b.lng - a.lng) * rad;
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.lat * rad) *
          math.cos(b.lat * rad) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * 6371 * math.asin(math.min(1, math.sqrt(h)));
}

abstract interface class AreaPrefsStore {
  Future<AreaPrefs> load();
  Future<void> save(AreaPrefs prefs);
}

/// Encrypted on the phone (Keystore / Keychain).
class SecureAreaPrefsStore implements AreaPrefsStore {
  const SecureAreaPrefsStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'vawra.area_prefs';

  @override
  Future<AreaPrefs> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return const AreaPrefs();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AreaPrefs(
        wanted: json['wanted'] as bool?,
        zones: [
          for (final z in (json['zones'] as List?) ?? const [])
            AreaCell(
              ((z as Map)['lat'] as num).toDouble(),
              (z['lng'] as num).toDouble(),
            ),
        ],
      );
    } catch (_) {
      return const AreaPrefs();
    }
  }

  @override
  Future<void> save(AreaPrefs prefs) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'wanted': prefs.wanted,
          'zones': [
            for (final z in prefs.zones) {'lat': z.lat, 'lng': z.lng},
          ],
        }),
      );
    } catch (_) {}
  }
}

class MemoryAreaPrefsStore implements AreaPrefsStore {
  AreaPrefs prefs = const AreaPrefs();

  @override
  Future<AreaPrefs> load() async => prefs;

  @override
  Future<void> save(AreaPrefs value) async => prefs = value;
}

/// Replaced in tests.
AreaPrefsStore areaPrefsStore = const SecureAreaPrefsStore();
