import 'package:ember_app/domain/openers.dart';
import 'package:ember_app/domain/profile_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prompt answers come first, then shared interests, at most three', () {
    final lines = openersFor(
      sharedInterests: ['Books', 'Music', 'Travel'],
      peerPrompts: const [
        ProfilePrompt('Ask me about…', 'My sourdough starter.'),
        ProfilePrompt('A perfect Sunday looks like…', 'Markets and naps'),
      ],
    );
    expect(lines, [
      'Okay, I am asking: tell me about my sourdough starter!',
      'I loved your answer to "A perfect Sunday looks like". Tell me more?',
      'You like books too! What are you reading at the moment? '
          'I need a recommendation.',
    ]);
  });

  test('names and "I" keep their capitals; nothing shared means no lines', () {
    expect(
      openersFor(
        sharedInterests: const [],
        peerPrompts: const [ProfilePrompt('Ask me about…', 'Lisbon')],
      ),
      ['Okay, I am asking: tell me about Lisbon!'],
    );
    expect(
      openersFor(sharedInterests: const [], peerPrompts: const []),
      isEmpty,
    );
    expect(
      openersFor(sharedInterests: const ['Knitting'], peerPrompts: const []),
      isEmpty,
    );
  });
}
