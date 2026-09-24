import 'package:ember_app/data/discovery_interaction_repository.dart';
import 'package:ember_app/data/discovery_safety_service.dart';
import 'package:ember_app/data/match_repository.dart';
import 'package:ember_app/domain/demo_profile.dart';
import 'package:ember_app/domain/match_connection.dart';
import 'package:ember_app/domain/safety_report.dart';
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

  test('report storage is local and exposed as an immutable view', () {
    final service = LocalDiscoverySafetyService(
      interactionRepository: MemoryDiscoveryInteractionRepository(),
      matchRepository: MemoryMatchRepository(),
    );
    final report = DiscoveryProfileReport(
      profileAssetPath: maya.assetPath,
      profileName: maya.name,
      reason: ReportReason.scam,
      createdAt: DateTime.utc(2026, 9, 24),
    );

    service.recordReport(report);

    expect(service.reports()[maya.assetPath], same(report));
    expect(() => service.reports().clear(), throwsUnsupportedError);
  });

  test('one block operation closes discovery and the matching connection', () {
    final interactions = MemoryDiscoveryInteractionRepository();
    final matches = MemoryMatchRepository(
      incomingLikeProfileAssets: {maya.assetPath},
    )..createMutualLike(maya);
    final service = LocalDiscoverySafetyService(
      interactionRepository: interactions,
      matchRepository: matches,
    );

    final result = service.block(maya);

    expect(interactions.blockedProfileAssets(), contains(maya.assetPath));
    expect(result.closedMatchingConnection, isTrue);
    expect(result.currentMatch?.status, ConnectionStatus.blocked);
    expect(result.currentMatch?.canMessage, isFalse);
    expect(result.currentMatch?.canRequestCall, isFalse);
  });

  test('blocking an unrelated profile preserves the active match', () {
    const other = DemoProfile(
      'Elena',
      32,
      'Long-term relationship',
      '5–10 km away',
      'Bookshop regular.',
      ['Books'],
      'assets/profiles/elena.png',
    );
    final interactions = MemoryDiscoveryInteractionRepository();
    final matches = MemoryMatchRepository(
      incomingLikeProfileAssets: {maya.assetPath},
    )..createMutualLike(maya);
    final service = LocalDiscoverySafetyService(
      interactionRepository: interactions,
      matchRepository: matches,
    );

    final result = service.block(other);

    expect(interactions.blockedProfileAssets(), contains(other.assetPath));
    expect(result.closedMatchingConnection, isFalse);
    expect(result.currentMatch?.isActive, isTrue);
  });
}
