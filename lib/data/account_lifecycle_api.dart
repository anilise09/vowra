import '../domain/account_lifecycle_contract.dart';

sealed class AccountLifecycleResult {
  const AccountLifecycleResult();
}

class AccountLifecycleUpdated extends AccountLifecycleResult {
  const AccountLifecycleUpdated(this.snapshot);
  final AccountLifecycleSnapshot snapshot;
}

class DataExportAccepted extends AccountLifecycleResult {
  const DataExportAccepted(this.receipt);
  final DataExportReceipt receipt;
}

class LocationUpdateAccepted extends AccountLifecycleResult {
  const LocationUpdateAccepted(this.snapshot);
  final LocationPrivacySnapshot snapshot;
}

enum AccountLifecycleFailureReason {
  unavailable,
  unauthenticated,
  reauthenticationRequired,
  invalidState,
  rateLimited,
}

class AccountLifecycleFailure extends AccountLifecycleResult {
  const AccountLifecycleFailure(this.reason, this.message);
  final AccountLifecycleFailureReason reason;
  final String message;
}

abstract interface class AccountLifecycleApi {
  Future<AccountLifecycleResult> pauseAccount();
  Future<AccountLifecycleResult> resumeAccount();
  Future<AccountLifecycleResult> requestDataExport();
  Future<AccountLifecycleResult> scheduleAccountDeletion();
  Future<AccountLifecycleResult> cancelScheduledDeletion();
  Future<AccountLifecycleResult> submitEncryptedLocation(
    EncryptedLocationEnvelope envelope,
  );
}

/// Fail-closed until retention, recovery, export, and location controls pass
/// legal, privacy, and security review.
class UnconfiguredAccountLifecycleApi implements AccountLifecycleApi {
  const UnconfiguredAccountLifecycleApi();

  static const _failure = AccountLifecycleFailure(
    AccountLifecycleFailureReason.unavailable,
    'Account lifecycle service is not connected in this prototype.',
  );

  @override
  Future<AccountLifecycleResult> pauseAccount() async => _failure;

  @override
  Future<AccountLifecycleResult> resumeAccount() async => _failure;

  @override
  Future<AccountLifecycleResult> requestDataExport() async => _failure;

  @override
  Future<AccountLifecycleResult> scheduleAccountDeletion() async => _failure;

  @override
  Future<AccountLifecycleResult> cancelScheduledDeletion() async => _failure;

  @override
  Future<AccountLifecycleResult> submitEncryptedLocation(
    EncryptedLocationEnvelope envelope,
  ) async => _failure;
}
