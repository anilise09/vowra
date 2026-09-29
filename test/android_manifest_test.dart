import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Android permissions Vawra declares: exactly what its features need,
/// no more. A missing one can crash on a real phone where no JVM test looks
/// (WebRTC aborted the app without ACCESS_NETWORK_STATE as a call connected).
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();
  final declared = RegExp(
    r'<uses-permission android:name="android\.permission\.([A-Z_]+)"\s*/>',
  ).allMatches(manifest).map((m) => m.group(1)!).toSet();

  test('declares what calls, location and the server need', () {
    expect(declared, {
      'INTERNET',
      'ACCESS_COARSE_LOCATION',
      'CAMERA',
      'RECORD_AUDIO',
      'MODIFY_AUDIO_SETTINGS',
      'ACCESS_NETWORK_STATE',
    });
  });

  test('never precise or background location', () {
    expect(manifest, isNot(contains('ACCESS_FINE_LOCATION"/>')));
    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    expect(
      manifest,
      contains(
        '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" tools:node="remove"/>',
      ),
    );
  });
}
