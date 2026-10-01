import 'package:ember_app/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _expectLargeText = bool.fromEnvironment('VAWRA_EXPECT_LARGE_TEXT');
const _expectReducedMotion = bool.fromEnvironment(
  'VAWRA_EXPECT_REDUCED_MOTION',
);
const _accessibilityDebugChannel = MethodChannel(
  'com.projectember.emberApp/debug-accessibility',
);

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

Future<void> _tapNext(WidgetTester tester) =>
    _tapShown(tester, find.byKey(const Key('onboarding-next')));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('critical offline flow runs in the iOS simulator', (
    tester,
  ) async {
    expect(defaultTargetPlatform, TargetPlatform.iOS);

    app.main();
    await _settle(tester, frames: 20);

    expect(find.byKey(const Key('adult-checkbox')), findsOneWidget);
    expect(find.byKey(const Key('rules-checkbox')), findsOneWidget);
    final mediaQuery = MediaQuery.of(
      tester.element(find.byKey(const Key('adult-checkbox'))),
    );
    if (_expectLargeText) {
      expect(
        mediaQuery.textScaler.scale(16),
        greaterThan(19.2),
        reason: 'the iOS accessibility text size must reach Flutter',
      );
    }
    if (_expectReducedMotion) {
      final reduceMotionEnabled = await _accessibilityDebugChannel
          .invokeMethod<bool>('isReduceMotionEnabled');
      expect(
        reduceMotionEnabled,
        isTrue,
        reason: 'iOS Reduce Motion must be enabled for this validation run',
      );
    }
    await _tapShown(tester, find.byKey(const Key('adult-checkbox')));
    await _tapShown(tester, find.byKey(const Key('rules-checkbox')));
    await _tapShown(tester, find.byKey(const Key('continue-button')));

    await tester.enterText(
      find.byKey(const Key('onboarding-name')),
      'iOS Test',
    );
    await _tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboarding-age')), '28');
    await _tapNext(tester);
    await _tapShown(tester, find.byKey(const Key('gender-woman')));
    await _tapNext(tester);
    await _tapNext(tester);
    await _tapShown(tester, find.byKey(const Key('intent-open_to_long_term')));
    await _tapNext(tester);
    await _tapShown(tester, find.byKey(const Key('interest-Books')));
    await _tapNext(tester);
    await _tapShown(tester, find.byKey(const Key('onboarding-skip')));
    await _tapShown(tester, find.byKey(const Key('onboarding-skip')));
    await _tapNext(tester);

    final tutorialDone = find.byKey(const Key('swipe-tutorial-done'));
    if (tutorialDone.evaluate().isNotEmpty) {
      await _tapShown(tester, tutorialDone);
    }

    expect(find.byKey(const Key('discovery-card-gesture')), findsOneWidget);
    await _tapShown(tester, find.byKey(const Key('action-like')));
    expect(find.byKey(const Key('match-send-message')), findsOneWidget);
    await _tapShown(tester, find.byKey(const Key('match-send-message')));

    final safetyClose = find.byKey(const Key('safety-guide-close'));
    if (safetyClose.evaluate().isNotEmpty) {
      await _tapShown(tester, safetyClose);
    }

    final composer = find.byKey(const Key('message-composer'));
    expect(composer, findsOneWidget);
    await tester.enterText(composer, 'Hello from the iOS simulator');
    await _tapShown(tester, find.byKey(const Key('send-message')));
    expect(find.text('Hello from the iOS simulator'), findsOneWidget);

    await _tapShown(tester, find.byKey(const Key('thread-back')));
    await _tapShown(tester, find.byKey(const Key('profile-tab')));
    await _tapShown(tester, find.byKey(const Key('open-settings')));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('settings-show-me')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-delete')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('settings-delete')), findsOneWidget);
  });
}
