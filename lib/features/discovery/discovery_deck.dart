import 'package:flutter/material.dart';

import '../../domain/conversation_access_policy.dart';
import '../../domain/demo_profile.dart';
import '../../domain/discovery_interaction.dart';
import '../../domain/discovery_preferences.dart';
import '../../domain/local_like_event.dart';
import '../../domain/safety_report.dart';
import '../../theme/vawra_theme.dart';
import '../shared/empty_tab.dart';

class DiscoveryDeck extends StatelessWidget {
  const DiscoveryDeck({
    super.key,
    required this.profiles,
    required this.preferences,
    required this.blockedProfileAssets,
    required this.likedProfiles,
    required this.rejectedProfileAssets,
    required this.reports,
    required this.likeEvents,
    required this.profileIndex,
    required this.onPreferencesChanged,
    required this.onSwipeAction,
    required this.onReport,
    required this.onBlockProfile,
    required this.onOpenSafety,
  });

  final List<DemoProfile> profiles;
  final DiscoveryPreferences preferences;
  final Set<String> blockedProfileAssets;
  final Map<String, LikedProfile> likedProfiles;
  final Set<String> rejectedProfileAssets;
  final Map<String, DiscoveryProfileReport> reports;
  final List<LocalLikeEvent> likeEvents;
  final int profileIndex;
  final ValueChanged<DiscoveryPreferences> onPreferencesChanged;
  final void Function(DemoProfile profile, DiscoverySwipeAction action)
  onSwipeAction;
  final ValueChanged<DiscoveryProfileReport> onReport;
  final ValueChanged<DemoProfile> onBlockProfile;
  final VoidCallback onOpenSafety;

