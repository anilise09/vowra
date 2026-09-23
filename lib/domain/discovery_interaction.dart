enum DiscoverySwipeAction { like, reject, skip }

extension DiscoverySwipeActionLabel on DiscoverySwipeAction {
  String get label => switch (this) {
    DiscoverySwipeAction.like => 'Like',
    DiscoverySwipeAction.reject => 'Reject',
    DiscoverySwipeAction.skip => 'Next',
  };
}

class LikedProfile {
  const LikedProfile({
    required this.profileAssetPath,
    required this.profileName,
    required this.createdAt,
  });

  final String profileAssetPath;
  final String profileName;
  final DateTime createdAt;
}
