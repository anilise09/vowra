import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/api/server_photo.dart';
import '../data/api/vawra_api.dart';
import '../features/profile/photo_tips.dart';
import '../theme/vawra_theme.dart';
import 'server_flow.dart' show describeApiError;

/// A photo chosen on the phone, ready to upload.
class PickedPhoto {
  const PickedPhoto(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

/// The system photo picker (no storage permission needed on current
/// Android). The picker re-encodes to a JPEG at most 2048 px; the server
/// removes all metadata anyway. Replaced in tests.
Future<PickedPhoto?> Function() pickPhoto = () async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 90,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return PickedPhoto(bytes, _sniff(bytes));
};

String _sniff(Uint8List b) {
  if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50) return 'image/png';
  if (b.length > 12 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

const rejectReasonLabels = {
  'nudity': 'nudity or sexual content',
  'not_a_person': 'it doesn’t show a person',
  'someone_else': 'it looks like someone else',
  'contact_info': 'it shows contact details',
  'other': 'it doesn’t meet the photo rules',
  'unreadable': 'the file couldn’t be read',
};

String _uploadError(Object e) => switch (e) {
  ApiException(code: 'photo_limit') =>
    'You can have 6 photos. Delete one first.',
  ApiException(code: 'upload_limit') =>
    'That’s a lot of uploads today. Try again tomorrow.',
  ApiException(code: 'unreadable_image' || 'wrong_type') =>
    'That file couldn’t be read as a photo. Try a JPEG or PNG.',
  _ => describeApiError(e),
};

/// Your photos on the server: up to 6, each checked by a person before
/// anyone else sees it. The first approved one is your main photo.
class ServerPhotosCard extends StatefulWidget {
  const ServerPhotosCard({super.key, required this.api});

  final VawraApi api;

  @override
  State<ServerPhotosCard> createState() => _ServerPhotosCardState();
}

class _ServerPhotosCardState extends State<ServerPhotosCard> {
  List<MyPhoto>? photos;
  bool busy = false;
  String? message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.api.myPhotos();
      if (mounted) setState(() => photos = list);
    } catch (e) {
      if (mounted) setState(() => message = describeApiError(e));
    }
  }

  Future<void> _add() async {
    final picked = await pickPhoto();
    if (picked == null) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.api.uploadPhoto(picked.bytes, picked.mimeType);
      await _load();
      if (mounted) {
        setState(
          () => message =
              'Uploaded. A person checks it before anyone else sees it.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = _uploadError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _manage(MyPhoto photo, int index) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0 && photo.state != 'rejected')
              ListTile(
                key: const Key('photo-make-main'),
                leading: const Icon(Icons.star_outline_rounded),
                title: const Text('Make this my main photo'),
                onTap: () => Navigator.pop(sheetContext, 'main'),
              ),
            ListTile(
              key: const Key('photo-delete'),
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: VawraColors.coralDark,
              ),
              title: const Text('Delete photo'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      if (choice == 'delete') {
        await widget.api.deletePhoto(photo.id);
      } else {
        final ids = [for (final p in photos!) p.id]
          ..remove(photo.id)
          ..insert(0, photo.id);
        await widget.api.orderPhotos(ids);
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => message = describeApiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = photos;
    return Container(
      key: const Key('photos-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E5EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, color: VawraColors.plum),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Photos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (list != null)
                Text(
                  '${list.where((p) => p.state != 'rejected').length} of 6',
                  style: const TextStyle(color: VawraColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'A person checks every photo before anyone else sees it. Location '
            'and camera details are removed.',
          ),
          const SizedBox(height: 12),
          if (list == null)
            const Center(child: CircularProgressIndicator())
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3 / 4,
              children: [
                for (final (i, p) in list.indexed) _tile(p, i),
                if (list.where((p) => p.state != 'rejected').length < 6)
                  _addTile(),
              ],
            ),
          if (message case final text?)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(text, key: const Key('photos-message')),
            ),
          TextButton.icon(
            key: const Key('photo-tips'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              builder: (_) => const PhotoTipsSheet(),
            ),
            icon: const Icon(Icons.lightbulb_outline_rounded),
            label: const Text('Photo tips'),
          ),
        ],
      ),
    );
  }

  Widget _addTile() => Material(
    color: VawraColors.blush,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: const Key('photo-add'),
      borderRadius: BorderRadius.circular(16),
      onTap: busy ? null : _add,
      child: Center(
        child: busy
            ? const CircularProgressIndicator()
            : const Icon(
                Icons.add_a_photo_outlined,
                color: VawraColors.coral,
                size: 30,
              ),
      ),
    ),
  );

  Widget _tile(MyPhoto p, int index) {
    final (label, color) = switch (p.state) {
      'pending_review' => ('Waiting for review', VawraColors.plum),
      'rejected' => ('Not approved', VawraColors.coralDark),
      _ => (index == 0 ? 'Main' : null, VawraColors.coral),
    };
    return Semantics(
      label: p.state == 'rejected'
          ? 'Photo not approved: ${rejectReasonLabels[p.rejectReason] ?? ''}'
          : 'Your photo ${index + 1}${label == null ? '' : ', $label'}',
      button: true,
      child: InkWell(
        key: Key('photo-${p.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _manage(p, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (p.url case final url? when p.state != 'rejected')
                Image(
                  image: ServerPhoto(widget.api.absolute(url)),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: VawraColors.lavender),
                )
              else
                ColoredBox(
                  color: VawraColors.lavender,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: Text(
                        rejectReasonLabels[p.rejectReason] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              if (label != null)
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
