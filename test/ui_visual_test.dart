import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';

void main() {
  Future<void> usePhoneViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('welcome visual baseline', (tester) async {
    await usePhoneViewport(tester);
    await tester.pumpWidget(const VawraApp());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_welcome.png'),
    );
  });

  testWidgets('discovery visual baseline', (tester) async {
    await usePhoneViewport(tester);
    await enterDiscovery(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_discovery.png'),
    );
  });

  testWidgets('onboarding visual baseline', (tester) async {
    await usePhoneViewport(tester);
    await startOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
    await tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboarding-age')), '28');
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('intent-open_to_long_term')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_onboarding.png'),
    );
  });

  testWidgets('onboarding lifestyle visual baseline', (tester) async {
    await usePhoneViewport(tester);
    await startOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
    await tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboarding-age')), '28');
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('intent-open_to_long_term')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('interest-Books')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('lifestyle-drinking-Socially')));
    await tester.tap(find.byKey(const Key('lifestyle-pets-Cat person')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_onboarding_lifestyle.png'),
    );
  });

  testWidgets('settings visual baseline', (tester) async {
    await usePhoneViewport(tester);
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('profile-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_settings.png'),
    );
  });

  testWidgets('swipe tutorial visual baseline', (tester) async {
    await usePhoneViewport(tester);
    await startOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
    await tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboarding-age')), '28');
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('intent-open_to_long_term')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('interest-Books')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    await tapNext(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_swipe_tutorial.png'),
    );
  });

  testWidgets('match celebration visual baseline', (tester) async {
    await usePhoneViewport(tester);
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('action-like')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_match.png'),
    );
  });

  testWidgets('connections visual baseline', (tester) async {
    await usePhoneViewport(tester);
    await enterDiscovery(tester);
    await tester.flingFrom(const Offset(160, 300), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();
    await closeMatchIfShown(tester);
    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_connections.png'),
    );
  });

  testWidgets('chat visual baseline', (tester) async {
    await usePhoneViewport(tester);
    await enterDiscovery(tester);
    await tester.flingFrom(const Offset(160, 300), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();
    await closeMatchIfShown(tester);
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    await closeSafetyGuideIfShown(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_chat.png'),
    );
  });

  testWidgets('profile visual baseline', (tester) async {
    await usePhoneViewport(tester);
    await enterDiscovery(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_profile.png'),
    );
  });
}
