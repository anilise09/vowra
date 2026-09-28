import 'package:ember_app/server/data_export_page.dart';
import 'package:ember_app/theme/vawra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _data = {
  'format': 'vawra-export-1',
  'generated_at': '2026-09-28T12:00:00.000Z',
  'account': {
    'email': 'alex@example.test',
    'created_at': '2026-09-20T12:00:00.000Z',
    'age_state': 'adult_verified',
    'lifecycle': 'active',
    'deletion_effective_at': null,
  },
  'profile': {
    'display_name': 'Alex',
    'relationship_intent': 'open_to_long_term',
    'bio': 'Weekend baker and live-music regular, always up for a long walk.',
    'interests': ['Books', 'Music', 'Travel'],
    'gender': 'man',
    'show_me': ['woman'],
    'show_gender': false,
  },
  'swipes': [
    {'kind': 'like', 'at': '2026-09-21T12:00:00.000Z'},
  ],
  'matches': [
    {
      'with': 'Maya',
      'status': 'active',
      'matched_at': '2026-09-21T12:02:00.000Z',
      'messages_you_sent': [
        {'at': '2026-09-21T12:03:00.000Z', 'text': 'Hi Maya'},
      ],
    },
  ],
  'blocks': <Object>[],
  'reports_you_made': <Object>[],
  'sign_ins': <Object>[],
  'not_included': ['Messages other people sent you'],
};

Future<void> _pump(WidgetTester tester, {double textScale = 1}) async {
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: VawraTheme.light,
      home: const DataExportPage(data: _data),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('labels line up in one column; cards span the page', (
    tester,
  ) async {
    await _pump(tester);
    final lefts = {
      for (final label in ['Email', 'Member since', 'Name', 'I am', 'Show me'])
        tester.getTopLeft(find.text(label)).dx,
    };
    expect(lefts, hasLength(1), reason: 'every label starts at the same x');
    final values = {
      for (final value in ['alex@example.test', 'Alex', 'Man', 'Women'])
        tester.getTopLeft(find.text(value)).dx,
    };
    expect(values, hasLength(1), reason: 'every value starts at the same x');
    final cards = find.descendant(
      of: find.byKey(const Key('export-scroll')),
      matching: find.byType(Material),
    );
    final widths = {
      for (final card in cards.evaluate())
        (card.renderObject! as RenderBox).size.width,
    };
    expect(widths, hasLength(1), reason: 'Account is as wide as Profile');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/vawra_data_export.png'),
    );
  });

  testWidgets('large text wraps instead of overflowing', (tester) async {
    await _pump(tester, textScale: 1.8);
    expect(tester.takeException(), isNull);
    expect(find.text('alex@example.test'), findsOneWidget);
  });
}
