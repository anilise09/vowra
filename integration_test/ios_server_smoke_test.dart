import 'dart:convert';

import 'package:ember_app/data/api/vawra_api.dart';
import 'package:ember_app/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const _apiBase = String.fromEnvironment('VAWRA_TEST_API');
const _bridgeBase = String.fromEnvironment('VAWRA_TEST_CODE_BRIDGE');
const _email = String.fromEnvironment('VAWRA_TEST_EMAIL');

Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  for (var frame = 0; frame < frames; frame += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapShown(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int frames = 100,
}) async {
  for (var frame = 0; frame < frames && finder.evaluate().isEmpty; frame += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<String> _newSignInCode() async {
  final uri = Uri.parse('$_bridgeBase/code')
      .replace(queryParameters: {'email': _email});
  for (var attempt = 0; attempt < 50; attempt += 1) {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final code = (jsonDecode(response.body) as Map<String, dynamic>)['code'];
      if (code is String && RegExp(r'^\d{6}$').hasMatch(code)) return code;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('The local test-code bridge did not return a new code.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('server-connected account flow runs in the iOS simulator', (
    tester,
  ) async {
    expect(defaultTargetPlatform, TargetPlatform.iOS);
    expect(_apiBase, isNotEmpty);
    expect(_bridgeBase, isNotEmpty);
    expect(_email, endsWith('.test'));

    await tester.pumpWidget(
      VawraApp(api: VawraApi(Uri.parse(_apiBase), store: MemorySessionStore())),
    );
    await _waitFor(tester, find.byKey(const Key('adult-checkbox')));

    await _tapShown(tester, find.byKey(const Key('adult-checkbox')));
    await _tapShown(tester, find.byKey(const Key('rules-checkbox')));
    await _tapShown(tester, find.byKey(const Key('continue-button')));

    await tester.enterText(find.byKey(const Key('sign-in-email')), _email);
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await _settle(tester);
    final sendCode = find.byKey(const Key('send-code'));
    if (find.text('Check your email').evaluate().isEmpty) {
      await _waitFor(tester, sendCode);
      await _tapShown(tester, sendCode);
    }
    await _waitFor(tester, find.text('Check your email'));

    final code = await _newSignInCode();
    await tester.enterText(find.byKey(const Key('sign-in-code')), code);
    await _waitFor(tester, find.text('TEST PROFILE · NOT A REAL PERSON'));

    final tutorialDone = find.byKey(const Key('swipe-tutorial-done'));
    if (tutorialDone.evaluate().isNotEmpty) {
      await _tapShown(tester, tutorialDone);
    }
    expect(find.byKey(const Key('discovery-card-gesture')), findsOneWidget);

    await _tapShown(tester, find.byKey(const Key('profile-tab')));
    await _tapShown(tester, find.byKey(const Key('open-settings')));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('settings-show-me')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-sign-out')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await _tapShown(tester, find.byKey(const Key('settings-sign-out')));
    await _waitFor(tester, find.text('Continue with email'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
