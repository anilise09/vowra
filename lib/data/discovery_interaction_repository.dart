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
    bool superLike = false,
  });
  void reject(DemoProfile profile);
  void block(DemoProfile profile);

  /// Brings back the most recent pass (never a like). Returns its asset path.
  String? undoLastRejection();

  /// Lets every passed profile appear again.
  void clearRejections();
}

class MemoryDiscoveryInteractionRepository
    implements DiscoveryInteractionRepository {
  final Map<String, LikedProfile> _likedProfiles = {};
  final Set<String> _rejectedProfileAssets = {};
  final List<String> _rejectionOrder = [];
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
    bool superLike = false,
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
      superLike: superLike,
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
      if (_rejectedProfileAssets.add(profile.assetPath)) {
        _rejectionOrder.add(profile.assetPath);
      }
    }
  }

  @override
  String? undoLastRejection() {
    while (_rejectionOrder.isNotEmpty) {
      final asset = _rejectionOrder.removeLast();
      if (_rejectedProfileAssets.remove(asset) &&
          !_blockedProfileAssets.contains(asset)) {
        return asset;
      }
    }
    return null;
  }

  @override
  void clearRejections() {
    _rejectedProfileAssets.clear();
    _rejectionOrder.clear();
  }

  @override
  void block(DemoProfile profile) {
    _blockedProfileAssets.add(profile.assetPath);
  }
}
