import '../domain/chat_message.dart';

abstract interface class MessageRepository {
  List<ChatMessage> list(String matchId);
  SendMessageResult send({
    required String matchId,
    required String text,
    required bool connectionActive,
    DateTime? now,
  });
}

class MemoryMessageRepository implements MessageRepository {
  MemoryMessageRepository({this.maxRetainedMessages = 100});

  final int maxRetainedMessages;
  final Map<String, List<ChatMessage>> _messages = {};
  int _nextId = 1;

  void seed(String matchId, Iterable<ChatMessage> messages) {
    _messages[matchId] = messages.take(maxRetainedMessages).toList();
  }

  @override
  List<ChatMessage> list(String matchId) =>
      List.unmodifiable(_messages[matchId] ?? const []);

  @override
  SendMessageResult send({
    required String matchId,
    required String text,
    required bool connectionActive,
    DateTime? now,
  }) {
    if (!connectionActive) {
      return const SendMessageResult.rejected('This conversation is closed.');
    }
    final validation = MessagePolicy.validate(text);
    if (validation != null) {
      return SendMessageResult.rejected(validation);
    }
    final stamp = (now ?? DateTime.now().toUtc()).toUtc();
    final rows = _messages.putIfAbsent(matchId, () => []);
    final cutoff = stamp.subtract(const Duration(minutes: 1));
    final recentUserMessages = rows.where(
      (row) =>
          row.author == MessageAuthor.currentUser && row.sentAt.isAfter(cutoff),
    );
    if (recentUserMessages.length >= MessagePolicy.maxMessagesPerMinute) {
      return const SendMessageResult.rejected(
        'Slow down before sending another message.',
      );
    }
    final message = ChatMessage(
      id: 'local-${_nextId++}',
      author: MessageAuthor.currentUser,
      text: MessagePolicy.normalize(text),
      sentAt: stamp,
    );
    rows.add(message);
    if (rows.length > maxRetainedMessages) {
      rows.removeRange(0, rows.length - maxRetainedMessages);
    }
    return SendMessageResult.sent(message);
  }
}
