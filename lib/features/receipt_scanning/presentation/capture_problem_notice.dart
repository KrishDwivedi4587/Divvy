import 'package:flutter/material.dart';

import '../../../core/widgets/notice.dart';
import '../application/photo_capture_notifier.dart';

/// Explains why the camera or gallery did not give a photo.
class CaptureProblemNotice extends StatelessWidget {
  const CaptureProblemNotice({required this.problem, super.key});

  final CaptureProblem problem;

  @override
  Widget build(BuildContext context) {
    return switch (problem) {
      CameraDenied() => const Notice(
        tone: NoticeTone.warning,
        title: 'Camera access is off',
        message:
            'Divvy needs the camera to photograph a bill. Open Settings, tap '
            'Divvy, and turn on Camera. You can still choose a photo from '
            'your library.',
      ),
      CaptureFailed(:final message) => Notice(
        tone: NoticeTone.error,
        message: message,
      ),
    };
  }
}