  @override
  Widget build(BuildContext context) {
    final visibleProfiles = profiles
        .where(
          (profile) => preferences.includes(
            age: profile.age,
            relationshipIntent: profile.intent,
          ),
        )
        .where((profile) => !blockedProfileAssets.contains(profile.assetPath))
        .where((profile) => !likedProfiles.containsKey(profile.assetPath))
        .where((profile) => !rejectedProfileAssets.contains(profile.assetPath))
        .toList();
    final profile = visibleProfiles.isEmpty
        ? null
        : visibleProfiles[profileIndex % visibleProfiles.length];
    final profileReport = profile == null ? null : reports[profile.assetPath];
    final photoHeight = (MediaQuery.sizeOf(context).height * 0.66).clamp(
      430.0,
      650.0,
    );
    return SingleChildScrollView(
      key: ValueKey(profile?.assetPath ?? 'empty-discovery'),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 10,
        16,
        28,
      ),
      child: Column(
        children: [
          _DiscoveryHeader(
            count: visibleProfiles.length,
            filtersActive: !preferences.isDefault,
            onPreferences: () => _showPreferences(context),
            onSafety: onOpenSafety,
          ),
          if (visibleProfiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DiscoveryStoryStrip(profiles: visibleProfiles.take(5).toList()),
          ],
          const SizedBox(height: 10),
          if (profile == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: EmptyTab(
                icon: Icons.search_off,
                title: 'No prototype profiles in this range',
                message: 'Try a wider age range or include both relationship intents.',
              ),
            ),
          if (profile != null) ...[
            _SwipeGestureSurface(
              key: const Key('discovery-card-gesture'),
              onSwipe: (action) => onSwipeAction(profile, action),
              onOpenDetails: () =>
                  _showProfileDetails(context, profile, profileReport),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFF0E5EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A5A274F),
                      blurRadius: 32,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(29),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: photoHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              profile.assetPath,
                              key: ValueKey(profile.assetPath),
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              semanticLabel:
                                  'Synthetic portrait of ${profile.name}',
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0, 0.48, 1],
                                  colors: [
                                    Color(0x24000000),
                                    Colors.transparent,
                                    Color(0xD9000000),
                                  ],
                                ),
                              ),
                            ),
                            const Positioned(
                              top: 16,
                              left: 16,
                              child: _OverlayPill(
                                icon: Icons.science_outlined,
                                label: 'PROTOTYPE PROFILE · NOT A REAL PERSON',
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.28),
                                shape: const CircleBorder(),
                                child: PopupMenuButton<String>(
                                  key: const Key('discovery-safety-menu'),
                                  tooltip: 'Profile safety actions',
                                  iconColor: Colors.white,
                                  onSelected: (value) => _handleSafetyAction(
                                    context,
                                    profile,
                                    value,
                                  ),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'report',
                                      child: Text('Report privately'),
                                    ),
                                    PopupMenuItem(
                                      value: 'block',
                                      child: Text('Block profile'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              right: 14,
                              bottom: 18,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _NameAge(
                                          name: profile.name,
                                          age: profile.age,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                        const SizedBox(height: 8),
                                        _CardFact(
                                          icon: Icons.favorite_outline_rounded,
                                          label: profile.intent,
                                        ),
                                        const SizedBox(height: 4),
                                        _CardFact(
                                          icon: Icons.near_me_outlined,
                                          label: profile.distanceBand,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Material(
                                    color: Colors.white,
                                    shape: const CircleBorder(),
                                    elevation: 4,
                                    child: IconButton(
                                      key: const Key('open-profile-details'),
                                      tooltip: 'View profile details',
                                      icon: const Icon(
                                        Icons.keyboard_arrow_up_rounded,
                                      ),
                                      color: VawraColors.plum,
                                      onPressed: () => _showProfileDetails(
                                        context,
                                        profile,
                                        profileReport,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ProfileActionButton(
                              tooltip: 'Pass',
                              icon: Icons.close_rounded,
                              onPressed: () => onSwipeAction(
                                profile,
                                DiscoverySwipeAction.reject,
                              ),
                              foreground: const Color(0xFF5A274F),
                              background: Colors.white,
                            ),
                            const SizedBox(width: 34),
                            _ProfileActionButton(
                              tooltip: 'Like',
                              icon: Icons.favorite_rounded,
                              onPressed: () => onSwipeAction(
                                profile,
                                DiscoverySwipeAction.like,
                              ),
                              foreground: Colors.white,
                              background: const Color(0xFFF24F78),
                              emphasized: true,
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: _SwipeGuide(),
                      ),
                      if (profileReport != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Column(
                            children: [
                              Text(
                                'Report recorded: ${profileReport.reason.label}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'Saved on this device only. No review team is connected.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
            if (likeEvents.isNotEmpty) ...[
              const SizedBox(height: 22),
              _LocalActivityCard(events: likeEvents.take(3).toList()),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _showProfileDetails(
    BuildContext context,
    DemoProfile profile,
    DiscoveryProfileReport? profileReport,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: VawraColors.canvas,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: _NameAge(
                    name: profile.name,
                    age: profile.age,
                    color: VawraColors.ink,
                    size: 24,
                  ),
                ),
                IconButton.filledTonal(
                  key: const Key('close-profile-details'),
                  tooltip: 'Close profile details',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: const Key('profile-details-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: AspectRatio(
                    aspectRatio: 0.9,
                    child: Image.asset(
                      profile.assetPath,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      semanticLabel: 'Synthetic portrait of ${profile.name}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _DetailSection(
                  icon: Icons.favorite_outline_rounded,
                  title: 'Looking for',
                  child: Text(
                    profile.intent,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                _DetailSection(
                  icon: Icons.format_quote_rounded,
                  title: 'About ${profile.name}',
                  child: Text(
                    profile.bio,
                    style: Theme.of(sheetContext).textTheme.bodyLarge,
                  ),
                ),
                _DetailSection(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Interests',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: profile.interests
                        .map((item) => Chip(label: Text(item)))
                        .toList(),
                  ),
                ),
                _DetailSection(
                  icon: Icons.near_me_outlined,
                  title: 'Distance',
                  child: Text(
                    '${profile.distanceBand}. Shown as a band; '
                    'exact location is never shown.',
                  ),
                ),
                if (profileReport != null)
                  _DetailSection(
                    icon: Icons.flag_outlined,
                    title: 'Your report',
                    child: Text(
                      '${profileReport.reason.label}. '
                      '${profileReport.moderationState.label}. '
                      'Saved on this device only; no review team is connected.',
                    ),
                  ),
                const SizedBox(height: 6),
                _SafetyRow(
                  key: const Key('details-block'),
                  label: 'Block ${profile.name}',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleSafetyAction(context, profile, 'block');
                  },
                ),
                _SafetyRow(
                  key: const Key('details-report'),
                  label: 'Report ${profile.name}',
                  destructive: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleSafetyAction(context, profile, 'report');
                  },
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Text(
                    'Blocking and reporting are free and private. '
                    'The other person is never told.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: VawraColors.muted),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ProfileActionButton(
                  tooltip: 'Pass',
                  icon: Icons.close_rounded,
                  foreground: VawraColors.plum,
                  background: Colors.white,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    onSwipeAction(profile, DiscoverySwipeAction.reject);
                  },
                ),
                const SizedBox(width: 38),
                _ProfileActionButton(
                  tooltip: 'Like',
                  icon: Icons.favorite_rounded,
                  foreground: Colors.white,
                  background: VawraColors.coral,
                  emphasized: true,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    onSwipeAction(profile, DiscoverySwipeAction.like);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _showPreferences(BuildContext context) async {
    var ageRange = RangeValues(
      preferences.minAge.toDouble(),
      preferences.maxAge.toDouble(),
    );
    String? selectedIntent = preferences.intent;
    final updated = await showModalBottomSheet<DiscoveryPreferences>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Discovery preferences',
                  style: Theme.of(sheetContext).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Filter synthetic profiles on this device. These choices are not sent to anyone.',
                ),
                const SizedBox(height: 20),
                Text('Age ${ageRange.start.round()}–${ageRange.end.round()}'),
                RangeSlider(
                  key: const Key('age-range'),
                  values: ageRange,
                  min: 18,
                  max: 99,
                  divisions: 81,
                  labels: RangeLabels(
                    '${ageRange.start.round()}',
                    '${ageRange.end.round()}',
                  ),
                  onChanged: (value) => setSheetState(() => ageRange = value),
                ),
                const SizedBox(height: 12),
                Text(
                  'Relationship intent',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final intent in const [
                      null,
                      'Long-term relationship',
                      'Open to long-term',
                    ])
                      ChoiceChip(
                        label: Text(intent ?? 'Any intent'),
                        selected: selectedIntent == intent,
                        onSelected: (_) =>
                            setSheetState(() => selectedIntent = intent),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('apply-discovery-preferences'),
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    DiscoveryPreferences(
                      minAge: ageRange.start.round(),
                      maxAge: ageRange.end.round(),
                      intent: selectedIntent,
                    ),
                  ),
                  child: const Text('Show profiles'),
                ),
                TextButton(
                  key: const Key('reset-discovery-preferences'),
                  onPressed: () =>
                      Navigator.pop(sheetContext, const DiscoveryPreferences()),
                  child: const Text('Reset preferences'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (updated != null && context.mounted) {
      onPreferencesChanged(updated);
    }
  }

  Future<void> _handleSafetyAction(
    BuildContext context,
    DemoProfile profile,
    String action,
  ) async {
    if (action == 'report') {
      final report = await _chooseProfileReport(context, profile);
      if (report == null || !context.mounted) return;
      onReport(report);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report recorded as local pending review on this device only.',
          ),
        ),
      );
      return;
    }
    if (action != 'block') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Block ${profile.name}?'),
        content: const Text(
          'This removes the prototype profile from discovery and closes any active match for this app session. No real account is contacted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-discovery-block'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    onBlockProfile(profile);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${profile.name} blocked locally. Discovery and active contact are closed.',
        ),
      ),
    );
  }

  Future<DiscoveryProfileReport?> _chooseProfileReport(
    BuildContext context,
    DemoProfile profile,
  ) {
    ReportReason? reason;
    return showDialog<DiscoveryProfileReport>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Report ${profile.name} privately'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose the concern. Reporting does not block this profile; you can block separately.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ReportReason>(
                  key: const Key('discovery-report-reason'),
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: ReportReason.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => reason = value),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Prototype only: this starts as local pending review and is not sent to a review team.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('submit-discovery-report'),
              onPressed: reason == null
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      DiscoveryProfileReport(
                        profileAssetPath: profile.assetPath,
                        profileName: profile.name,
                        reason: reason!,
                        createdAt: DateTime.now().toUtc(),
                      ),
                    ),
              child: const Text('Record report'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({
    required this.count,
    required this.filtersActive,
    required this.onPreferences,
    required this.onSafety,
  });

  final int count;
  final bool filtersActive;
  final VoidCallback onPreferences;
  final VoidCallback onSafety;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 48,
        height: 48,
        child: Image.asset(
          'assets/branding/vawra_company_mark_clean.png',
          semanticLabel: 'Vawra logo',
          fit: BoxFit.contain,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find your match',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              '$count prototype profiles',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
      IconButton.filledTonal(
        key: const Key('discovery-preferences'),
        tooltip: filtersActive ? 'Edit preferences' : 'Preferences',
        onPressed: onPreferences,
        icon: Icon(
          filtersActive ? Icons.tune_rounded : Icons.tune_outlined,
          size: 21,
        ),
      ),
      IconButton(
        tooltip: 'Safety center',
        onPressed: onSafety,
        icon: const Icon(Icons.shield_outlined),
      ),
    ],
  );
}

class _DiscoveryStoryStrip extends StatelessWidget {
  const _DiscoveryStoryStrip({required this.profiles});

  final List<DemoProfile> profiles;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 88,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: profiles.length + 1,
      separatorBuilder: (_, _) => const SizedBox(width: 13),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _StoryAvatar(
            label: 'Your story',
            icon: Icons.add_rounded,
          );
        }
        final profile = profiles[index - 1];
        return _StoryAvatar(label: profile.name, assetPath: profile.assetPath);
      },
    ),
  );
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({required this.label, this.assetPath, this.icon});

  final String label;
  final String? assetPath;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 62,
    child: Column(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [VawraColors.coral, Color(0xFFFF9CBE), Color(0xFF182465)],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: assetPath == null
                  ? ColoredBox(
                      color: VawraColors.blush,
                      child: Icon(icon, color: VawraColors.coral),
                    )
                  : Image.asset(assetPath!, fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.15,
          ),
        ),
      ],
    ),
  );
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.foreground,
    required this.background,
    this.emphasized = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color foreground;
  final Color background;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final size = emphasized ? 68.0 : 58.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        elevation: emphasized ? 7 : 2,
        shadowColor: emphasized
            ? const Color(0x66F24F78)
            : const Color(0x225A274F),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, color: foreground, size: emphasized ? 32 : 28),
          ),
        ),
      ),
    );
  }
}

