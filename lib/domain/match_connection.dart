enum ConnectionStatus { active, unmatched, blocked }

class MatchConnection {
  const MatchConnection({
    required this.matchId,
    required this.peerName,
    required this.peerProfileAssetPath,
    this.status = ConnectionStatus.active,
    this.currentUserCallReady = false,
    this.peerCallReady = false,
    this.reported = false,
  });

  factory MatchConnection.syntheticMutualLike({
    required String profileAssetPath,
    required String peerName,
    bool peerCallReady = false,
  }) => MatchConnection(
    matchId: 'synthetic-mutual-${profileAssetPath.hashCode}',
    peerName: peerName,
    peerProfileAssetPath: profileAssetPath,
    peerCallReady: peerCallReady,
  );

  final String matchId;
  final String peerName;
  final String peerProfileAssetPath;
  final ConnectionStatus status;
  final bool currentUserCallReady;
  final bool peerCallReady;
  final bool reported;

  bool get isActive => status == ConnectionStatus.active;
  bool get canMessage => isActive;
  bool get canRequestCall => isActive && currentUserCallReady && peerCallReady;

  MatchConnection setCurrentUserCallReady(bool value) {
    if (!isActive) return this;
    return _copy(currentUserCallReady: value);
  }

  MatchConnection setPeerCallReady(bool value) {
    if (!isActive) return this;
    return _copy(peerCallReady: value);
  }

  MatchConnection report() => _copy(reported: true);

  MatchConnection unmatch() => _copy(
    status: ConnectionStatus.unmatched,
    currentUserCallReady: false,
    peerCallReady: false,
  );

  MatchConnection block() => _copy(
    status: ConnectionStatus.blocked,
    currentUserCallReady: false,
    peerCallReady: false,
  );

  MatchConnection _copy({
    ConnectionStatus? status,
    bool? currentUserCallReady,
    bool? peerCallReady,
    bool? reported,
  }) => MatchConnection(
    matchId: matchId,
    peerName: peerName,
    peerProfileAssetPath: peerProfileAssetPath,
    status: status ?? this.status,
    currentUserCallReady: currentUserCallReady ?? this.currentUserCallReady,
    peerCallReady: peerCallReady ?? this.peerCallReady,
    reported: reported ?? this.reported,
  );
}
