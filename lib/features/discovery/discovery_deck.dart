import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../domain/conversation_access_policy.dart';
import '../../domain/demo_profile.dart';
import '../../domain/discovery_interaction.dart';
import '../../domain/discovery_preferences.dart';
import '../../domain/local_like_event.dart';
import '../../domain/match_reason.dart';
import '../../domain/safety_report.dart';
import '../../theme/vawra_theme.dart';
import '../shared/profile_image.dart';
import 'swipe_card_stack.dart';

/// The swipe card never gets wider than this, however wide the screen.
const maxCardWidth = 560.0;

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
    this.canUndo = false,
    this.onUndo,
    this.focusProfileAsset,
    this.onShowPassedAgain,
    this.superLikesLeft = 0,
    this.showTutorial = false,
    this.onTutorialDone,
    this.title = 'Find your match',
    this.onBack,
    this.extraPhotos = const {},
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

  /// Free undo of the most recent pass. Likes are never undone here.
  final bool canUndo;
  final VoidCallback? onUndo;

  /// A profile to show first, such as one just brought back by undo.
  final String? focusProfileAsset;
  final VoidCallback? onShowPassedAgain;

  /// Free Super Likes left today.
  final int superLikesLeft;

  /// First-visit overlay explaining the three swipe directions.
  final bool showTutorial;
  final VoidCallback? onTutorialDone;

  /// Header title; hub decks use their hub name and show a back arrow.
  final String title;
  final VoidCallback? onBack;

  /// Further photos per profile, keyed by the main portrait's asset path.
  final Map<String, List<String>> extraPhotos;

  List<String> _photosOf(DemoProfile profile) => [
    profile.assetPath,
    ...?extraPhotos[profile.assetPath],
  ];

  @override
  Widget build(BuildContext context) {
    final visibleProfiles = profiles
        .where(
          (profile) => preferences.includes(
            age: profile.age,
            relationshipIntent: profile.intent,
            distanceBand: profile.distanceBand,
          ),
        )
        .where((profile) => !blockedProfileAssets.contains(profile.assetPath))
        .where((profile) => !likedProfiles.containsKey(profile.assetPath))
        .where((profile) => !rejectedProfileAssets.contains(profile.assetPath))
        .toList();
    final focused = visibleProfiles
        .where((p) => p.assetPath == focusProfileAsset)
        .firstOrNull;
    final profile = visibleProfiles.isEmpty
        ? null
        : focused ?? visibleProfiles[profileIndex % visibleProfiles.length];
    final profileReport = profile == null ? null : reports[profile.assetPath];
    final nextProfile = profile == null || visibleProfiles.length < 2
        ? null
        : visibleProfiles[(visibleProfiles.indexOf(profile) + 1) %
              visibleProfiles.length];
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF7F5), Color(0xFFFCFAF8), Color(0xFFF8F6F4)],
        ),
      ),
      child: Padding(
        key: ValueKey(profile?.assetPath ?? 'empty-discovery'),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 10,
          16,
          12,
        ),
        child: LayoutBuilder(
          // Give the portrait all available space after the header and actions.
          builder: (context, constraints) {
            return Column(
              children: [
                _DiscoveryHeader(
                  title: title,
                  onBack: onBack,
                  count: visibleProfiles.length,
                  live: profiles.any((p) => isServerPerson(p.assetPath)),
                  filtersActive: !preferences.isDefault,
                  onPreferences: () => _showPreferences(context),
                  onSafety: onOpenSafety,
                ),
                const SizedBox(height: 14),
                if (profile == null)
                  Expanded(
                    child: SingleChildScrollView(
                      child: _EndOfDeck(
                        filtersActive: !preferences.isDefault,
                        hasPassed: rejectedProfileAssets.isNotEmpty,
                        onPreferences: () => _showPreferences(context),
                        onShowPassedAgain: onShowPassedAgain,
                      ),
                    ),
                  )
                else
                  Expanded(
                    // A card stays card-sized on tablets and open foldables.
                    child: Center(
                      child: SizedBox(
                        width: math.min(constraints.maxWidth, maxCardWidth),
                        height: double.infinity,
                        child: _SwipeArea(
                          key: const Key('discovery-card-gesture'),
                          profile: profile,
                          front: _profileCard(context, profile, profileReport),
                          back: nextProfile == null
                              ? null
                              : _profileCard(
                                  context,
                                  nextProfile,
                                  null,
                                  preview: true,
                                ),
                          superLikesLeft: superLikesLeft,
                          canUndo: canUndo,
                          onUndo: onUndo,
                          onDetails: () => _showProfileDetails(
                            context,
                            profile,
                            profileReport,
                          ),
                          onAction: (action) => onSwipeAction(profile, action),
                          showTutorial: showTutorial,
                          onTutorialDone: onTutorialDone,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The card itself: full photo with name, facts and actions laid over it.
  Widget _profileCard(
    BuildContext context,
    DemoProfile profile,
    DiscoveryProfileReport? profileReport, {
    bool preview = false,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [
        BoxShadow(
          color: Color(0x225A274F),
          blurRadius: 28,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _CardPhotos(
            key: ValueKey('photos-${profile.assetPath}'),
            photos: _photosOf(profile),
            name: profile.name,
            interactive: !preview,
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.5, 1],
                  colors: [
                    Color(0x24000000),
                    Colors.transparent,
                    Color(0xE0000000),
                  ],
                ),
              ),
            ),
          ),
          if (!isServerPerson(profile.assetPath))
            Positioned(
              top: _photosOf(profile).length > 1 ? 34 : 22,
              left: 16,
              right: 64,
              child: const _OverlayPill(
                icon: Icons.science_outlined,
                label: 'PROTOTYPE PROFILE · NOT A REAL PERSON',
              ),
            )
          else if (isDemoPerson(profile.assetPath))
            Positioned(
              key: Key('demo-pill'),
              top: _photosOf(profile).length > 1 ? 34 : 22,
              left: 16,
              right: 64,
              child: const _OverlayPill(
                icon: Icons.science_outlined,
                label: 'TEST PROFILE · NOT A REAL PERSON',
              ),
            ),
          if (profileReport != null)
            Positioned(
              top: _photosOf(profile).length > 1 ? 66 : 52,
              left: 16,
              right: 60,
              child: Tooltip(
                message: isServerPerson(profile.assetPath)
                    ? 'Sent to Vawra safety for review.'
                    : '${profileReport.moderationState.label}. Saved on this device only; no review team is connected.',
                child: _OverlayPill(
                  icon: Icons.flag_outlined,
                  label: 'Report recorded: ${profileReport.reason.label}',
                ),
              ),
            ),
          if (!preview)
            Positioned(
              top: _photosOf(profile).length > 1 ? 30 : 16,
              right: 10,
              child: Material(
                color: Colors.black.withValues(alpha: 0.34),
                shape: const CircleBorder(),
                child: PopupMenuButton<String>(
                  key: const Key('discovery-safety-menu'),
                  tooltip: 'Profile safety actions',
                  iconColor: Colors.white,
                  onSelected: (value) =>
                      _handleSafetyAction(context, profile, value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'report',
                      child: Text('Report privately'),
                    ),
                    PopupMenuItem(value: 'block', child: Text('Block profile')),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 14,
            bottom: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NameAge(
                        name: profile.name,
                        age: profile.age,
                        color: Colors.white,
                        size: 30,
                      ),
                      if (profile is DetailedProfile)
                        if (MatchReason.forCard(profile.reasons)
                            case final reason?) ...[
                          const SizedBox(height: 8),
                          _ReasonPill(
                            key: const Key('card-reason'),
                            text: reason.text,
                          ),
                        ],
                      if (MediaQuery.sizeOf(context).height > 760 &&
                          MediaQuery.textScalerOf(context).scale(1) < 1.5 &&
                          profile.bio.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          profile.bio.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 8),
                            ],
                          ),
                        ),
                      ],
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
                if (!preview)
                  Material(
                    color: Colors.white.withValues(alpha: 0.88),
                    shape: const CircleBorder(),
                    elevation: 0,
                    child: IconButton(
                      key: const Key('open-profile-details'),
                      tooltip: 'View profile details',
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      color: VawraColors.plum,
                      onPressed: () =>
                          _showProfileDetails(context, profile, profileReport),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

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
      // Keeps Pass and Like above three-button navigation.
      child: SafeArea(
        top: false,
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
                  _DetailPhotos(photos: _photosOf(profile), name: profile.name),
                  const SizedBox(height: 12),
                  _DetailSection(
                    icon: Icons.favorite_outline_rounded,
                    title: 'Looking for',
                    child: Text(
                      profile.intent,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                  if (profile is DetailedProfile && profile.gender != null)
                    _DetailSection(
                      key: const Key('detail-gender'),
                      icon: Icons.person_outline_rounded,
                      title: 'Gender',
                      child: Text(
                        profile.gender!.label,
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                  if (profile is DetailedProfile && profile.reasons.isNotEmpty)
                    _DetailSection(
                      key: const Key('detail-reasons'),
                      icon: Icons.auto_awesome_rounded,
                      title: 'Why you might click',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final reason in profile.reasons)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    switch (reason.kind) {
                                      ReasonKind.goal =>
                                        Icons.favorite_outline_rounded,
                                      ReasonKind.interests =>
                                        Icons.auto_awesome_outlined,
                                      ReasonKind.habit => Icons.spa_outlined,
                                    },
                                    size: 18,
                                    color: VawraColors.coral,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(reason.text)),
                                ],
                              ),
                            ),
                          Text(
                            'Vawra orders Discover by what you share. It never '
                            'ranks people by popularity or looks.',
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  if (profile.bio.trim().isNotEmpty)
                    _DetailSection(
                      icon: Icons.format_quote_rounded,
                      title: 'About ${profile.name}',
                      child: Text(
                        profile.bio,
                        style: Theme.of(sheetContext).textTheme.bodyLarge,
                      ),
                    ),
                  if (profile is DetailedProfile)
                    for (final (i, prompt) in profile.prompts.indexed)
                      _DetailSection(
                        key: Key('detail-prompt-$i'),
                        icon: Icons.chat_bubble_outline_rounded,
                        title: prompt.question,
                        child: Text(
                          prompt.answer,
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
                  if (profile is DetailedProfile &&
                      profile.lifestyle.isNotEmpty)
                    _DetailSection(
                      key: const Key('detail-habits'),
                      icon: Icons.spa_outlined,
                      title: 'Habits',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in profile.lifestyle.entries)
                            Chip(
                              label: Text('${entry.key.label}: ${entry.value}'),
                            ),
                        ],
                      ),
                    ),
                  _DetailSection(
                    icon: Icons.near_me_outlined,
                    title: 'Distance',
                    child: Text(
                      isServerPerson(profile.assetPath)
                          ? 'Not shown yet. Vawra never shows an exact location.'
                          : '${profile.distanceBand}. Shown as a band; '
                                'exact location is never shown.',
                    ),
                  ),
                  if (profileReport != null)
                    _DetailSection(
                      icon: Icons.flag_outlined,
                      title: 'Your report',
                      child: Text(
                        isServerPerson(profile.assetPath)
                            ? '${profileReport.reason.label}. Sent to Vawra safety for review.'
                            : '${profileReport.reason.label}. '
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
    ),
  );

  Future<void> _showPreferences(BuildContext context) async {
    var ageRange = RangeValues(
      preferences.minAge.toDouble(),
      preferences.maxAge.toDouble(),
    );
    String? selectedIntent = preferences.intent;
    int? selectedDistance = preferences.maxDistanceKm;
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
                const SizedBox(height: 16),
                Text(
                  'Distance',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const Text(
                  'Uses the distance band only. Nobody\'s location is shared.',
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final km in <int?>[
                      null,
                      ...DiscoveryPreferences.distanceChoices,
                    ])
                      ChoiceChip(
                        key: Key('distance-${km ?? 'any'}'),
                        label: Text(
                          km == null ? 'Any distance' : 'Up to $km km',
                        ),
                        selected: selectedDistance == km,
                        onSelected: (_) =>
                            setSheetState(() => selectedDistance = km),
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
                      maxDistanceKm: selectedDistance,
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
        SnackBar(
          content: Text(
            isServerPerson(profile.assetPath)
                ? 'Report sent privately. ${profile.name} is not told who reported.'
                : 'Report recorded privately. Saved on this device only. No review team is connected.',
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
        content: Text(
          isServerPerson(profile.assetPath)
              ? '${profile.name} will no longer see you or be able to message you, and any match with them closes. They are not told.'
              : 'This removes the prototype profile from discovery and closes any active match for this app session. No real account is contacted.',
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
    required this.title,
    required this.onBack,
    required this.count,
    this.live = false,
    required this.filtersActive,
    required this.onPreferences,
    required this.onSafety,
  });

  final String title;
  final VoidCallback? onBack;
  final int count;
  final bool live;
  final bool filtersActive;
  final VoidCallback onPreferences;
  final VoidCallback onSafety;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onBack != null)
        IconButton(
          key: const Key('hub-back'),
          tooltip: 'Back to Explore',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onBack == null)
              Image.asset(
                'assets/branding/vawra_company_lockup_transparent.png',
                key: const Key('discovery-brand-lockup'),
                semanticLabel: 'Vawra company logo',
                width: 174,
                height: 52,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              )
            else
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                live
                    ? '$count ${count == 1 ? 'person' : 'people'} to meet'
                    : '$count prototype profiles',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: VawraColors.muted,
                  fontSize: 11,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
      _HeaderAction(
        key: const Key('discovery-preferences'),
        tooltip: filtersActive ? 'Edit preferences' : 'Preferences',
        icon: filtersActive ? Icons.tune_rounded : Icons.tune_outlined,
        onPressed: onPreferences,
      ),
      const SizedBox(width: 8),
      _HeaderAction(
        tooltip: 'Safety center',
        icon: Icons.shield_outlined,
        onPressed: onSafety,
      ),
    ],
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.82),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 21, color: VawraColors.ink),
    ),
  );
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: VawraColors.plum),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VawraColors.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: 0.12,
                ),
              ),
            ),
          ],
        ),
      ),
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

class LocalActivityCard extends StatelessWidget {
  const LocalActivityCard({super.key, required this.events});

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

/// The strongest shared thing, as a soft pill on the card photo.
class _ReasonPill extends StatelessWidget {
  const _ReasonPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
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
    super.key,
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

class _EndOfDeck extends StatelessWidget {
  const _EndOfDeck({
    required this.filtersActive,
    required this.hasPassed,
    required this.onPreferences,
    required this.onShowPassedAgain,
  });

  final bool filtersActive;
  final bool hasPassed;
  final VoidCallback onPreferences;
  final VoidCallback? onShowPassedAgain;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('end-of-deck'),
    margin: const EdgeInsets.only(top: 40),
    padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFF0E5EB)),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.travel_explore_rounded,
          size: 48,
          color: VawraColors.coral,
        ),
        const SizedBox(height: 12),
        Text(
          "You've seen everyone for now",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          filtersActive
              ? 'Your preferences are narrowing things down. Widen them to see more people.'
              : 'Check back later, or look again at people you passed.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('end-open-preferences'),
            onPressed: onPreferences,
            child: const Text('Change preferences'),
          ),
        ),
        if (hasPassed && onShowPassedAgain != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('end-show-passed'),
              onPressed: onShowPassedAgain,
              child: const Text('See passed profiles again'),
            ),
          ),
        ],
      ],
    ),
  );
}

