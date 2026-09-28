import 'package:ember_app/theme/orientation_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phones stay upright; tablets and open foldables turn freely', () {
    for (final phone in const [
      Size(320, 568),
      Size(393, 852),
      Size(344, 882),
    ]) {
      expect(orientationsFor(phone), [DeviceOrientation.portraitUp]);
    }
    for (final big in const [
      Size(673, 841),
      Size(800, 1280),
      Size(1280, 800),
    ]) {
      expect(orientationsFor(big), isEmpty);
    }
  });
}
