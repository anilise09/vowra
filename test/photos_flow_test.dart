import 'dart:typed_data';

import 'package:ember_app/data/api/server_photo.dart';
import 'package:ember_app/data/api/vawra_api.dart';
import 'package:ember_app/main.dart';
import 'package:ember_app/server/photos_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';
import 'support/fake_vawra_server.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _signIn(WidgetTester tester, FakeVawraServer server) async {
  final api = VawraApi(Uri.parse('http://vawra.test'), client: server.client);
  await tester.pumpWidget(VawraApp(api: api));
  await _settle(tester);
  for (final key in ['adult-checkbox', 'rules-checkbox']) {
    await tester.ensureVisible(find.byKey(Key(key)));
    await _settle(tester);
    await tester.tap(find.byKey(Key(key)));
  }
  await tester.ensureVisible(find.byKey(const Key('continue-button')));
  await _settle(tester);
  await tester.tap(find.byKey(const Key('continue-button')));
  await _settle(tester);
  await tester.enterText(
    find.byKey(const Key('sign-in-email')),
    'alex@example.test',
  );
  await tester.tap(find.byKey(const Key('send-code')));
  await _settle(tester);
  await tester.enterText(
    find.byKey(const Key('sign-in-code')),
    server.outbox.last,
  );
  await tester.tap(find.byKey(const Key('verify-code')));
  await _settle(tester);
}

FakeVawraServer _server() => FakeVawraServer()
  ..verified = true
  ..profile = {
    'display_name': 'Alex',
    'relationship_intent': 'casual',
    'bio': '',
    'interests': <String>['Books'],
    'show_distance_band': true,
    'call_ready_by_default': false,
    'public_age': 28,
  };

Future<void> _openProfile(WidgetTester tester) async {
  await dismissSwipeTutorial(tester);
  await tester.tap(find.byKey(const Key('profile-tab')));
  await _settle(tester);
  await tester.ensureVisible(find.byKey(const Key('photos-card')));
  await _settle(tester);
}

void main() {
  final original = pickPhoto;
  tearDown(() => pickPhoto = original);

  testWidgets('a picked photo uploads and waits for review', (tester) async {
    final bytes = Uint8List.fromList(FakeVawraServer.pixel);
    pickPhoto = () async => PickedPhoto(bytes, 'image/png');
    final server = _server();
    await _signIn(tester, server);
    await _openProfile(tester);
    expect(find.text('0 of 6'), findsOneWidget);
    await tester.tap(find.byKey(const Key('photo-add')));
    await _settle(tester);
    expect(server.uploads, [bytes]);
    expect(find.text('Waiting for review'), findsOneWidget);
    expect(find.text('1 of 6'), findsOneWidget);
    expect(
      find.text('Uploaded. A person checks it before anyone else sees it.'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the picker uploads nothing', (tester) async {
    pickPhoto = () async => null;
    final server = _server();
    await _signIn(tester, server);
    await _openProfile(tester);
    await tester.tap(find.byKey(const Key('photo-add')));
    await _settle(tester);
    expect(server.uploads, isEmpty);
  });

  testWidgets('make another photo the main one, or delete one', (tester) async {
    final server = _server()
      ..myPhotos.addAll([
        for (final id in ['a', 'b'])
          {
            'photo_id': id,
            'state': 'approved',
            'reject_reason': null,
            'url': '/v1/media/$id?p=view',
          },
        {
          'photo_id': 'c',
          'state': 'rejected',
          'reject_reason': 'someone_else',
          'url': null,
        },
      ]);
    await _signIn(tester, server);
    await _openProfile(tester);
    expect(find.text('Main'), findsOneWidget);
    expect(find.text('Not approved'), findsOneWidget);
    expect(find.text('it looks like someone else'), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo-b')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('photo-make-main')));
    await _settle(tester);
    expect([for (final p in server.myPhotos) p['photo_id']], ['b', 'a', 'c']);

    await tester.tap(find.byKey(const Key('photo-c')));
    await _settle(tester);
    expect(find.byKey(const Key('photo-make-main')), findsNothing);
    await tester.tap(find.byKey(const Key('photo-delete')));
    await _settle(tester);
    expect([for (final p in server.myPhotos) p['photo_id']], ['b', 'a']);
  });

  testWidgets('cards show approved photos from the server', (tester) async {
    final server = _server()..addPerson('Maya', photos: ['m1', 'm2']);
    await _signIn(tester, server);
    await dismissSwipeTutorial(tester);
    final photos = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<ServerPhoto>()
        .map((p) => p.url)
        .toList();
    expect(photos, contains('http://vawra.test/v1/media/m1?p=view'));
    expect(find.bySemanticsLabel(RegExp('Photo of Maya')), findsWidgets);
  });

  testWidgets('moderators approve or reject photos with a reason', (
    tester,
  ) async {
    final server = _server()
      ..moderator = true
      ..modPhotos.addAll([
        for (final id in ['x', 'y'])
          {
            'photo_id': id,
            'account_id': 'someone',
            'display_name': 'Ben',
            'created_at': '2026-09-29T10:00:00.000Z',
            'url': '/v1/media/$id?p=review',
          },
      ]);
    await _signIn(tester, server);
    await dismissSwipeTutorial(tester);
    await tester.tap(find.byKey(const Key('profile-tab')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('open-settings')));
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-moderation')),
      200,
    );
    await tester.ensureVisible(find.byKey(const Key('settings-moderation')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('settings-moderation')));
    await _settle(tester);
    await tester.tap(find.text('Photos (2)'));
    await _settle(tester);

    await tester.ensureVisible(find.byKey(const Key('mod-photo-approve-x')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('mod-photo-approve-x')));
    await _settle(tester);
    expect(server.decisions, ['photos:x:approved']);

    await tester.ensureVisible(find.byKey(const Key('mod-photo-reject-y')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('mod-photo-reject-y')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('mod-reason-contact_info')));
    await _settle(tester);
    expect(server.decisions, ['photos:x:approved', 'photos:y:rejected']);
    expect(find.text('No photos waiting.'), findsOneWidget);
  });
}