/// The card stack plus the action row. Buttons drive the same animations as
/// dragging, so every choice looks and feels the same.
class _SwipeArea extends StatefulWidget {
  const _SwipeArea({
    super.key,
    required this.profile,
    required this.front,
    required this.back,
    required this.superLikesLeft,
    required this.canUndo,
    required this.onUndo,
    required this.onDetails,
    required this.onAction,
    required this.showTutorial,
    required this.onTutorialDone,
  });

  final DemoProfile profile;
  final Widget front;
  final Widget? back;
  final int superLikesLeft;
  final bool canUndo;
  final VoidCallback? onUndo;
  final VoidCallback onDetails;
  final ValueChanged<DiscoverySwipeAction> onAction;
  final bool showTutorial;
  final VoidCallback? onTutorialDone;

  @override
  State<_SwipeArea> createState() => _SwipeAreaState();
}

class _SwipeAreaState extends State<_SwipeArea> {
  final stackKey = GlobalKey<SwipeCardStackState>();

  void _noSuperLikes() => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('No Super Likes left today. You get 3 free every day.'),
      ),
    );

  void _swiped(SwipeDirection direction) => widget.onAction(switch (direction) {
    SwipeDirection.left => DiscoverySwipeAction.reject,
    SwipeDirection.right => DiscoverySwipeAction.like,
    SwipeDirection.up => DiscoverySwipeAction.superLike,
  });

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Column(
        children: [
          Expanded(
            child: SwipeCardStack(
              key: stackKey,
              frontId: widget.profile.assetPath,
              front: widget.front,
              back: widget.back,
              canSwipeUp: widget.superLikesLeft > 0,
              onSwipeUpBlocked: _noSuperLikes,
              onSwiped: _swiped,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final primarySize = math.min(
                64.0,
                (constraints.maxWidth - 38) / 4.4,
              );
              final secondarySize = primarySize * 0.72;
              final superLikeSize = primarySize * 0.78;
              return Container(
                key: const Key('discovery-action-dock'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x215A274F),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.94),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _RoundAction(
                            key: const Key('undo-pass'),
                            tooltip: 'Undo last pass',
                            icon: Icons.undo_rounded,
                            color: VawraColors.muted,
                            size: secondarySize,
                            onPressed: widget.canUndo ? widget.onUndo : null,
                          ),
                          _RoundAction(
                            key: const Key('action-pass'),
                            tooltip: 'Pass',
                            icon: Icons.close_rounded,
                            color: VawraColors.plum,
                            size: primarySize,
                            onPressed: () => stackKey.currentState?.swipe(
                              SwipeDirection.left,
                            ),
                          ),
                          Badge(
                            label: Text('${widget.superLikesLeft}'),
                            backgroundColor: VawraColors.superLike,
                            offset: const Offset(-2, 2),
                            isLabelVisible: widget.superLikesLeft > 0,
                            child: _RoundAction(
                              key: const Key('action-super-like'),
                              tooltip: 'Super Like',
                              icon: Icons.star_rounded,
                              color: VawraColors.superLike,
                              backgroundColor: const Color(0xFFEAF0FF),
                              size: superLikeSize,
                              onPressed: () => stackKey.currentState?.swipe(
                                SwipeDirection.up,
                              ),
                            ),
                          ),
                          _RoundAction(
                            key: const Key('action-like'),
                            tooltip: 'Like',
                            icon: Icons.favorite_rounded,
                            color: VawraColors.coral,
                            size: primarySize,
                            onPressed: () => stackKey.currentState?.swipe(
                              SwipeDirection.right,
                            ),
                          ),
                          _RoundAction(
                            key: const Key('action-details'),
                            tooltip: 'View profile details',
                            icon: Icons.info_outline_rounded,
                            color: VawraColors.muted,
                            size: secondarySize,
                            onPressed: widget.onDetails,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      if (widget.showTutorial)
        Positioned.fill(
          child: _SwipeTutorial(onDone: widget.onTutorialDone ?? () {}),
        ),
    ],
  );
}

/// White circle with a coloured icon that presses in slightly when tapped.
class _RoundAction extends StatefulWidget {
  const _RoundAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.size,
    required this.onPressed,
    this.backgroundColor = const Color(0xFFFDFCFB),
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onPressed;
  final Color backgroundColor;

  @override
  State<_RoundAction> createState() => _RoundActionState();
}

class _RoundActionState extends State<_RoundAction> {
  var pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => pressed = true) : null,
        onTapCancel: () => setState(() => pressed = false),
        onTapUp: (_) => setState(() => pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: pressed ? 0.95 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 110),
          child: Semantics(
            button: true,
            enabled: enabled,
            label: widget.tooltip,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF0E9E8)),
              ),
              child: Icon(
                widget.icon,
                size: widget.size * 0.5,
                color: enabled ? widget.color : const Color(0xFFD5CCD2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeTutorial extends StatelessWidget {
  const _SwipeTutorial({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => ClipRRect(
    key: const Key('swipe-tutorial'),
    borderRadius: BorderRadius.circular(30),
    child: ColoredBox(
      color: const Color(0xD9140C13),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How it works',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 22),
              const _TutorialRow(
                icon: Icons.east_rounded,
                color: VawraColors.coral,
                text: 'Swipe right to like',
              ),
              const _TutorialRow(
                icon: Icons.west_rounded,
                color: Color(0xFFB9AEB6),
                text: 'Swipe left to pass. Nobody is told.',
              ),
              const _TutorialRow(
                icon: Icons.north_rounded,
                color: VawraColors.superLike,
                text: 'Swipe up to Super Like. 3 free every day.',
              ),
              const _TutorialRow(
                icon: Icons.keyboard_arrow_up_rounded,
                color: Colors.white,
                text: 'Tap the arrow to see their whole profile',
              ),
              const SizedBox(height: 22),
              FilledButton(
                key: const Key('swipe-tutorial-done'),
                onPressed: onDone,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TutorialRow extends StatelessWidget {
  const _TutorialRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The card's photos: a segment bar when there is more than one, and taps on
/// the right or left of the photo flip forward or back.
class _CardPhotos extends StatefulWidget {
  const _CardPhotos({
    super.key,
    required this.photos,
    required this.name,
    required this.interactive,
  });

  final List<String> photos;
  final String name;
  final bool interactive;

  @override
  State<_CardPhotos> createState() => _CardPhotosState();
}

class _CardPhotosState extends State<_CardPhotos> {
  var index = 0;

  void _flip(TapUpDetails details, double width) {
    if (widget.photos.length < 2) return;
    setState(() {
      index = details.localPosition.dx > width / 2
          ? (index + 1).clamp(0, widget.photos.length - 1)
          : (index - 1).clamp(0, widget.photos.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: profileImage(widget.photos[index]),
          key: ValueKey(widget.photos[index]),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          gaplessPlayback: true,
          semanticLabel:
              '${portraitLabel(widget.name, widget.photos[index])}, photo ${index + 1} of ${widget.photos.length}',
        ),
        if (widget.interactive && widget.photos.length > 1)
          Positioned.fill(
            bottom: constraints.maxHeight * 0.3,
            child: GestureDetector(
              key: const Key('card-photo-tap'),
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) => _flip(details, constraints.maxWidth),
            ),
          ),
        if (widget.photos.length > 1)
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Row(
              key: const Key('photo-segments'),
              children: [
                for (var i = 0; i < widget.photos.length; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Swipeable photos at the top of the details sheet.
class _DetailPhotos extends StatefulWidget {
  const _DetailPhotos({required this.photos, required this.name});

  final List<String> photos;
  final String name;

  @override
  State<_DetailPhotos> createState() => _DetailPhotosState();
}

class _DetailPhotosState extends State<_DetailPhotos> {
  var page = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: AspectRatio(
          aspectRatio: 0.9,
          child: PageView(
            key: const Key('detail-photos'),
            onPageChanged: (value) => setState(() => page = value),
            children: [
              for (final (i, photo) in widget.photos.indexed)
                Image(
                  image: profileImage(photo),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  semanticLabel:
                      '${portraitLabel(widget.name, photo)}, photo ${i + 1} of ${widget.photos.length}',
                ),
            ],
          ),
        ),
      ),
      if (widget.photos.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.photos.length; i++)
                Container(
                  width: i == page ? 16 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == page
                        ? VawraColors.coral
                        : const Color(0xFFE2D7DE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}
