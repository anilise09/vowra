import 'package:flutter/widgets.dart';

/// Server people are keyed as `account:<id>` in place of a bundled portrait.
/// Their photos arrive with the reviewed media service; until then a neutral
/// placeholder is shown.
const serverPersonPrefix = 'account:';
const noPhotoAsset = 'assets/branding/no_photo.png';

bool isServerPerson(String photoKey) => photoKey.startsWith(serverPersonPrefix);

ImageProvider profileImage(String photoKey) =>
    AssetImage(isServerPerson(photoKey) ? noPhotoAsset : photoKey);

String portraitLabel(String name, String photoKey) => isServerPerson(photoKey)
    ? 'No photo yet for $name'
    : 'Synthetic portrait of $name';