class _LocalActivityCard extends StatelessWidget {
  const _LocalActivityCard({required this.events});

  final List<LocalLikeEvent> events;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Local activity', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          const Text(
            'Prototype only: these are on-device event previews, not real notifications.',
          ),
          const SizedBox(height: 8),
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notifications_none, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(event.summary)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _SwipeGuide extends StatelessWidget {
  const _SwipeGuide();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.swipe_rounded, size: 15, color: Color(0xFF756A72)),
      SizedBox(width: 6),
      Flexible(
        child: Text(
          'Swipe left to pass · right to like · up for details',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: Color(0xFF756A72)),
        ),
      ),
    ],
  );
}

class _SwipeGestureSurface extends StatefulWidget {
  const _SwipeGestureSurface({
    super.key,
    required this.child,
    required this.onSwipe,
    required this.onOpenDetails,
  });

  final Widget child;
  final ValueChanged<DiscoverySwipeAction> onSwipe;
  final VoidCallback onOpenDetails;

  @override
  State<_SwipeGestureSurface> createState() => _SwipeGestureSurfaceState();
}

class _SwipeGestureSurfaceState extends State<_SwipeGestureSurface> {
  Offset? startPosition;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) => startPosition = event.position,
    onPointerCancel: (_) => startPosition = null,
    onPointerUp: (event) {
      final start = startPosition;
      startPosition = null;
      if (start == null) return;
      final delta = event.position - start;
      if (delta.dy < -80 && delta.dy.abs() > delta.dx.abs()) {
        widget.onOpenDetails();
        return;
      }
      final action = _actionForDelta(delta);
      if (action != null) widget.onSwipe(action);
    },
    child: widget.child,
  );

  DiscoverySwipeAction? _actionForDelta(Offset delta) {
    const threshold = 80;
    if (delta.dx < -threshold && delta.dx.abs() > delta.dy.abs()) {
      return DiscoverySwipeAction.reject;
    }
    if (delta.dx > threshold && delta.dx.abs() > delta.dy.abs()) {
      return DiscoverySwipeAction.like;
    }
    return null;
  }
}

