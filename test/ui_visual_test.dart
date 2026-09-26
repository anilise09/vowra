import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> usePhoneViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> enterDiscovery(WidgetTester tester) async {
    await tester.pumpWidget(const VawraApp());
    await tester.tap(find.byKey(const Key('adult-checkbox')));
    await tester.tap(find.byKey(const Key('rules-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('continue-button')));
    await tester.pumpAndSettle();
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

  testWidgets('connections visual baseline', (tester) async {
    await usePhoneViewport(tester);
    await enterDiscovery(tester);
    await tester.flingFrom(const Offset(160, 300), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();

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
