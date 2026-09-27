/// A question the person chose and their short answer, shown on their card.
class ProfilePrompt {
  const ProfilePrompt(this.question, this.answer);

  final String question;
  final String answer;

  static const maxPrompts = 2;
  static const maxAnswer = 150;

  static const questions = [
    'A perfect Sunday looks like…',
    'I get far too excited about…',
    'The way to win me over is…',
    'A green flag I look for…',
    'My most controversial food opinion…',
    'I am looking for someone who…',
    'Ask me about…',
    'The best trip I have taken…',
  ];

  static String? validateAnswer(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Write a short answer.';
    if (trimmed.length > maxAnswer) {
      return 'Use $maxAnswer characters or fewer.';
    }
    return null;
  }
}
