import '../domain/demo_profile.dart';
import '../domain/match_connection.dart';
import '../domain/safety_report.dart';
import 'discovery_interaction_repository.dart';
import 'match_repository.dart';

class DiscoveryBlockResult {
  const DiscoveryBlockResult({
    required this.currentMatch,
    required this.closedMatchingConnection,
  });

  final MatchConnection? currentMatch;
  final bool closedMatchingConnection;
}

abstract interface class DiscoverySafetyService {
  Map<String, DiscoveryProfileReport> reports();
  void recordReport(DiscoveryProfileReport report);
  DiscoveryBlockResult block(DemoProfile profile);
}

class LocalDiscoverySafetyService implements DiscoverySafetyService {
  LocalDiscoverySafetyService({
    required this.interactionRepository,
    required this.matchRepository,
  });

  final DiscoveryInteractionRepository interactionRepository;
  final MatchRepository matchRepository;
  final Map<String, DiscoveryProfileReport> _reports = {};

  @override
  Map<String, DiscoveryProfileReport> reports() => Map.unmodifiable(_reports);

  @override
  void recordReport(DiscoveryProfileReport report) {
    _reports[report.profileAssetPath] = report;
  }

  @override
  DiscoveryBlockResult block(DemoProfile profile) {
    final before = matchRepository.current();
    interactionRepository.block(profile);
    final current = matchRepository.blockProfile(profile.assetPath);
    return DiscoveryBlockResult(
      currentMatch: current,
      closedMatchingConnection:
          before?.peerProfileAssetPath == profile.assetPath &&
          before?.isActive == true &&
          current?.status == ConnectionStatus.blocked,
    );
  }
}
