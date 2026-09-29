import 'package:flutter/material.dart';

import '../data/api/vawra_api.dart';
import '../data/area_locator.dart';
import '../data/area_prefs.dart';
import '../domain/location_grid.dart';
import '../theme/vawra_theme.dart';

/// Turns distance on or off, and manages private places. On means the
/// phone's approximate area, rounded on the phone to a cell about 2 km
/// across; people only ever see a band. Near a private place nothing is
/// sent at all.
class AreaSheet extends StatefulWidget {
  const AreaSheet({super.key, required this.api, required this.on});

  final VawraApi api;
  final bool on;

  /// Returns whether distance is wanted afterwards.
  static Future<bool> show(
    BuildContext context, {
    required VawraApi api,
    required bool on,
  }) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => AreaSheet(api: api, on: on),
      ) ??
      on;

  @override
  State<AreaSheet> createState() => _AreaSheetState();
}

class _AreaSheetState extends State<AreaSheet> {
  late bool on = widget.on;
  AreaPrefs prefs = const AreaPrefs();
  bool busy = false;
  String? problem;
  String? note;
  bool offerSettings = false;

  @override
  void initState() {
    super.initState();
    areaPrefsStore.load().then((p) {
      if (mounted) setState(() => prefs = p);
    });
  }

  String _problemText(AreaProblem p) => switch (p) {
    AreaProblem.denied =>
      'Vawra didn’t get permission. Everything else still works; '
          'distances stay hidden.',
    AreaProblem.deniedForever =>
      'Location is blocked for Vawra. You can allow “Approximate” '
          'location in the phone’s settings.',
    AreaProblem.serviceOff =>
      'Location is off on this phone. Turn it on in the phone’s '
          'settings, then try again.',
    AreaProblem.unavailable =>
      'Your phone couldn’t find your area just now. Try again in a '
          'moment.',
  };

  Future<AreaCell?> _locate() async {
    final fix = await areaLocator.locate(ask: true);
    if (fix.cell == null && mounted) {
      setState(() {
        busy = false;
        offerSettings = fix.problem == AreaProblem.deniedForever;
        problem = _problemText(fix.problem!);
      });
    }
    return fix.cell;
  }

  void _start() => setState(() {
    busy = true;
    problem = null;
    note = null;
    offerSettings = false;
  });

  Future<void> _useArea() async {
    _start();
    final cell = await _locate();
    if (cell == null) return;
    try {
      // At a private place nothing is sent; distance is hidden until you leave.
      if (prefs.isPrivate(cell)) {
        await widget.api.clearArea();
      } else {
        await widget.api.setArea(cell);
      }
      await areaPrefsStore.save(prefs.copyWith(wanted: true));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        problem = switch (e.code) {
          'slow_down' =>
            'Your area can change once every 15 minutes. Try again a little '
                'later.',
          'implausible_move' =>
            'That is too far from your last area to be right. Try again '
                'later.',
          _ => 'Vawra couldn’t save your area. Try again.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        problem = 'Can’t reach Vawra. Check your connection and try again.';
      });
    }
  }

  Future<void> _turnOff() async {
    _start();
    try {
      await widget.api.clearArea();
      await areaPrefsStore.save(prefs.copyWith(wanted: false));
      if (mounted) Navigator.pop(context, false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        problem = 'Vawra couldn’t turn distance off. Try again.';
      });
    }
  }

  Future<void> _addPlace() async {
    _start();
    final cell = await _locate();
    if (cell == null) return;
    final updated = prefs.copyWith(zones: [...prefs.zones, cell]);
    await areaPrefsStore.save(updated);
    try {
      await widget.api.clearArea();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      prefs = updated;
      busy = false;
      note = 'Added. Your distance is hidden while you’re here.';
    });
  }

  Future<void> _removePlace(int index) async {
    final updated = prefs.copyWith(zones: [...prefs.zones]..removeAt(index));
    await areaPrefsStore.save(updated);
    if (mounted) {
      setState(() {
        prefs = updated;
        note = 'Removed. Distance shows there again from your next visit.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('area-sheet'),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Distance', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'Vawra can show distances such as “5–10 km away”. It '
              'uses your approximate area: your phone rounds its location to '
              'a square about 2 km across before sending it.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            for (final line in const [
              'People only ever see a band, never your area.',
              'Your exact location never leaves your phone.',
              'Turn it off any time; it is removed at once.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1, right: 10),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 20,
                        color: VawraColors.plum,
                      ),
                    ),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
            if (problem case final text?) ...[
              const SizedBox(height: 6),
              Container(
                key: const Key('area-problem'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VawraColors.blush,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(text),
              ),
              if (offerSettings)
                TextButton(
                  key: const Key('area-open-settings'),
                  onPressed: areaLocator.openSettings,
                  child: const Text('Open phone settings'),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('area-on'),
              onPressed: busy ? null : _useArea,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.near_me_rounded),
              label: Text(on ? 'Update my area' : 'Use my approximate area'),
            ),
            if (on) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('area-off'),
                onPressed: busy ? null : _turnOff,
                child: const Text('Turn distance off'),
              ),
              const SizedBox(height: 22),
              Text('Private places', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text(
                'Your distance is hidden whenever you’re within about 3 km '
                'of a private place, such as home. Private places are kept '
                'only on this phone.',
              ),
              const SizedBox(height: 8),
              for (final (i, _) in prefs.zones.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.home_outlined),
                  title: Text('Private place ${i + 1}'),
                  trailing: TextButton(
                    key: Key('area-zone-remove-$i'),
                    onPressed: busy ? null : () => _removePlace(i),
                    child: const Text('Remove'),
                  ),
                ),
              if (prefs.zones.length < AreaPrefs.maxZones)
                OutlinedButton.icon(
                  key: const Key('area-zone-add'),
                  onPressed: busy ? null : _addPlace,
                  icon: const Icon(Icons.add_home_outlined),
                  label: const Text('Hide my distance at this place'),
                ),
              if (note case final text?)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(text, key: const Key('area-note')),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
