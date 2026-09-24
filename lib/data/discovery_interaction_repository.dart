import '../domain/demo_profile.dart';
import '../domain/discovery_interaction.dart';
import '../domain/local_like_event.dart';

abstract interface class DiscoveryInteractionRepository {
  Map<String, LikedProfile> likedProfiles();
  Set<String> rejectedProfileAssets();
  Set<String> blockedProfileAssets();
  List<LocalLikeEvent> likeEvents();

  bool recordLike(
    DemoProfile profile, {
    required DateTime createdAt,
    required bool mutualLike,
  });
  void reject(DemoProfile profile);
  void block(DemoProfile profile);
}

class MemoryDiscoveryInteractionRepository
    implements DiscoveryInteractionRepository {
  final Map<String, LikedProfile> _likedProfiles = {};
  final Set<String> _rejectedProfileAssets = {};
  final Set<String> _blockedProfileAssets = {};
  final List<LocalLikeEvent> _likeEvents = [];

  @override
  Map<String, LikedProfile> likedProfiles() => Map.unmodifiable(_likedProfiles);

  @override
  Set<String> rejectedProfileAssets() =>
      Set.unmodifiable(_rejectedProfileAssets);

  @override
  Set<String> blockedProfileAssets() => Set.unmodifiable(_blockedProfileAssets);

  @override
  List<LocalLikeEvent> likeEvents() => List.unmodifiable(_likeEvents);

  @override
  bool recordLike(
    DemoProfile profile, {
    required DateTime createdAt,
    required bool mutualLike,
  }) {
    if (_likedProfiles.containsKey(profile.assetPath) ||
        _blockedProfileAssets.contains(profile.assetPath) ||
        _rejectedProfileAssets.contains(profile.assetPath)) {
      return false;
    }
    _likedProfiles[profile.assetPath] = LikedProfile(
      profileAssetPath: profile.assetPath,
      profileName: profile.name,
      createdAt: createdAt,
    );
    _likeEvents.insertAll(
      0,
      localLikeEventsFor(
        profileAssetPath: profile.assetPath,
        profileName: profile.name,
        createdAt: createdAt,
        mutualLike: mutualLike,
      ),
    );
    return true;
  }

  @override
  void reject(DemoProfile profile) {
    if (!_likedProfiles.containsKey(profile.assetPath) &&
        !_blockedProfileAssets.contains(profile.assetPath)) {
      _rejectedProfileAssets.add(profile.assetPath);
    }
  }

  @override
  void block(DemoProfile profile) {
    _blockedProfileAssets.add(profile.assetPath);
  }
}
