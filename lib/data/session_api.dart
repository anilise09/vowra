import '../domain/session_contract.dart';

sealed class SessionResult {
  const SessionResult();
}

class SessionEstablished extends SessionResult {
  const SessionEstablished(this.session);
  final SessionSnapshot session;
}

class AccountRequestAccepted extends SessionResult {
  const AccountRequestAccepted(this.receipt);
  final PublicAccountRequestReceipt receipt;
}

class SessionEnded extends SessionResult {
  const SessionEnded();
}

enum SessionFailureReason {
  unavailable,
  invalidOrExpiredProof,
  reauthenticationRequired,
  rateLimited,
}

class SessionFailure extends SessionResult {
  const SessionFailure(this.reason, this.message);
  final SessionFailureReason reason;
  final String message;
}

abstract interface class SessionApi {
  Future<SessionResult> requestAccountAction(AccountRequest request);
  Future<SessionResult> exchangeProviderProof(ProviderExchangeProof proof);
  Future<SessionResult> rotateSession();
  Future<SessionResult> signOutCurrentSession();
  Future<SessionResult> signOutEverywhere();
}

/// Fail-closed until authentication and recovery providers pass review.
class UnconfiguredSessionApi implements SessionApi {
  const UnconfiguredSessionApi();

  static const _failure = SessionFailure(
    SessionFailureReason.unavailable,
    'Account sessions are not connected in this prototype.',
  );

  @override
  Future<SessionResult> requestAccountAction(AccountRequest request) async =>
      _failure;

  @override
  Future<SessionResult> exchangeProviderProof(
    ProviderExchangeProof proof,
  ) async => _failure;

  @override
  Future<SessionResult> rotateSession() async => _failure;

  @override
  Future<SessionResult> signOutCurrentSession() async => _failure;

  @override
  Future<SessionResult> signOutEverywhere() async => _failure;
}
