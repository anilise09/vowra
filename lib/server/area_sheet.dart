import 'package:flutter/material.dart';

import '../data/api/vawra_api.dart';
import '../data/area_locator.dart';
import '../theme/vawra_theme.dart';

/// Turns distance on or off. On means the phone's approximate area, rounded
/// on the phone to a cell about 2 km across; people only ever see a band.
class AreaSheet extends StatefulWidget {
  const AreaSheet({super.key, required this.api, required this.on});

  final VawraApi api;
  final bool on;

  /// Returns whether distance is on afterwards.
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
  bool busy = false;
  String? problem;
  bool offerSettings = false;

  Future<void> _useArea() async {
    setState(() {
      busy = true;
      problem = null;
      offerSettings = false;
    });
    final fix = await areaLocator.locate(ask: true);
    final cell = fix.cell;
    if (cell == null) {
      if (!mounted) return;
      setState(() {
        busy = false;
        offerSettings = fix.problem == AreaProblem.deniedForever;
        problem = switch (fix.problem!) {
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
      });
      return;
    }
    try {
      await widget.api.setArea(cell);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        problem = switch (e.code) {
          'slow_down' =>
            'Your area can change once every 15 minutes. Try '
                'again a little later.',
          'implausible_move' =>
            'That is too far from your last area to be '
                'right. Try again later.',
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
    setState(() {
      busy = true;
      problem = null;
    });
    try {
      await widget.api.clearArea();
      if (mounted) Navigator.pop(context, false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        problem = 'Vawra couldn’t turn distance off. Try again.';
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
            ],
          ],
        ),
      ),
    );
  }
}
