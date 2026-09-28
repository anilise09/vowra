import 'profile_prompt.dart';

/// First lines for an empty chat, built from what the two people share: the
/// other person's prompt answers first (the most personal), then shared
/// interests. They only fill the message box; the person edits and sends.
const maxOpeners = 3;

const _interestQuestions = {
  'Arts': 'What is the best exhibition you have seen lately?',
  'Books': 'What are you reading at the moment? I need a recommendation.',
  'Cooking': 'What is the dish you are proudest of cooking?',
  'Fitness': 'What is your favourite way to stay active?',
  'Music': 'Who have you had on repeat lately?',
  'Outdoors': 'Where is your favourite place to get outside around here?',
  'Travel': 'What is the best trip you have taken so far?',
};

String _clean(String answer) {
  var text = answer.trim().replaceAll(RegExp(r'[.!…]+$'), '');
  // "My sourdough starter" reads better mid-sentence as "my sourdough starter",
  // but names and "I" stay as written.
  if (text.length > 1 &&
      text[0] != text[0].toLowerCase() &&
      text[1] == text[1].toLowerCase() &&
      !text.startsWith('I ')) {
    final firstWord = text.split(' ').first.toLowerCase();
    if (const {
      'my',
      'the',
      'a',
      'an',
      'our',
      'long',
      'good',
    }.contains(firstWord)) {
      text = text[0].toLowerCase() + text.substring(1);
    }
  }
  return text;
}

String _fromPrompt(ProfilePrompt prompt) {
  final question = prompt.question.replaceAll('…', '').trim();
  if (prompt.question == 'Ask me about…') {
    return 'Okay, I am asking: tell me about ${_clean(prompt.answer)}!';
  }
  return 'I loved your answer to "$question". Tell me more?';
}

List<String> openersFor({
  required List<String> sharedInterests,
  required List<ProfilePrompt> peerPrompts,
}) {
  final lines = <String>[
    for (final prompt in peerPrompts)
      if (prompt.answer.trim().isNotEmpty) _fromPrompt(prompt),
    for (final interest in sharedInterests)
      if (_interestQuestions[interest] case final question?)
        'You like ${interest.toLowerCase()} too! $question',
  ];
  return lines.take(maxOpeners).toList();
}
