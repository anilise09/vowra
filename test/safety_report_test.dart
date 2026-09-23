import 'package:ember_app/domain/safety_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversation reports start in local pending moderation state', () {
    final report = SafetyReport(
      matchId: 'synthetic-match',
      reason: ReportReason.harassment,
      createdAt: DateTime.utc(2026, 9, 22),
    );

    expect(report.moderationState, LocalModerationState.localPending);
    expect(report.moderationState.backendKey, 'local_pending');
    expect(report.moderationState.label, 'Local pending review');
  });

  test('discovery reports use stable moderation backend keys', () {
    final report = DiscoveryProfileReport(
      profileAssetPath: 'assets/profiles/synthetic.png',
      profileName: 'Maya',
      reason: ReportReason.scam,
      createdAt: DateTime.utc(2026, 9, 22),
      moderationState: LocalModerationState.readyForReview,
    );

    expect(report.moderationState.backendKey, 'ready_for_review');
    expect(
      LocalModerationState.values.map((state) => state.backendKey),
      containsAll(<String>[
        'local_pending',
        'ready_for_review',
        'reviewed_no_action',
        'actioned',
      ]),
    );
  });
}