class ConversationAccessPreview extends StatelessWidget {
  const ConversationAccessPreview({super.key});

  @override
  Widget build(BuildContext context) {
    const likedPolicy = ConversationAccessPolicy(
      relationship: LikeRelationship.currentUserLiked,
    );
    const mutualPolicy = ConversationAccessPolicy(
      relationship: LikeRelationship.mutualLike,
    );
    const premiumPolicy = ConversationAccessPolicy(
      currentUserTier: SubscriptionTier.premium,
    );
    return Card(
      color: const Color(0xFFF8F4FF),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.forum_outlined,
                    size: 20,
                    color: Color(0xFF5A274F),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Connection, without pressure',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(likedPolicy.prototypeSummary),
            const SizedBox(height: 4),
            Text(mutualPolicy.prototypeSummary),
            const SizedBox(height: 12),
            Text(premiumPolicy.prototypeSummary),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('direct-intro-preview'),
              onPressed: null,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Direct intro — unavailable in prototype'),
            ),
            const SizedBox(height: 7),
            Text(
              'No message is sent and no purchase is offered. Mutual matches can always message for free.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Name in bold with the age lighter; reads as "Name, age".
class _NameAge extends StatelessWidget {
  const _NameAge({
    required this.name,
    required this.age,
    required this.color,
    required this.size,
  });

  final String name;
  final int age;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        TextSpan(
          text: ', $age',
          style: const TextStyle(fontWeight: FontWeight.w400),
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: color,
      fontSize: size,
      height: 1.1,
      letterSpacing: -0.5,
      shadows: color == Colors.white
          ? const [Shadow(color: Colors.black45, blurRadius: 12)]
          : null,
    ),
  );
}

class _CardFact extends StatelessWidget {
  const _CardFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: Colors.white),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
        ),
      ),
    ],
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFF0E5EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: VawraColors.coral),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: VawraColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({
    super.key,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFF0E5EB)),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                color: destructive ? VawraColors.coralDark : VawraColors.ink,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
