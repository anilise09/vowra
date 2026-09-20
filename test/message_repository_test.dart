import 'package:ember_app/data/message_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes valid text and rejects invalid content', () {
    final repository = MemoryMessageRepository();
    final sent = repository.send(
      matchId: 'm1',
      text: '  hello    there  ',
      connectionActive: true,
    );
    expect(sent.accepted, isTrue);
    expect(sent.message?.text, 'hello there');
    expect(
      repository.send(matchId: 'm1', text: '  ', connectionActive: true).error,
      isNotNull,
    );
    expect(
      repository
          .send(matchId: 'm1', text: 'bad\u0000', connectionActive: true)
          .error,
      contains('control'),
    );
  });

  test('closed connection fails before a message is stored', () {
    final repository = MemoryMessageRepository();
    final result = repository.send(
      matchId: 'm1',
      text: 'hello',
      connectionActive: false,
    );
    expect(result.accepted, isFalse);
    expect(repository.list('m1'), isEmpty);
  });

  test('rate limit and retention bound fail safely', () {
    final repository = MemoryMessageRepository(maxRetainedMessages: 5);
    final start = DateTime.utc(2026, 9, 20, 12);
    for (var index = 0; index < 5; index++) {
      expect(
        repository
            .send(
              matchId: 'm1',
              text: 'message $index',
              connectionActive: true,
              now: start.add(Duration(seconds: index)),
            )
            .accepted,
        isTrue,
      );
    }
    expect(
      repository
          .send(
            matchId: 'm1',
            text: 'too fast',
            connectionActive: true,
            now: start.add(const Duration(seconds: 10)),
          )
          .error,
      contains('Slow down'),
    );
    expect(repository.list('m1'), hasLength(5));
  });
}
