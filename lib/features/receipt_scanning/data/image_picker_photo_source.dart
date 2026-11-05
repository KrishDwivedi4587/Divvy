import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/receipt_photo_source.dart';

/// Opens the system camera or photo picker and returns the file chosen, or null
/// if the user backed out. Throws [PlatformException] for platform failures.
typedef PickImage = Future<String?> Function(PhotoSource source);

/// Camera and gallery through the `image_picker` plugin.
///
/// Both go through the system's own UI, so they behave the same on a phone as
/// in a release build. Images stay on the device: nothing here uploads.
///
/// JPEG at 85% keeps a receipt legible while avoiding multi-megabyte HEIC
/// files and sidesteps HEIC compatibility problems. There is no crop step on
/// purpose: a square crop would cut the bottom off a tall receipt.
///
/// On iOS the gallery runs out of process (PHPicker), so the app only ever
/// receives the one photo the user picks and never needs library permission.
/// The camera asks for permission itself the first time; if the user refuses,
/// iOS will not ask again and the plugin reports `camera_access_denied`.
class ImagePickerPhotoSource implements ReceiptPhotoSource {
  ImagePickerPhotoSource({PickImage? pick}) : _pick = pick ?? _pickWithPlugin;

  final PickImage _pick;

  static Future<String?> _pickWithPlugin(PhotoSource source) async {
    final file = await ImagePicker().pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    return file?.path;
  }

  @override
  Future<PhotoResult> takePhoto() => _run(PhotoSource.camera);

  @override
  Future<PhotoResult> pickFromGallery() => _run(PhotoSource.gallery);

  Future<PhotoResult> _run(PhotoSource source) async {
    try {
      final path = await _pick(source);
      if (path == null) return const PhotoCancelled();
      if (path.isEmpty) {
        return const PhotoFailed('No photo came back. Please try again.');
      }
      return PhotoPicked(path, source);
    } on PlatformException catch (e) {
      return describePickerError(e, source);
    } catch (_) {
      return PhotoFailed(_genericMessage(source));
    }
  }

  /// Turns a plugin error into a result the UI can show. Public for tests.
  static PhotoResult describePickerError(
    PlatformException e,
    PhotoSource source,
  ) {
    final code = e.code;
    if (code == 'camera_access_denied' || code == 'camera_access_restricted') {
      return const PhotoDenied();
    }
    // A photo-library refusal is not expected from PHPicker, but if the
    // plugin falls back to a mode that needs access, say so.
    if (code == 'photo_access_denied' || code == 'photo_access_restricted') {
      return const PhotoFailed(
        'Divvy cannot open your photos. Allow photo access in Settings, '
        'or take a photo instead.',
      );
    }
    if (source == PhotoSource.camera &&
        (code == 'no_available_camera' ||
            RegExp(
              'simulator|not available|no camera|unavailable',
              caseSensitive: false,
            ).hasMatch('${e.message}'))) {
      return const PhotoFailed(
        "The camera isn't available on this device. "
        'Choose a photo from your library instead.',
      );
    }
    return PhotoFailed(_genericMessage(source));
  }

  static String _genericMessage(PhotoSource source) =>
      source == PhotoSource.camera
      ? "Couldn't open the camera. Please try again, "
            'or choose a photo from your library.'
      : "Couldn't open your photo library. Please try again.";
}
