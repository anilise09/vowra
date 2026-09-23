import 'package:ember_app/data/match_repository.dart';
import 'package:ember_app/domain/demo_profile.dart';
import 'package:ember_app/domain/match_connection.dart';
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

  test('creates a match only for profiles with an incoming like', () {
    final repository = MemoryMatchRepository(
      incomingLikeProfileAssets: {maya.assetPath},
    );

    expect(repository.current(), isNull);
    expect(repository.hasIncomingLike(maya), isTrue);

    final match = repository.createMutualLike(maya);
    expect(match.peerName, 'Maya');
    expect(match.peerProfileAssetPath, maya.assetPath);
    expect(match.canMessage, isTrue);
    expect(repository.current(), same(match));
  });

  test('updates preserve block and unmatch invariants', () {
    final repository = MemoryMatchRepository(
      incomingLikeProfileAssets: {maya.assetPath},
    );
    repository.createMutualLike(maya);

    final blocked = repository.update((match) => match.block());
    expect(blocked?.status, ConnectionStatus.blocked);
    expect(blocked?.canMessage, isFalse);
    expect(blocked?.canRequestCall, isFalse);
  });
}
