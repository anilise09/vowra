import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';

/// Walks every main screen at a large accessibility text size on a phone-sized
/// screen. Any layout overflow fails the test.
void main() {
  testWidgets('main screens survive 1.8x text on a phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await startOnboarding(tester);
    await tester.enterText(
      find.byKey(const Key('onboarding-name')),
      'Alexandra',
    );
    await tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboarding-age')), '28');
    await tapNext(tester);
    await tester.ensureVisible(find.byKey(const Key('intent-figuring_it_out')));
    await tester.tap(find.byKey(const Key('intent-figuring_it_out')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('interest-Outdoors')));
    await tester.pump();
    await tapNext(tester);
    await tester.ensureVisible(
      find.byKey(const Key('lifestyle-smoking-Trying to quit')),
    );
    await tester.tap(find.byKey(const Key('lifestyle-smoking-Trying to quit')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    await tapNext(tester);

    // Discover, details, preferences.
    await tester.ensureVisible(find.byKey(const Key('open-profile-details')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-profile-details')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('details-report')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('profile-details-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('close-profile-details')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('discovery-preferences')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discovery-preferences')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('reset-discovery-preferences')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset-discovery-preferences')));
    await tester.pumpAndSettle();

    // Matches, Chats (with guide), Profile, Settings.
    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    await closeSafetyGuideIfShown(tester);
    await tester.tap(find.byKey(const Key('profile-tab')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('preview-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-preview')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('photo-tips')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-tips')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-delete')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('settings-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete your profile?'), findsOneWidget);
  });
}
