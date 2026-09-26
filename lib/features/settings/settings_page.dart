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
  });

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

  void _setPaused(bool value) {
    setState(() => paused = value);
    widget.onPausedChanged(value);
  }

  Future<void> _confirmDelete() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('delete-dialog'),
        title: const Text('Delete your profile?'),
        content: const Text(
          'This removes your profile, likes, matches and chats from this '
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
            child: const Text('Delete'),
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
          ],
        ),
        const _Heading('Privacy'),
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
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Vawra prototype · matching, messaging, blocking and reporting are always free',
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
  });

  final IconData icon;
  final String title;
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
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
