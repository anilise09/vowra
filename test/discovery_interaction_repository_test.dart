import 'package:ember_app/data/discovery_interaction_repository.dart';
import 'package:ember_app/domain/demo_profile.dart';
import 'package:ember_app/domain/local_like_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const maya = DemoProfile(
    'Maya',
    29,
    'Long-term relationship',
    '2–5 km away',
    'Sunday markets, tiny concerts, and ambitious pasta experiments.',
    ['Kindness', 'Live music', 'Cooking'],
    'assets/profiles/maya.png',
  );

  test('records one local like and backend-shaped event sequence', () {
    final repository = MemoryDiscoveryInteractionRepository();
    final createdAt = DateTime.utc(2026, 9, 23, 12);

    expect(
      repository.recordLike(maya, createdAt: createdAt, mutualLike: true),
      isTrue,
    );
    expect(repository.likedProfiles()[maya.assetPath]?.createdAt, createdAt);
    expect(repository.likeEvents().map((event) => event.type), [
      LocalLikeEventType.outboundLike,
      LocalLikeEventType.notificationPreview,
      LocalLikeEventType.mutualLike,
    ]);
    expect(
      repository.recordLike(
        maya,
        createdAt: createdAt.add(const Duration(seconds: 1)),
        mutualLike: true,
      ),
      isFalse,
    );
    expect(repository.likeEvents(), hasLength(3));
  });

  test('rejected and blocked profiles cannot later be liked', () {
    final rejected = MemoryDiscoveryInteractionRepository()..reject(maya);
    final blocked = MemoryDiscoveryInteractionRepository()..block(maya);

    expect(rejected.rejectedProfileAssets(), contains(maya.assetPath));
    expect(blocked.blockedProfileAssets(), contains(maya.assetPath));
    expect(
      rejected.recordLike(
        maya,
        createdAt: DateTime.utc(2026, 9, 23),
        mutualLike: true,
      ),
      isFalse,
    );
    expect(
      blocked.recordLike(
        maya,
        createdAt: DateTime.utc(2026, 9, 23),
        mutualLike: true,
      ),
      isFalse,
    );
    expect(rejected.likeEvents(), isEmpty);
    expect(blocked.likeEvents(), isEmpty);
  });

  test('repository views cannot mutate interaction state', () {
    final repository = MemoryDiscoveryInteractionRepository()..block(maya);

    expect(
      () => repository.blockedProfileAssets().clear(),
      throwsUnsupportedError,
    );
    expect(repository.blockedProfileAssets(), contains(maya.assetPath));
  });
}
