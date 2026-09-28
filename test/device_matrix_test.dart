import 'package:ember_app/features/discovery/discovery_deck.dart'
    show maxCardWidth;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';

/// Every main screen on the kinds of devices people really use, with their
/// system bars, at normal and larger text. Any overflow fails the test, and on
/// wide screens the swipe card must stay a readable size instead of
/// stretching across a tablet.
class Device {
  const Device(this.name, this.size, {this.top = 24, this.bottom = 48});

  final String name;
  final Size size; // logical pixels
  final double top; // status bar
  final double bottom; // navigation bar (48 = three buttons)
}

const devices = [
  Device('small phone 320x568', Size(320, 568), top: 20, bottom: 0),
  Device('compact Android 360x640', Size(360, 640)),
  Device('Samsung S24 Ultra 384x832', Size(384, 832)),
  Device('Pixel / iPhone 393x852', Size(393, 852), top: 47, bottom: 34),
  Device('Pro Max 430x932', Size(430, 932), top: 59, bottom: 34),
  Device('Fold cover 344x882', Size(344, 882)),
  Device('Fold open 673x841', Size(673, 841)),
  Device('tablet portrait 800x1280', Size(800, 1280), bottom: 24),
  Device('tablet landscape 1280x800', Size(1280, 800), bottom: 24),
];

/// Scrolls a control into view like a person would, then taps it. A control
/// that is still covered (say, under a pinned button) fails the test.
Future<void> tapShown(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> onboard(WidgetTester tester) async {
  await startOnboarding(tester);
  await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
  await tapShown(tester, find.byKey(const Key('onboarding-next')));
  await tester.enterText(find.byKey(const Key('onboarding-age')), '28');
  await tapShown(tester, find.byKey(const Key('onboarding-next')));
  await tapShown(tester, find.byKey(const Key('gender-woman')));
  await tapShown(tester, find.byKey(const Key('onboarding-next')));
  await tapShown(tester, find.byKey(const Key('onboarding-next')));
  await tapShown(tester, find.byKey(const Key('intent-open_to_long_term')));
  await tapShown(tester, find.byKey(const Key('onboarding-next')));
  await tapShown(tester, find.byKey(const Key('interest-Books')));
  await tapShown(tester, find.byKey(const Key('onboarding-next')));
  await tapShown(tester, find.byKey(const Key('onboarding-skip')));
  await tapShown(tester, find.byKey(const Key('onboarding-skip')));
  await tapShown(tester, find.byKey(const Key('onboarding-next')));
  final done = find.byKey(const Key('swipe-tutorial-done'));
  if (done.evaluate().isNotEmpty) await tapShown(tester, done);
}

Future<void> walkApp(WidgetTester tester) async {
  await onboard(tester);

  final card = tester.getRect(find.byKey(const Key('discovery-card-gesture')));
  expect(card.width, lessThanOrEqualTo(maxCardWidth));
  expect(card.height, greaterThan(200));

  // Details sheet, then back.
  await tapShown(tester, find.byKey(const Key('open-profile-details')));
  await tapShown(tester, find.byKey(const Key('close-profile-details')));

  // Like the first profile (she likes back in the prototype), open the chat.
  await tapShown(tester, find.byKey(const Key('action-like')));
  await tapShown(tester, find.byKey(const Key('match-send-message')));
  await closeSafetyGuideIfShown(tester);
  expect(find.byKey(const Key('message-composer')), findsOneWidget);

  for (final tab in ['explore-tab', 'profile-tab']) {
    await tester.tap(find.byKey(Key(tab)));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Matches'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('profile-tab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-settings')));
  await tester.pumpAndSettle();
  expect(find.text('Settings'), findsOneWidget);
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final device in devices) {
    for (final textScale in const [1.0, 1.3]) {
      testWidgets('${device.name} at ${textScale}x text', (tester) async {
        const dpr = 3.0;
        tester.view
          ..devicePixelRatio = dpr
          ..physicalSize = device.size * dpr
          ..padding = FakeViewPadding(
            top: device.top * dpr,
            bottom: device.bottom * dpr,
          )
          ..viewPadding = FakeViewPadding(
            top: device.top * dpr,
            bottom: device.bottom * dpr,
          );
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await walkApp(tester);
      });
    }
  }
  // This exercises Flutter's iOS platform branch and realistic safe areas on
  // Windows. It is not a substitute for an iOS Simulator or device run on macOS.
  for (final device in devices.where(
    (device) =>
        device.name == 'Pixel / iPhone 393x852' ||
        device.name == 'Pro Max 430x932',
  )) {
    for (final textScale in const [1.0, 1.3]) {
      testWidgets('iOS-style ${device.name} at ${textScale}x text', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        const dpr = 3.0;
        tester.view
          ..devicePixelRatio = dpr
          ..physicalSize = device.size * dpr
          ..padding = FakeViewPadding(
            top: device.top * dpr,
            bottom: device.bottom * dpr,
          )
          ..viewPadding = FakeViewPadding(
            top: device.top * dpr,
            bottom: device.bottom * dpr,
          );
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        try {
          await walkApp(tester);
        } finally {
          // Flutter checks debug globals before addTearDown callbacks run.
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
