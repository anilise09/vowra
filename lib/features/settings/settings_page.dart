import 'package:flutter/material.dart';

import '../../theme/vawra_theme.dart';

/// Settings grouped by purpose. Pausing, safety and deletion are free and
/// never hidden behind a subscription.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.paused,
    required this.onPausedChanged,
    required this.onOpenSafetyGuide,
    required this.onOpenSafetyCenter,
    required this.onDeleteProfile,
    this.notifications = const {},
    this.onNotificationChanged,
    this.travelCity,
    this.onTravelCityChanged,
    this.onSignOut,
    this.shareReadReceipts,
    this.onShareReadReceiptsChanged,
    this.onDownloadData,
    this.areaOn,
    this.areaHiddenHere = false,
    this.onArea,
    this.onModeration,
  });

  /// Only for moderators: reviewing reports and appeals.
  final VoidCallback? onModeration;

  /// Whether an approximate area is set; null hides the row (prototype).
  final bool? areaOn;

  /// On, but hidden right now at a private place.
  final bool areaHiddenHere;

  /// Opens the area choice; returns whether it is on and hidden here.
  final Future<(bool, bool)> Function()? onArea;

  /// A copy of what the server holds; null hides it (prototype).
  final VoidCallback? onDownloadData;

  /// Read receipts and typing; null hides the switch (prototype).
  final bool? shareReadReceipts;
  final ValueChanged<bool>? onShareReadReceiptsChanged;

  /// Present for a signed-in server account; the page then describes what the
  /// server keeps instead of the prototype's in-memory session.
  final VoidCallback? onSignOut;
  bool get live => onSignOut != null;

  /// Notification kinds and whether each is on. Nothing is sent yet; a
  /// signed-in account keeps its choices on the server.
  final Map<String, bool> notifications;
  final void Function(String kind, bool on)? onNotificationChanged;

  /// A city chosen by hand for browsing; null means home. No GPS is used.
  final String? travelCity;
  final ValueChanged<String?>? onTravelCityChanged;

  static const travelCities = [
    'Winnipeg',
    'Toronto',
    'Vancouver',
    'Montreal',
    'Calgary',
    'London',
    'New York',
    'Mumbai',
    'Kathmandu',
    'Sydney',
  ];

  final bool paused;
  final ValueChanged<bool> onPausedChanged;
  final VoidCallback onOpenSafetyGuide;
  final VoidCallback onOpenSafetyCenter;
  final VoidCallback onDeleteProfile;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool paused = widget.paused;
  late final notifications = {...widget.notifications};
  late String? travelCity = widget.travelCity;
  late bool? shareReadReceipts = widget.shareReadReceipts;
  late bool? areaOn = widget.areaOn;
  late bool areaHiddenHere = widget.areaHiddenHere;

  Future<void> _pickCity() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          key: const Key('travel-picker'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              'Browse in another city',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const Text(
              'Chosen by you, never from GPS. Prototype: the sample profiles '
              'stay the same for now.',
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('travel-home'),
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home (turn travel mode off)'),
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
            for (final city in SettingsPage.travelCities)
              ListTile(
                key: Key('travel-$city'),
                leading: const Icon(Icons.location_city_outlined),
                title: Text(city),
                trailing: travelCity == city
                    ? const Icon(Icons.check_rounded, color: VawraColors.coral)
                    : null,
                onTap: () => Navigator.pop(sheetContext, city),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final city = choice.isEmpty ? null : choice;
    setState(() => travelCity = city);
    widget.onTravelCityChanged?.call(city);
  }

  void _setPaused(bool value) {
    setState(() => paused = value);
    widget.onPausedChanged(value);
  }

  Future<void> _confirmDelete() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('delete-dialog'),
        title: Text(
          widget.live ? 'Delete your account?' : 'Delete your profile?',
        ),
        content: Text(
          widget.live
              ? 'Your profile, likes, matches and chats are deleted from '
                    'Vawra after a waiting period, and the next screen shows '
                    'the date. From now until then nobody can see or message '
                    'you, and signing back in lets you keep your account. You '
                    'may be asked to confirm with a code sent to your email.'
                    '\n\nOnly need a break? Pausing hides you from Discover '
                    'and keeps everything.'
              : 'This removes your profile, likes, matches and chats from this '
                    'device straight away. It cannot be undone.\n\n'
                    'Only need a break? Pausing hides you from Discover and keeps '
                    'everything.',
        ),
        actions: [
          if (!paused)
            TextButton(
              key: const Key('delete-pause-instead'),
              onPressed: () => Navigator.pop(dialogContext, 'pause'),
              child: const Text('Pause instead'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: VawraColors.coralDark,
            ),
            onPressed: () => Navigator.pop(dialogContext, 'delete'),
            child: Text(widget.live ? 'Continue' : 'Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'pause':
        _setPaused(true);
      case 'delete':
        widget.onDeleteProfile();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      key: const Key('settings-scroll'),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
      children: [
        const _Heading('Discover'),
        _Group(
          children: [
            SwitchListTile(
              key: const Key('settings-show-me'),
              title: const Text('Show me on Discover'),
              subtitle: Text(
                paused
                    ? 'Paused. New people will not see you. Your matches can still message you.'
                    : 'Turn off to take a break. Free, and you keep everything.',
              ),
              value: !paused,
              onChanged: (value) => _setPaused(!value),
            ),
            if (areaOn case final on?)
              _Row(
                key: const Key('settings-area'),
                icon: Icons.near_me_outlined,
                title: on ? 'Distance: on' : 'Distance: off',
                subtitle: !on
                    ? 'Distances stay hidden. Your location is not used.'
                    : areaHiddenHere
                    ? 'Hidden right now: you\u2019re at a private place.'
                    : 'From your approximate area, about 2 km across.',
                onTap: () async {
                  final (now, hidden) = await widget.onArea!();
                  if (mounted) {
                    setState(() {
                      areaOn = now;
                      areaHiddenHere = hidden;
                    });
                  }
                },
              ),
            if (widget.onTravelCityChanged != null)
              _Row(
                key: const Key('settings-travel'),
                icon: Icons.flight_takeoff_rounded,
                title: travelCity == null
                    ? 'Travel mode: off'
                    : 'Travel mode: $travelCity',
                onTap: _pickCity,
              ),
          ],
        ),
        if (shareReadReceipts case final share?) ...[
          const _Heading('Chats'),
          _Group(
            children: [
              SwitchListTile(
                key: const Key('settings-read-receipts'),
                title: const Text('Read receipts and typing'),
                subtitle: const Text(
                  'Show when you have read a message and when you are typing. '
                  'It only works when both of you turn it on, and it is '
                  'always free.',
                ),
                value: share,
                onChanged: (on) {
                  setState(() => shareReadReceipts = on);
                  widget.onShareReadReceiptsChanged?.call(on);
                },
              ),
            ],
          ),
        ],
        const _Heading('Notifications'),
        _Group(
          children: [
            for (final entry in notifications.entries)
              SwitchListTile(
                key: Key('notify-${entry.key}'),
                title: Text(entry.key),
                value: entry.value,
                onChanged: (on) {
                  setState(() => notifications[entry.key] = on);
                  widget.onNotificationChanged?.call(entry.key, on);
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Nothing is sent yet'),
              subtitle: Text(
                widget.live
                    ? 'Vawra\'s notifications aren\'t switched on yet. Your '
                          'choices are saved to your account and apply as '
                          'soon as they are.'
                    : 'This prototype has no notification service. Your '
                          'choices are kept and will apply when '
                          'notifications arrive.',
              ),
            ),
          ],
        ),
        const _Heading('Safety'),
        _Group(
          children: [
            _Row(
              key: const Key('settings-safety-guide'),
              icon: Icons.shield_outlined,
              title: 'Date safely guide',
              onTap: widget.onOpenSafetyGuide,
            ),
            _Row(
              icon: Icons.health_and_safety_outlined,
              title: 'Safety center',
              onTap: widget.onOpenSafetyCenter,
            ),
            if (widget.onModeration case final open?)
              _Row(
                key: const Key('settings-moderation'),
                icon: Icons.gavel_rounded,
                title: 'Moderation',
                subtitle: 'Review reports and appeals.',
                onTap: open,
              ),
          ],
        ),
        const _Heading('Privacy'),
        if (widget.live)
          _Group(
            children: [
              const ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: Text('What Vawra keeps'),
                subtitle: Text(
                  'Your profile, likes, matches and messages are stored on '
                  'the Vawra server so they reach the people you match. Your '
                  'email is stored encrypted. Vawra does not collect your '
                  'location.',
                ),
              ),
              if (widget.onDownloadData case final download?)
                _Row(
                  key: const Key('settings-export'),
                  icon: Icons.download_rounded,
                  title: 'Download a copy of your data',
                  onTap: download,
                ),
            ],
          )
        else
          const _Group(
            children: [
              ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: Text('What this prototype keeps'),
                subtitle: Text(
                  'Everything stays in this device\'s memory and is gone when '
                  'the app closes. Nothing is uploaded. Others only ever see a '
                  'distance band, never your location.',
                ),
              ),
            ],
          ),
        const _Heading('Account'),
        _Group(
          children: [
            _Row(
              key: const Key('settings-delete'),
              icon: Icons.delete_outline_rounded,
              title: 'Delete profile',
              destructive: true,
              onTap: _confirmDelete,
            ),
            if (widget.onSignOut case final signOut?)
              _Row(
                key: const Key('settings-sign-out'),
                icon: Icons.logout_rounded,
                title: 'Sign out',
                onTap: signOut,
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          widget.live
              ? 'Vawra · matching, messaging, blocking and reporting are always free'
              : 'Vawra prototype · matching, messaging, blocking and reporting are always free',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: VawraColors.muted),
        ),
      ],
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xFFF0E5EB)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
          children[i],
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? VawraColors.coralDark : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
