import 'package:flutter/material.dart';

import '../../domain/explore_hub.dart';
import '../../theme/vawra_theme.dart';

/// Grid of hubs. Each tile shows how many people it currently holds.
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key, required this.counts, required this.onOpen});

  final Map<String, int> counts;
  final ValueChanged<ExploreHub> onOpen;

  static const _looks = <String, (IconData, List<Color>)>{
    'long-term': (
      Icons.favorite_rounded,
      [Color(0xFFF24F78), Color(0xFF8A346C)],
    ),
    'open': (
      Icons.all_inclusive_rounded,
      [Color(0xFF8A346C), Color(0xFF182465)],
    ),
    'outdoors': (Icons.forest_rounded, [Color(0xFF2E8B6A), Color(0xFF1B4D5C)]),
    'foodies': (
      Icons.ramen_dining_rounded,
      [Color(0xFFF08A3E), Color(0xFFD93663)],
    ),
    'arts': (Icons.palette_rounded, [Color(0xFF7A5AF8), Color(0xFFF24F78)]),
    'music': (Icons.headphones_rounded, [Color(0xFF182465), Color(0xFF4C6FFF)]),
    'books': (
      Icons.auto_stories_rounded,
      [Color(0xFF5A274F), Color(0xFFB2567E)],
    ),
    'travel': (
      Icons.flight_takeoff_rounded,
      [Color(0xFF1F8FBF), Color(0xFF4C6FFF)],
    ),
    'fitness': (
      Icons.directions_run_rounded,
      [Color(0xFFE0A33A), Color(0xFFF24F78)],
    ),
  };

  @override
  Widget build(BuildContext context) => SafeArea(
    child: CustomScrollView(
      key: const Key('explore-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Browse people by what they told us matters to them.',
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          sliver: SliverGrid.builder(
            itemCount: ExploreHub.all.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final hub = ExploreHub.all[index];
              final (icon, colors) = _looks[hub.id]!;
              return _HubTile(
                hub: hub,
                icon: icon,
                colors: colors,
                count: counts[hub.id] ?? 0,
                onTap: () => onOpen(hub),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.hub,
    required this.icon,
    required this.colors,
    required this.count,
    required this.onTap,
  });

  final ExploreHub hub;
  final IconData icon;
  final List<Color> colors;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: InkWell(
        key: Key('hub-${hub.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const Spacer(),
              Text(
                hub.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hub.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count ${count == 1 ? 'person' : 'people'}',
                  style: const TextStyle(
                    color: VawraColors.plum,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
