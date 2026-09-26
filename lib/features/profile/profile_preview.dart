import 'package:flutter/material.dart';

import '../../domain/lifestyle.dart';
import '../../domain/user_profile.dart';
import '../../theme/vawra_theme.dart';

/// Shows the person their own card the way others would see it.
class ProfilePreviewSheet extends StatelessWidget {
  const ProfilePreviewSheet({super.key, required this.profile});

  final UserProfile profile;

  static Future<void> show(BuildContext context, UserProfile profile) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: VawraColors.canvas,
        builder: (_) => ProfilePreviewSheet(profile: profile),
      );

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName.trim().isEmpty
        ? 'Your name'
        : profile.displayName.trim();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'How others see you',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  key: const Key('close-preview'),
                  tooltip: 'Close preview',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: const Key('preview-scroll'),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                AspectRatio(
                  aspectRatio: 0.82,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          VawraColors.lavender,
                          VawraColors.blush,
                          Color(0xFFFFD4E3),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 46,
                                backgroundColor: Colors.white,
                                child: Text(
                                  name.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: VawraColors.plum,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 28),
                                child: Text(
                                  'Your photos go here once photo upload is available.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 18,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ', ${profile.age}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontSize: 28,
                                  color: VawraColors.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _Fact(
                                icon: Icons.favorite_outline_rounded,
                                text: profile.intent.label,
                              ),
                              _Fact(
                                icon: Icons.near_me_outlined,
                                text: profile.showDistanceBand
                                    ? 'Distance shown as a band, e.g. "5–10 km away"'
                                    : 'Distance hidden',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (profile.bio.trim().isNotEmpty)
                  _Section(title: 'About $name', child: Text(profile.bio)),
                if (profile.interests.isNotEmpty)
                  _Section(
                    title: 'Interests',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in profile.interests)
                          Chip(label: Text(item)),
                      ],
                    ),
                  ),
                if (profile.lifestyle.isNotEmpty)
                  _Section(
                    title: 'Lifestyle',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final topic in LifestyleTopic.values)
                          if (profile.lifestyle[topic] case final choice?)
                            Chip(label: Text('${topic.label}: $choice')),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Icon(icon, size: 16, color: VawraColors.plum),
        const SizedBox(width: 6),
        Flexible(child: Text(text)),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

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
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: VawraColors.muted),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

/// Optional pieces that make a profile easier to start a conversation with.
class ProfileStrengthCard extends StatelessWidget {
  const ProfileStrengthCard({
    super.key,
    required this.hasIntro,
    required this.interestCount,
    required this.hasLifestyle,
  });

  final bool hasIntro;
  final int interestCount;
  final bool hasLifestyle;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Intro', hasIntro),
      ('3+ interests', interestCount >= 3),
      ('Habits', hasLifestyle),
    ];
    final done = items.where((item) => item.$2).length;
    return Container(
      key: const Key('profile-strength'),
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(
                  'Profile strength',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '$done of ${items.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: VawraColors.coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: done / items.length,
              minHeight: 6,
              color: VawraColors.coral,
              backgroundColor: const Color(0xFFF0E6EB),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, complete) in items)
                Chip(
                  avatar: Icon(
                    complete
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 18,
                    color: complete ? VawraColors.coral : VawraColors.muted,
                  ),
                  label: Text(label),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'All optional: a short intro, three or more interests, and a few habits give matches an easy way to start talking.',
            style: TextStyle(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
