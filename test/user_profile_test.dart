import 'package:ember_app/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile validation enforces the adult boundary', () {
    expect(UserProfile.validateAge('17'), contains('18+'));
    expect(UserProfile.validateAge('18'), isNull);
    expect(UserProfile.validateAge('100'), isNotNull);
    expect(UserProfile.validateAge('not an age'), isNotNull);
  });

  test('profile validation bounds public text', () {
    expect(UserProfile.validateName('A'), isNotNull);
    expect(UserProfile.validateName('Alex'), isNull);
    expect(UserProfile.validateName('Alex\u0000'), isNotNull);
    expect(UserProfile.validateBio('Too short'), isNotNull);
    expect(
      UserProfile.validateBio('A thoughtful introduction with enough context.'),
      isNull,
    );
  });
}
