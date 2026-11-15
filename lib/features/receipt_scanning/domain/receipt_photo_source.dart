/// Camera and photo-library access, as the rest of the app sees it.
///
/// Both entry points return the same [PhotoResult], so the camera and the
/// gallery feed one shared workflow (capture, preview, scan). Every
/// non-success outcome is an explicit case rather than a thrown exception, so
/// the UI can give each one a proper message instead of a blank screen.
library;

enum PhotoSource { camera, gallery }

sealed class PhotoResult {
  const PhotoResult();
}

/// A photo was chosen. [path] is a temporary file the plugin wrote; it is
/// copied into app storage only if the bill is saved.
final class PhotoPicked extends PhotoResult {
  const PhotoPicked(this.path, this.source);

  final String path;
  final PhotoSource source;
}

/// The user closed the camera or picker without choosing anything.
final class PhotoCancelled extends PhotoResult {
  const PhotoCancelled();
}

/// The operating system refused camera access. On iOS the prompt is shown only
/// once, so after a refusal the only way back is Settings.
final class PhotoDenied extends PhotoResult {
  const PhotoDenied();
}

final class PhotoFailed extends PhotoResult {
  const PhotoFailed(this.message);

  /// Plain language, safe to show as is.
  final String message;
}

abstract interface class ReceiptPhotoSource {
  Future<PhotoResult> takePhoto();
  Future<PhotoResult> pickFromGallery();
}
