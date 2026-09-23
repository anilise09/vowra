import '../domain/demo_profile.dart';
import '../domain/match_connection.dart';

abstract interface class MatchRepository {
  MatchConnection? current();
  bool hasIncomingLike(DemoProfile profile);
  MatchConnection createMutualLike(DemoProfile profile);
  MatchConnection? update(
    MatchConnection Function(MatchConnection match) apply,
  );
}

class MemoryMatchRepository implements MatchRepository {
  MemoryMatchRepository({Set<String>? incomingLikeProfileAssets})
    : incomingLikeProfileAssets = incomingLikeProfileAssets ?? const {};

  final Set<String> incomingLikeProfileAssets;
  MatchConnection? _current;

  @override
  MatchConnection? current() => _current;

  @override
  bool hasIncomingLike(DemoProfile profile) =>
      incomingLikeProfileAssets.contains(profile.assetPath);

  @override
  MatchConnection createMutualLike(DemoProfile profile) {
    final existing = _current;
    if (existing != null &&
        existing.peerProfileAssetPath == profile.assetPath &&
        existing.isActive) {
      return existing;
    }
    final match = MatchConnection.syntheticMutualLike(
      profileAssetPath: profile.assetPath,
      peerName: profile.name,
      peerCallReady: true,
    );
    _current = match;
    return match;
  }

  @override
  MatchConnection? update(
    MatchConnection Function(MatchConnection match) apply,
  ) {
    final existing = _current;
    if (existing == null) return null;
    _current = apply(existing);
    return _current;
  }
}
