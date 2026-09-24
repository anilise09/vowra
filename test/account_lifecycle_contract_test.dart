import 'package:ember_app/data/account_lifecycle_api.dart';
import 'package:ember_app/domain/account_lifecycle_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only active lifecycle state permits dating features', () {
    for (final state in AccountLifecycleState.values) {
      final snapshot = AccountLifecycleSnapshot(state: state);
      expect(
        snapshot.mayUseDatingFeatures,
        state == AccountLifecycleState.active,
      );
    }
  });

  test('deletion cancellation follows the server-provided effective time', () {
    final now = DateTime.utc(2026, 9, 24, 12);
    final scheduled = AccountLifecycleSnapshot(
      state: AccountLifecycleState.deletionScheduled,
      deletionEffectiveAt: now.add(const Duration(minutes: 1)),
    );

    expect(scheduled.mayCancelDeletionAt(now), isTrue);
    expect(
      scheduled.mayCancelDeletionAt(now.add(const Duration(minutes: 1))),
      isFalse,
    );
    expect(
      const AccountLifecycleSnapshot(state: AccountLifecycleState.active)
          .mayCancelDeletionAt(now),
      isFalse,
    );
  });

  test('location contract carries encrypted data and redacts it from logs', () {
    final envelope = EncryptedLocationEnvelope(
      ciphertext: 'sensitive-ciphertext',
      keyId: 'location-key-1',
      capturedAt: DateTime.utc(2026, 9, 24, 12),
    );
    final payload = envelope.toContractMap();

    expect(payload.keys, {'encrypted_location', 'key_id', 'captured_at'});
    expect(payload.containsKey('latitude'), isFalse);
    expect(payload.containsKey('longitude'), isFalse);
    expect(envelope.toString(), isNot(contains('sensitive-ciphertext')));
  });

  test('export readiness requires ready state and unexpired server time', () {
    final now = DateTime.utc(2026, 9, 24, 12);
    final ready = DataExportReceipt(
      opaqueRequestId: 'opaque-export',
      state: DataExportState.ready,
      downloadExpiresAt: now.add(const Duration(minutes: 1)),
    );

    expect(ready.isDownloadReadyAt(now), isTrue);
    expect(
      ready.isDownloadReadyAt(now.add(const Duration(minutes: 1))),
      isFalse,
    );
  });

  test('unconfigured lifecycle API fails every operation', () async {
    const api = UnconfiguredAccountLifecycleApi();
    final envelope = EncryptedLocationEnvelope(
      ciphertext: 'ciphertext',
      keyId: 'key',
      capturedAt: DateTime.utc(2026, 9, 24),
    );

    final results = await Future.wait([
      api.pauseAccount(),
      api.resumeAccount(),
      api.requestDataExport(),
      api.scheduleAccountDeletion(),
      api.cancelScheduledDeletion(),
      api.submitEncryptedLocation(envelope),
    ]);

    expect(results, everyElement(isA<AccountLifecycleFailure>()));
    expect(
      results.cast<AccountLifecycleFailure>().map((failure) => failure.reason),
      everyElement(AccountLifecycleFailureReason.unavailable),
    );
  });
}
