import 'package:ember_app/domain/conversation_access_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mutual likes can message without premium', () {
    const policy = ConversationAccessPolicy(
      relationship: LikeRelationship.mutualLike,
    );

    expect(policy.canMessageMutualMatch, isTrue);
    expect(policy.canUsePremiumDirectIntro, isFalse);
    expect(
      policy.prototypeSummary,
      'Mutual likes can connect and message in the free core.',
    );
  });

  test('premium direct intro is separate from mutual-match messaging', () {
    const policy = ConversationAccessPolicy(
      currentUserTier: SubscriptionTier.premium,
    );

    expect(policy.canMessageMutualMatch, isFalse);
    expect(policy.canUsePremiumDirectIntro, isTrue);
    expect(policy.prototypeSummary, contains('future design concept'));
  });
}
