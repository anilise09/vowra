import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

/// The connection photos load through: the app's own client (set by
/// VawraApi), so tests and the app use the same path.
http.Client serverPhotoClient = http.Client();

/// A photo from the Vawra server, loaded from its short-lived link. Links are
/// bound to the viewer and expire; the server checks access again each time.
@immutable
class ServerPhoto extends ImageProvider<ServerPhoto> {
  const ServerPhoto(this.url);

  final String url;

  @override
  Future<ServerPhoto> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ServerPhoto>(this);

  @override
  ImageStreamCompleter loadImage(
    ServerPhoto key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: 1,
    debugLabel: 'ServerPhoto',
  );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final response = await serverPhotoClient.get(Uri.parse(url));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw StateError('photo unavailable (${response.statusCode})');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) => other is ServerPhoto && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'ServerPhoto()';
}
