import 'package:flutter/material.dart';

import '../../theme/vawra_theme.dart';

/// Full-screen moment when a like turns into a match.
class MatchCelebration extends StatelessWidget {
  const MatchCelebration({
    super.key,
    required this.peerName,
    required this.peerPhotoAsset,
    required this.ownInitial,
    required this.superLike,
    required this.onMessage,
  });

  final String peerName;
  final String peerPhotoAsset;
  final String ownInitial;
  final bool superLike;
  final VoidCallback onMessage;

  static Future<void> show(
    BuildContext context, {
    required String peerName,
    required String peerPhotoAsset,
    required String ownInitial,
    required bool superLike,
    required VoidCallback onMessage,
  }) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Match',
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => MatchCelebration(
      peerName: peerName,
      peerPhotoAsset: peerPhotoAsset,
      ownInitial: ownInitial,
      superLike: superLike,
      onMessage: onMessage,
    ),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('match-celebration'),
    color: Colors.transparent,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF2182465), Color(0xF25A274F), Color(0xF2F24F78)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            children: [
              const Spacer(),
              SizedBox(
                height: 150,
                width: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 0,
                      child: _Avatar(
                        child: Text(
                          ownInitial,
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: VawraColors.plum,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: _Avatar(
                        child: Image.asset(
                          peerPhotoAsset,
                          fit: BoxFit.cover,
                          width: 132,
                          height: 132,
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.elasticOut,
                      builder: (_, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Icon(
                          superLike
                              ? Icons.star_rounded
                              : Icons.favorite_rounded,
                          color: superLike
                              ? VawraColors.superLike
                              : VawraColors.coral,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                "It's a match!",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(color: Colors.white, fontSize: 42),
              ),
              const SizedBox(height: 10),
              Text(
                'You and $peerName like each other.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                'Prototype match: $peerName is not a real person.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('match-send-message'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: VawraColors.plum,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onMessage();
                  },
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Send a message'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                key: const Key('match-keep-swiping'),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Keep swiping',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 140,
    height: 140,
    padding: const EdgeInsets.all(4),
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: ClipOval(
      child: ColoredBox(
        color: VawraColors.blush,
        child: Center(child: child),
      ),
    ),
  );
}
