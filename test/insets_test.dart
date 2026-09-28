import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow.dart';

/// Samsung with three-button navigation: 48 logical pixels at the bottom
/// belong to the system. Nothing tappable may sit behind them.
void main() {
  testWidgets('bottom bar and profile actions stay above system buttons', (
    tester,
  ) async {
    const navBar = 48.0;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    tester.view.padding = const FakeViewPadding(bottom: navBar * 2.625);
    tester.view.viewPadding = const FakeViewPadding(bottom: navBar * 2.625);
    addTearDown(tester.view.reset);
    final screenBottom = 2340 / 2.625;

    await enterDiscovery(tester);
    final bar = tester.getRect(find.byType(NavigationBar));
    expect(bar.bottom, lessThanOrEqualTo(screenBottom - navBar));

    await tester.tap(find.byKey(const Key('open-profile-details')));
    await tester.pumpAndSettle();
    final like = tester.getRect(find.byTooltip('Like').last);
    expect(like.bottom, lessThanOrEqualTo(screenBottom - navBar));
  });
}
