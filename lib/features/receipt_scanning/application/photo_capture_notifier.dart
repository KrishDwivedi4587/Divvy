import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../../bills/application/bill_draft_notifier.dart';
import '../domain/receipt_photo_source.dart';
import 'scan_notifier.dart';

/// Why the camera or gallery did not give a photo, when that is something the
/// user should be told about. A cancelled picker is not a problem.
sealed class CaptureProblem {
  const CaptureProblem();
}

/// The operating system refused camera access.
final class CameraDenied extends CaptureProblem {
  const CameraDenied();
}

final class CaptureFailed extends CaptureProblem {
  const CaptureFailed(this.message);

  final String message;
}

class CaptureState {
  const CaptureState({this.busy = false, this.problem});

  final bool busy;
  final CaptureProblem? problem;
}

/// Opens the camera or gallery and, on success, puts the photo on the draft.
/// Camera and gallery share this one path, so retake, replace, cancel and every
/// failure behave the same whichever way the photo is chosen.
class PhotoCaptureNotifier extends Notifier<CaptureState> {
  @override
  CaptureState build() => const CaptureState();

  void clearProblem() => state = const CaptureState();

  /// Returns true if a photo was chosen and is now on the draft.
  Future<bool> capture(PhotoSource source) async {
    if (state.busy) return false;
    state = const CaptureState(busy: true);

    final photos = ref.read(photoSourceProvider);
    final result = source == PhotoSource.camera
        ? await photos.takePhoto()
        : await photos.pickFromGallery();

    switch (result) {
      case PhotoPicked(:final path):
        ref.read(billDraftProvider.notifier).setPhoto(path);
        // A new photo makes any earlier scan stale.
        ref.read(scanProvider.notifier).reset();
        state = const CaptureState();
        return true;
      case PhotoCancelled():
        state = const CaptureState();
        return false;
      case PhotoDenied():
        state = const CaptureState(problem: CameraDenied());
        return false;
      case PhotoFailed(:final message):
        state = CaptureState(problem: CaptureFailed(message));
        return false;
    }
  }
}

final photoCaptureProvider =
    NotifierProvider<PhotoCaptureNotifier, CaptureState>(
      PhotoCaptureNotifier.new,
    );
