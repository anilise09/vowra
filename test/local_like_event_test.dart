import 'package:ember_app/domain/local_like_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local like creates outbound and notification preview events', () {
    final events = localLikeEventsFor(
      profileAssetPath: 'assets/profiles/maya.png',
      profileName: 'Maya',
      createdAt: DateTime.utc(2026, 9, 22, 12),
    );

    expect(events, hasLength(2));
    expect(events[0].type, LocalLikeEventType.outboundLike);
    expect(events[0].type.backendKey, 'outbound_like');
    expect(events[1].type, LocalLikeEventType.notificationPreview);
    expect(events[1].summary, contains('someone liked your profile'));
  });

  test('mutual like appends a connectable free-core event', () {
    final events = localLikeEventsFor(
      profileAssetPath: 'assets/profiles/maya.png',
      profileName: 'Maya',
      createdAt: DateTime.utc(2026, 9, 22, 12),
      mutualLike: true,
    );

    expect(events.map((event) => event.type), <LocalLikeEventType>[
      LocalLikeEventType.outboundLike,
      LocalLikeEventType.notificationPreview,
      LocalLikeEventType.mutualLike,
    ]);
    expect(events.last.type.backendKey, 'mutual_like');
    expect(events.last.summary, contains('free core'));
  });
}
