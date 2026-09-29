import 'package:flutter/widgets.dart';

import '../../data/api/server_photo.dart';

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

/// Approved photos for a server person, as short-lived links, in order.
final _serverPhotos = <String, List<String>>{};

void registerServerPhotos(String photoKey, List<String> urls) {
  if (urls.isEmpty) {
    _serverPhotos.remove(photoKey);
  } else {
    _serverPhotos[photoKey] = urls;
  }
}

/// A person's photos after the main one (for the card's photo pager).
List<String> morePhotos(String photoKey) =>
    (_serverPhotos[photoKey] ?? const []).skip(1).toList();

bool _isLink(String key) => key.startsWith('http');

ImageProvider profileImage(String photoKey) {
  if (_isLink(photoKey)) return ServerPhoto(photoKey);
  final photos = _serverPhotos[photoKey];
  if (photos != null) return ServerPhoto(photos.first);
  return AssetImage(
    _demoPortraits[photoKey] ??
        (isServerPerson(photoKey) ? noPhotoAsset : photoKey),
  );
}

String portraitLabel(String name, String photoKey) {
  if (_isLink(photoKey) || _serverPhotos.containsKey(photoKey)) {
    return 'Photo of $name';
  }
  return isServerPerson(photoKey) && !isDemoPerson(photoKey)
      ? 'No photo yet for $name'
      : 'Synthetic portrait of $name';
}
