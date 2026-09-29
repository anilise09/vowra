// Renders the app's own screens, with real fonts and the bundled sample
// portraits, for the website. Not part of the test suite; run:
//   flutter test tool/site_screens_test.dart --update-goldens
// Output: build/site_screens/*.png, which are converted to 720px-wide WebP in
// website/assets/screens/. Buttons and chips whose style names no font show
// as blocks here (the test renderer's own fallback), so screens with them
// come from the phone instead: see website/README.md.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ember_app/data/api/vawra_api.dart';
import 'package:ember_app/main.dart';

import '../test/support/app_flow.dart';
import '../test/support/fake_vawra_server.dart';

const _fonts =
    'C:/Users/anili/Tools/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  // A style with no family (the app's button text) falls back to the test
  // font; on a phone it falls back to Roboto, so map both names to it.
  for (final family in ['Roboto', 'FlutterTest', 'Ahem']) {
    final roboto = FontLoader(family);
    for (final f in ['regular', 'medium', 'bold', 'black', 'light']) {
      final bytes = File('$_fonts/roboto-$f.ttf').readAsBytesSync();
      roboto.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await roboto.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.view(
          File('$_fonts/materialicons-regular.otf').readAsBytesSync().buffer,
        ),
      ),
    );
  await icons.load();
}

Future<void> _phone(WidgetTester tester) async {
  const dpr = 3.0;
  tester.view
    ..devicePixelRatio = dpr
    ..physicalSize = const Size(393, 852) * dpr
    ..padding = const FakeViewPadding(top: 28 * dpr, bottom: 16 * dpr)
    ..viewPadding = const FakeViewPadding(top: 28 * dpr, bottom: 16 * dpr);
  addTearDown(tester.view.reset);
}

/// Decodes every portrait on screen before the shot, so none is blank.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    final seen = <String>{};
    for (final element in find.byType(Image).evaluate()) {
      final provider = (element.widget as Image).image;
      if (provider is AssetImage && seen.add(provider.assetName)) {
        await precacheImage(provider, context);
      }
    }
    for (final element in find.byType(DecoratedBox).evaluate()) {
      final decoration = (element.widget as DecoratedBox).decoration;
      final image = decoration is BoxDecoration
          ? decoration.image?.image
          : null;
      if (image is AssetImage && seen.add(image.assetName)) {
        await precacheImage(image, context);
      }
    }
  });
  await _pumps(tester);
}

/// The server-connected app keeps a live-update link open, so settle by
/// time instead of waiting for no frames.
Future<void> _pumps(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settleImages(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../build/site_screens/$name.png'),
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('discover', (tester) async {
    await _phone(tester);
    await enterDiscovery(tester);
    await _shot(tester, 'discover');
  });

  testWidgets('details', (tester) async {
    await _phone(tester);
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('open-profile-details')));
    await tester.pumpAndSettle();
    await _shot(tester, 'details');
  });

  testWidgets('match', (tester) async {
    await _phone(tester);
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('action-like')));
    await tester.pumpAndSettle();
    await _shot(tester, 'match');
  });

  testWidgets('chat', (tester) async {
    await _phone(tester);
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('action-like')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-send-message')));
    await tester.pumpAndSettle();
    await closeSafetyGuideIfShown(tester);
    await _shot(tester, 'chat');
  });

  testWidgets('explore', (tester) async {
    await _phone(tester);
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('explore-tab')));
    await tester.pumpAndSettle();
    await _shot(tester, 'explore');
  });

  testWidgets('profile', (tester) async {
    await _phone(tester);
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('profile-tab')));
    await tester.pumpAndSettle();
    await _shot(tester, 'profile');
  });

  testWidgets('settings', (tester) async {
    await _phone(tester);
    await enterDiscovery(tester);
    await tester.tap(find.byKey(const Key('profile-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await _shot(tester, 'settings');
  });

  testWidgets('show-me', (tester) async {
    await _phone(tester);
    await startOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onboarding-name')), 'Alex');
    await tapNext(tester);
    await tester.enterText(find.byKey(const Key('onboarding-age')), '28');
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('gender-man')));
    await tester.pump();
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('showme-woman')));
    await tester.pumpAndSettle();
    await _shot(tester, 'show-me');
  });

  // Screens from the app connected to its server (a stand-in server with
  // one labelled sample member).
  Future<FakeVawraServer> signedIn(WidgetTester tester) async {
    await _phone(tester);
    final server = FakeVawraServer()
      ..verified = true
      ..addPerson(
        'Maya',
        age: 29,
        likesMe: true,
        demoPortrait: 'assets/profiles/maya.webp',
        prompts: [
          {'question': 'Ask me about…', 'answer': 'my sourdough starter'},
        ],
        reasons: [
          {'kind': 'goal', 'text': 'Both want something long-term'},
          {'kind': 'interests', 'text': 'You both like Books and Music'},
          {'kind': 'habit', 'text': 'Both dog people'},
        ],
      )
      ..profile = {
        'display_name': 'Alex',
        'relationship_intent': 'long_term',
        'bio':
            'Weekend baker and live-music regular, always up for a long walk.',
        'interests': <String>['Books', 'Music', 'Travel'],
        'show_distance_band': true,
        'call_ready_by_default': false,
        'public_age': 28,
        'gender': 'man',
        'show_me': <String>['woman'],
        'show_gender': false,
      };
    final api = VawraApi(Uri.parse('http://vawra.test'), client: server.client);
    await tester.pumpWidget(VawraApp(api: api));
    await _pumps(tester);
    for (final key in ['adult-checkbox', 'rules-checkbox']) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await _pumps(tester);
      await tester.tap(find.byKey(Key(key)));
    }
    await tester.ensureVisible(find.byKey(const Key('continue-button')));
    await _pumps(tester);
    await tester.tap(find.byKey(const Key('continue-button')));
    await _pumps(tester);
    await tester.enterText(
      find.byKey(const Key('sign-in-email')),
      'alex@example.test',
    );
    await tester.tap(find.byKey(const Key('send-code')));
    await _pumps(tester);
    await tester.enterText(
      find.byKey(const Key('sign-in-code')),
      server.outbox.last,
    );
    await tester.tap(find.byKey(const Key('verify-code')));
    await _pumps(tester);
    await dismissSwipeTutorial(tester);
    await _pumps(tester);
    return server;
  }

  testWidgets('reasons-card', (tester) async {
    await signedIn(tester);
    await _shot(tester, 'reasons-card');
  });

  testWidgets('reasons', (tester) async {
    await signedIn(tester);
    await tester.tap(find.byKey(const Key('open-profile-details')));
    await _pumps(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('detail-reasons')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('profile-details-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await _pumps(tester);
    await _shot(tester, 'reasons');
  });

  testWidgets('openers', (tester) async {
    await signedIn(tester);
    await tester.tap(find.byKey(const Key('action-like')));
    await _pumps(tester);
    await tester.tap(find.byKey(const Key('match-send-message')));
    await _pumps(tester);
    await _shot(tester, 'openers');
  });

  testWidgets('export', (tester) async {
    await signedIn(tester);
    await tester.tap(find.byKey(const Key('profile-tab')));
    await _pumps(tester);
    await tester.tap(find.byKey(const Key('open-settings')));
    await _pumps(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-export')),
      200,
    );
    await tester.ensureVisible(find.byKey(const Key('settings-export')));
    await _pumps(tester);
    await tester.tap(find.byKey(const Key('settings-export')));
    await _pumps(tester);
    await _pumps(tester);
    expect(find.text('Your data'), findsOneWidget);
    await _shot(tester, 'export');
  });
}
