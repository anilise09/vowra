import 'package:ember_app/domain/chat_message.dart';
import 'package:ember_app/domain/match_connection.dart';
import 'package:ember_app/domain/safety_report.dart';
import 'package:ember_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'a report needs a reason and does not attach message evidence by default',
    (tester) async {
      SafetyReport? recorded;
      const connection = MatchConnection(
        matchId: 'synthetic-1',
        peerName: 'Maya',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatTab(
              connection: connection,
              messages: [
                ChatMessage(
                  id: 'peer-1',
                  author: MessageAuthor.peer,
                  text: 'Hello',
                  sentAt: DateTime.utc(2026, 9, 20),
                ),
              ],
              report: null,
              onSend: (_) {},
              onCallReadinessChanged: (_) {},
              onReport: (value) => recorded = value,
              onUnmatch: () {},
              onBlock: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Conversation safety actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report privately'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('submit-report')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('report-reason')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Harassment or hate').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit-report')));
      await tester.pumpAndSettle();

      expect(recorded?.matchId, 'synthetic-1');
      expect(recorded?.reason, ReportReason.harassment);
      expect(recorded?.messageId, isNull);
    },
  );

  testWidgets('message evidence is an optional ID reference only', (
    tester,
  ) async {
    SafetyReport? recorded;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatTab(
            connection: const MatchConnection(
              matchId: 'synthetic-2',
              peerName: 'Maya',
            ),
            messages: [
              ChatMessage(
                id: 'peer-2',
                author: MessageAuthor.peer,
                text: 'Example message',
                sentAt: DateTime.utc(2026, 9, 20),
              ),
            ],
            report: null,
            onSend: (_) {},
            onCallReadinessChanged: (_) {},
            onReport: (value) => recorded = value,
            onUnmatch: () {},
            onBlock: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Conversation safety actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report privately'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-reason')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scam or suspicious request').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-message-reference')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pumpAndSettle();

    expect(recorded?.reason, ReportReason.scam);
    expect(recorded?.messageId, 'peer-2');
  });
}
