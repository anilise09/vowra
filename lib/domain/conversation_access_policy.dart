enum SubscriptionTier { none, premium }

enum LikeRelationship { none, currentUserLiked, mutualLike }

class ConversationAccessPolicy {
  const ConversationAccessPolicy({
    this.currentUserTier = SubscriptionTier.none,
    this.relationship = LikeRelationship.none,
  });

  final SubscriptionTier currentUserTier;
  final LikeRelationship relationship;

  bool get canMessageMutualMatch => relationship == LikeRelationship.mutualLike;

  bool get canUsePremiumDirectIntro =>
      currentUserTier == SubscriptionTier.premium &&
      relationship != LikeRelationship.mutualLike;

  String get prototypeSummary {
    if (canMessageMutualMatch) {
      return 'Mutual likes can connect and message in the free core.';
    }
    if (canUsePremiumDirectIntro) {
      return 'Premium direct intros are a future design concept; this prototype still uses local synthetic profiles.';
    }
    if (relationship == LikeRelationship.currentUserLiked) {
      return 'Like saved locally. A real launch would notify this person and wait for a mutual like.';
    }
    return 'Swipe up to like, left to reject, or right to see the next profile.';
  }
}
