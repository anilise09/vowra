import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('requires adult and community-rule consent', (tester) async {
    await tester.pumpWidget(const VawraApp());
    expect(
      find.image(
        const AssetImage('assets/branding/vawra_company_mark_clean.png'),
      ),
      findsOneWidget,
    );
    expect(find.text('Vawra'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('continue-button')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('adult-checkbox')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('continue-button')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('rules-checkbox')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('continue-button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('enters discovery and opens safety center', (tester) async {
    await tester.pumpWidget(const VawraApp());
    await tester.tap(find.byKey(const Key('adult-checkbox')));
    await tester.tap(find.byKey(const Key('rules-checkbox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('continue-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-button')));
    await tester.pumpAndSettle();
    expect(find.text('PROTOTYPE PROFILE · NOT A REAL PERSON'), findsOneWidget);
    expect(find.textContaining('Exact location'), findsOneWidget);
    await tester.tap(find.byTooltip('Safety center'));
    await tester.pumpAndSettle();
    expect(find.text('Calls require mutual readiness'), findsOneWidget);
    expect(
      find.text('A match can always decline. Calls are not recorded.'),
      findsOneWidget,
    );
  });

  testWidgets('validates and saves a local prototype profile', (tester) async {
    await tester.pumpWidget(const VawraApp());
    await tester.tap(find.byKey(const Key('adult-checkbox')));
    await tester.tap(find.byKey(const Key('rules-checkbox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('continue-button')));
    await tester.tap(find.byKey(const Key('continue-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-tab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), 'Alex');
    await tester.enterText(find.byKey(const Key('profile-age')), '17');
    await tester.enterText(
      find.byKey(const Key('profile-bio')),
      'I enjoy good books, thoughtful conversations, and cooking.',
    );
    await tester.scrollUntilVisible(
      find.text('Books'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('profile-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Books'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('save-profile')),
      220,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('profile-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pump();
    expect(find.text('Vawra is only for adults 18+.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profile-age')), '28');
    await tester.dragFrom(const Offset(400, 450), const Offset(0, -400));
    await tester.pump();
    await tester.dragFrom(const Offset(400, 450), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pump();
    expect(
      find.text('Profile saved on this device session only.'),
      findsOneWidget,
    );
  });

  testWidgets('video calls require mutual readiness and block closes contact', (
    tester,
  ) async {
    await tester.pumpWidget(const VawraApp());
    await tester.tap(find.byKey(const Key('adult-checkbox')));
    await tester.tap(find.byKey(const Key('rules-checkbox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('continue-button')));
    await tester.tap(find.byKey(const Key('continue-button')));
    await tester.pumpAndSettle();
    await tester.flingFrom(const Offset(400, 320), const Offset(0, -500), 1000);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Chats'),
      ),
    );
    await tester.pumpAndSettle();

    FilledButton callButton() => tester.widget<FilledButton>(
      find.byKey(const Key('request-video-call')),
    );
    expect(callButton().onPressed, isNull);
    await tester.tap(find.byKey(const Key('call-ready-switch')));
    await tester.pump();
    expect(callButton().onPressed, isNotNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('request-video-call')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('request-video-call')));
    await tester.pump();
    expect(find.textContaining('no camera, microphone'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('message-composer')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(
      find.byKey(const Key('message-composer')),
      '  A new    bounded message  ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(find.text('A new bounded message'), findsOneWidget);

    await tester.dragFrom(const Offset(400, 180), const Offset(0, 800));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Conversation safety actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-block')));
    await tester.pumpAndSettle();
    expect(find.text('Blocked'), findsOneWidget);
    expect(
      find.textContaining('can no longer message or call'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('request-video-call')), findsNothing);
  });
}
