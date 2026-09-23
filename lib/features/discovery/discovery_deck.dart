import 'package:flutter/material.dart';

import '../../domain/conversation_access_policy.dart';
import '../../domain/demo_profile.dart';
import '../../domain/discovery_interaction.dart';
import '../../domain/discovery_preferences.dart';
import '../../domain/local_like_event.dart';
import '../../domain/safety_report.dart';
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${visibleProfiles.length} prototype profiles',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            OutlinedButton.icon(
              key: const Key('discovery-preferences'),
              onPressed: () => _showPreferences(context),
              icon: const Icon(Icons.tune),
              label: Text(
                preferences.isDefault ? 'Preferences' : 'Edit preferences',
              ),
            ),
          ],
        ),
        if (likeEvents.isNotEmpty) ...[
          _LocalActivityCard(events: likeEvents.take(3).toList()),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        if (profile == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: EmptyTab(
              icon: Icons.search_off,
              title: 'No prototype profiles in this range',
              message:
                  'Try a wider age range or include both relationship intents.',
            ),
          ),
        if (profile != null) ...[
          const Text(
            'PROTOTYPE PROFILE · NOT A REAL PERSON',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          _SwipeGestureSurface(
            key: const Key('discovery-card-gesture'),
            onSwipe: (action) => onSwipeAction(profile, action),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 380,
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
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Material(
                            color: Theme.of(context).colorScheme.surface
                                .withValues(alpha: 0.92),
                            shape: const CircleBorder(),
                            child: PopupMenuButton<String>(
                              key: const Key('discovery-safety-menu'),
                              tooltip: 'Profile safety actions',
                              onSelected: (value) =>
                                  _handleSafetyAction(context, profile, value),
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
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile.name}, ${profile.age}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.background == null
                              ? '${profile.intent} · ${profile.distanceBand}'
                              : '${profile.background} · ${profile.intent} · ${profile.distanceBand}',
                        ),
                        const SizedBox(height: 12),
                        const _SwipeGuide(),
                        const SizedBox(height: 12),
                        const _ConversationAccessPreview(),
                        if (profileReport != null) ...[
                          const SizedBox(height: 12),
                          Card(
                            color: const Color(0xFFFFF1D6),
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.flag_outlined),
                              title: Text(
                                'Report recorded: ${profileReport.reason.label}',
                              ),
                              subtitle: Text(
                                '${profileReport.moderationState.label}. Saved in this device session only. No review team is connected.',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          profile.bio,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          children: profile.interests
                              .map((item) => Chip(label: Text(item)))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Icon(Icons.lock_outline, size: 17),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Exact location and precise distance are never shown.',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Reject',
                iconSize: 32,
                onPressed: () =>
                    onSwipeAction(profile, DiscoverySwipeAction.reject),
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 24),
              IconButton.filledTonal(
                tooltip: 'Next profile',
                iconSize: 32,
                onPressed: () =>
                    onSwipeAction(profile, DiscoverySwipeAction.skip),
                icon: const Icon(Icons.arrow_forward),
              ),
              const SizedBox(width: 24),
              IconButton.filled(
                tooltip: 'Like',
                iconSize: 32,
                onPressed: () =>
                    onSwipeAction(profile, DiscoverySwipeAction.like),
                icon: const Icon(Icons.favorite),
              ),
            ],
          ),
        ],
      ],
    );
  }

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
          'This removes the prototype profile from discovery for this app session. No real account is contacted.',
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
      SnackBar(content: Text('${profile.name} removed from discovery.')),
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
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: const [
      _SwipeGuideChip(icon: Icons.keyboard_arrow_up, label: 'Like'),
      _SwipeGuideChip(icon: Icons.keyboard_arrow_left, label: 'Reject'),
      _SwipeGuideChip(icon: Icons.keyboard_arrow_right, label: 'Next'),
    ],
  );
}

class _SwipeGestureSurface extends StatefulWidget {
  const _SwipeGestureSurface({
    super.key,
    required this.child,
    required this.onSwipe,
  });

  final Widget child;
  final ValueChanged<DiscoverySwipeAction> onSwipe;

  @override
  State<_SwipeGestureSurface> createState() => _SwipeGestureSurfaceState();
}

class _SwipeGestureSurfaceState extends State<_SwipeGestureSurface> {
  Offset? startPosition;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) => startPosition = event.position,
    onPointerUp: (event) {
      final start = startPosition;
      startPosition = null;
      if (start == null) return;
      final delta = event.position - start;
      final action = _actionForDelta(delta);
      if (action != null) widget.onSwipe(action);
    },
    child: widget.child,
  );

  DiscoverySwipeAction? _actionForDelta(Offset delta) {
    const threshold = 80;
    if (delta.dy < -threshold && delta.dy.abs() > delta.dx.abs()) {
      return DiscoverySwipeAction.like;
    }
    if (delta.dx < -threshold && delta.dx.abs() > delta.dy.abs()) {
      return DiscoverySwipeAction.reject;
    }
    if (delta.dx > threshold && delta.dx.abs() > delta.dy.abs()) {
      return DiscoverySwipeAction.skip;
    }
    return null;
  }
}

class _SwipeGuideChip extends StatelessWidget {
  const _SwipeGuideChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 18), label: Text(label));
}

class _ConversationAccessPreview extends StatelessWidget {
  const _ConversationAccessPreview();

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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection rules',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(likedPolicy.prototypeSummary),
            const SizedBox(height: 4),
            Text(mutualPolicy.prototypeSummary),
            const SizedBox(height: 4),
            Text(premiumPolicy.prototypeSummary),
          ],
        ),
      ),
    );
  }
}
