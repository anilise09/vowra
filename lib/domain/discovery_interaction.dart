enum DiscoverySwipeAction { like, superLike, reject, skip }

extension DiscoverySwipeActionLabel on DiscoverySwipeAction {
  String get label => switch (this) {
    DiscoverySwipeAction.like => 'Like',
    DiscoverySwipeAction.superLike => 'Super Like',
    DiscoverySwipeAction.reject => 'Reject',
    DiscoverySwipeAction.skip => 'Next',
  };
}

class LikedProfile {
  const LikedProfile({
    required this.profileAssetPath,
    required this.profileName,
    required this.createdAt,
    this.superLike = false,
  });

  final String profileAssetPath;
  final String profileName;
  final DateTime createdAt;
  final bool superLike;
}
