enum MessageAuthor { currentUser, peer }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final MessageAuthor author;
  final String text;
  final DateTime sentAt;
}

class MessagePolicy {
  static const maxCharacters = 1000;
  static const maxMessagesPerMinute = 5;

  static String normalize(String value) =>
      value.trim().replaceAll(RegExp(r'[ \t]+'), ' ');

  static String? validate(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return 'Write a message first.';
    if (normalized.length > maxCharacters) {
      return 'Messages are limited to $maxCharacters characters.';
    }
    if (RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(normalized)) {
      return 'Remove unsupported control characters.';
    }
    return null;
  }
}

class SendMessageResult {
  const SendMessageResult._(this.message, this.error);
  const SendMessageResult.sent(ChatMessage message) : this._(message, null);
  const SendMessageResult.rejected(String error) : this._(null, error);

  final ChatMessage? message;
  final String? error;
  bool get accepted => message != null;
}
