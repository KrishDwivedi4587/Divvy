import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/navigation.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/step_progress.dart';
import '../../../receipt_scanning/application/photo_capture_notifier.dart';
import '../../../receipt_scanning/application/scan_notifier.dart';
import '../../../receipt_scanning/domain/receipt_photo_source.dart';
import '../../../receipt_scanning/presentation/capture_problem_notice.dart';
import '../../../receipt_scanning/presentation/receipt_image.dart';
import '../../application/bill_draft_notifier.dart';

/// Step 1b: check the photo, retake or replace it, then have it read.
class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  Future<void> _read(String path) async {
    final draft = ref.read(billDraftProvider);
    if (draft.items.isNotEmpty) {
      final ok = await confirmAction(
        context,
        title: 'Read the receipt again?',
        message:
            'This replaces the items and charges you have so far with what '
            'is read from the photo.',
        confirmLabel: 'Read again',
      );
      if (!ok || !mounted) return;
    }
    await ref.read(scanProvider.notifier).scan(path);
    if (mounted) context.open(AppRoutes.createReview);
  }

  void _skip() {
    ref.read(photoCaptureProvider.notifier).clearProblem();
    context.open(AppRoutes.createReview);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final path = ref.watch(billDraftProvider.select((d) => d.imagePath));
    final scanning = ref.watch(scanProvider) is Scanning;
    final capture = ref.watch(photoCaptureProvider);
    final locked = scanning || capture.busy;

    if (path == null) {
      return ScreenScaffold(
        title: 'Receipt',
        body: EmptyState(
          icon: Icons.image_not_supported_outlined,
          title: 'No photo chosen',
          message: 'Take or choose a photo of the bill to continue.',
          actionLabel: 'Choose a photo',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    return ScreenScaffold(
      title: 'Check the photo',
      belowHeader: const StepProgress(step: 1, of: 5, label: 'Receipt'),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: scanning ? 'Reading your receipt…' : 'Read receipt',
            icon: Icons.document_scanner_outlined,
            loading: scanning,
            onPressed: locked ? null : () => _read(path),
          ),
          const SizedBox(height: Space.xs),
          AppButton(
            label: 'Skip, enter details by hand',
            kind: AppButtonKind.text,
            onPressed: locked ? null : _skip,
          ),
        ],
      ),
      children: [
        GestureDetector(
          onTap: () => ReceiptViewer.show(context, ReceiptImage(path: path)),
          child: Semantics(
            button: true,
            label: 'Photo of your receipt. Tap to view full screen.',
            child: Container(
              height: _frameHeight(context),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: Corners.card,
                border: Border.all(color: c.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: ReceiptImage(path: path, cacheWidth: 1400),
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        Text(
          'Tap the photo to zoom. Check the prices are readable.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: c.textSecondary),
          textAlign: TextAlign.center,
        ),
        if (capture.problem != null) ...[
          const SizedBox(height: Space.lg),
          CaptureProblemNotice(problem: capture.problem!),
        ],
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Retake',
                icon: Icons.photo_camera_outlined,
                kind: AppButtonKind.secondary,
                onPressed: locked
                    ? null
                    : () => ref
                          .read(photoCaptureProvider.notifier)
                          .capture(PhotoSource.camera),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppButton(
                label: 'Replace',
                icon: Icons.photo_library_outlined,
                kind: AppButtonKind.secondary,
                onPressed: locked
                    ? null
                    : () => ref
                          .read(photoCaptureProvider.notifier)
                          .capture(PhotoSource.gallery),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tall enough to read, short enough to leave the buttons on screen; scales
  /// with the screen rather than assuming a size.
  double _frameHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.38).clamp(240.0, 460.0);
  }
}
