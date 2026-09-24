import 'package:ember_app/data/session_api.dart';
import 'package:ember_app/domain/session_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public account receipt cannot reveal account existence', () {
    const receipt = PublicAccountRequestReceipt(
      message: PublicAccountRequestReceipt.genericMessage,
    );

    expect(receipt.toContractMap(), {
      'message': 'If the account can continue, instructions will be sent.',
    });
    expect(receipt.toContractMap().keys, isNot(contains('account_exists')));
  });

  test('account identifiers and provider proofs are redacted from logs', () {
    const request = AccountRequest(
      identifier: 'person@example.com',
      purpose: AccountRequestPurpose.recovery,
    );
    const proof = ProviderExchangeProof(
      provider: SignInProvider.googleOidc,
      authorizationCode: 'secret-code',
      pkceVerifier: 'secret-verifier',
      stateNonce: 'secret-state',
    );

    expect(request.toString(), isNot(contains('person@example.com')));
    expect(proof.toString(), isNot(contains('secret-code')));
    expect(proof.toString(), isNot(contains('secret-verifier')));
    expect(proof.toString(), isNot(contains('secret-state')));
  });

  test('only a live active server session allows authenticated requests', () {
    final now = DateTime.utc(2026, 9, 24, 12);
    SessionSnapshot snapshot(SessionState state, DateTime expiresAt) =>
        SessionSnapshot(
          opaqueSessionId: 'opaque-session',
          opaqueAccountId: 'opaque-account',
          state: state,
          expiresAt: expiresAt,
        );

    expect(
      snapshot(
        SessionState.active,
        now.add(const Duration(minutes: 1)),
      ).allowsAuthenticatedRequestsAt(now),
      isTrue,
    );
    expect(
      snapshot(SessionState.active, now).allowsAuthenticatedRequestsAt(now),
      isFalse,
    );
    expect(
      snapshot(
        SessionState.reauthenticationRequired,
        now.add(const Duration(minutes: 1)),
      ).allowsAuthenticatedRequestsAt(now),
      isFalse,
    );
    expect(
      snapshot(
        SessionState.revoked,
        now.add(const Duration(minutes: 1)),
      ).allowsAuthenticatedRequestsAt(now),
      isFalse,
    );
  });

  test('unconfigured session API fails every account operation', () async {
    const api = UnconfiguredSessionApi();
    const request = AccountRequest(
      identifier: 'person@example.com',
      purpose: AccountRequestPurpose.signIn,
    );
    const proof = ProviderExchangeProof(
      provider: SignInProvider.passwordlessEmail,
      authorizationCode: 'one-time-code',
      pkceVerifier: 'verifier',
      stateNonce: 'state',
    );

    final results = await Future.wait([
      api.requestAccountAction(request),
      api.exchangeProviderProof(proof),
      api.rotateSession(),
      api.signOutCurrentSession(),
      api.signOutEverywhere(),
    ]);

    expect(results, everyElement(isA<SessionFailure>()));
    expect(
      results.cast<SessionFailure>().map((failure) => failure.reason),
      everyElement(SessionFailureReason.unavailable),
    );
  });
}
