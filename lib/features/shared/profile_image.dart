import 'package:flutter/widgets.dart';

/// Server people are keyed as `account:<id>` in place of a bundled portrait.
/// Their photos arrive with the reviewed media service; until then a neutral
/// placeholder is shown.
const serverPersonPrefix = 'account:';
const noPhotoAsset = 'assets/branding/no_photo.png';

bool isServerPerson(String photoKey) => photoKey.startsWith(serverPersonPrefix);

/// Local test server only: seeded demo members carry one of the app's bundled
/// synthetic portraits (backend/scripts/seed-demo.ts). Real accounts never do.
final _demoPortraits = <String, String>{};

void registerDemoPortrait(String photoKey, String? asset) {
  if (asset != null && asset.startsWith('assets/profiles/')) {
    _demoPortraits[photoKey] = asset;
  }
}

bool isDemoPerson(String photoKey) => _demoPortraits.containsKey(photoKey);

ImageProvider profileImage(String photoKey) => AssetImage(
  _demoPortraits[photoKey] ??
      (isServerPerson(photoKey) ? noPhotoAsset : photoKey),
);

String portraitLabel(String name, String photoKey) =>
    isServerPerson(photoKey) && !isDemoPerson(photoKey)
    ? 'No photo yet for $name'
    : 'Synthetic portrait of $name';
