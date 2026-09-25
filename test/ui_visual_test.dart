import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pumpWidget(const VawraApp());
    await tester.tap(find.byKey(const Key('adult-checkbox')));
    await tester.tap(find.byKey(const Key('rules-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('continue-button')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_discovery.png'),
    );
  });
}
