import 'package:flutter/material.dart';

import '../../theme/vawra_theme.dart';

/// Honest status of photos plus advice, until the checked upload pipeline exists.
class PhotosCard extends StatelessWidget {
  const PhotosCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('photos-card'),
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
            const Icon(Icons.photo_library_outlined, color: VawraColors.plum),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Photos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Photo upload is coming. Every photo will be checked before anyone '
          'sees it. Until then your card shows your initial.',
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('photo-tips'),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => const PhotoTipsSheet(),
          ),
          icon: const Icon(Icons.lightbulb_outline_rounded),
          label: const Text('Photo tips'),
        ),
      ],
    ),
  );
}

class PhotoTipsSheet extends StatelessWidget {
  const PhotoTipsSheet({super.key});

  static const _do = [
    (
      Icons.face_retouching_natural_outlined,
      'Your face, clearly',
      'Good light, no sunglasses in the first photo.',
    ),
    (
      Icons.accessibility_new_rounded,
      'One that shows all of you',
      'A full-length photo feels honest.',
    ),
    (
      Icons.hiking_rounded,
      'Doing something you love',
      'It gives people an easy first question.',
    ),
    (
      Icons.groups_outlined,
      'At most one group photo',
      'Make it obvious which one is you.',
    ),
  ];

  static const _avoid = [
    (
      Icons.blur_on_rounded,
      'Blurry or far away',
      'If people have to squint, they move on.',
    ),
    (
      Icons.auto_fix_off_outlined,
      'Heavy filters',
      'Look like yourself on the first date.',
    ),
    (Icons.history_rounded, 'Old photos', 'Recent ones build trust.'),
    (
      Icons.person_off_outlined,
      'Other people\'s faces without asking',
      'Crop out or ask first.',
    ),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      key: const Key('photo-tips-sheet'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      children: [
        Text('Photo tips', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 14),
        Text('Works well', style: Theme.of(context).textTheme.titleMedium),
        for (final (icon, title, body) in _do)
          _Tip(icon: icon, title: title, body: body, good: true),
        const SizedBox(height: 10),
        Text('Best avoided', style: Theme.of(context).textTheme.titleMedium),
        for (final (icon, title, body) in _avoid)
          _Tip(icon: icon, title: title, body: body, good: false),
      ],
    ),
  );
}

class _Tip extends StatelessWidget {
  const _Tip({
    required this.icon,
    required this.title,
    required this.body,
    required this.good,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool good;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: good ? VawraColors.blush : const Color(0xFFF3F0F2),
      child: Icon(icon, color: good ? VawraColors.coral : VawraColors.muted),
    ),
    title: Text(title),
    subtitle: Text(body),
  );
}
