import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/navigation.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/step_progress.dart';
import '../../../receipt_scanning/application/photo_capture_notifier.dart';
import '../../../receipt_scanning/domain/receipt_photo_source.dart';
import '../../../receipt_scanning/presentation/capture_problem_notice.dart';
import '../../application/bill_draft_notifier.dart';
import 'source_option.dart';

/// Step 1: get the receipt, by camera or from the photo library, or skip the
/// photo and enter the bill by hand.
class SourceScreen extends ConsumerStatefulWidget {
  const SourceScreen({super.key});

  @override
  ConsumerState<SourceScreen> createState() => _SourceScreenState();
}

class _SourceScreenState extends ConsumerState<SourceScreen> {
  PhotoSource? _active;

  Future<void> _choose(PhotoSource source) async {
    setState(() => _active = source);
    final picked = await ref
        .read(photoCaptureProvider.notifier)
        .capture(source);
    if (!mounted) return;
    setState(() => _active = null);
    if (picked) context.open(AppRoutes.createPreview);
  }

  void _manual() {
    ref.read(billDraftProvider.notifier).clearPhoto();
    ref.read(photoCaptureProvider.notifier).clearProblem();
    context.open(AppRoutes.createReview);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final capture = ref.watch(photoCaptureProvider);
    final busy = capture.busy;
    final problem = capture.problem;

    return ScreenScaffold(
      title: 'New bill',
      belowHeader: const StepProgress(step: 1, of: 5, label: 'Receipt'),
      children: [
        Text('Add the receipt', style: t.headlineMedium),
        const SizedBox(height: Space.sm),
        Text(
          'Divvy reads the items and prices for you. You can correct '
          'anything before it is saved.',
          style: t.bodyMedium?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.xl),
        if (problem != null) ...[
          CaptureProblemNotice(problem: problem),
          const SizedBox(height: Space.lg),
        ],
        SourceOption(
          icon: Icons.photo_camera_outlined,
          title: 'Take photo',
          subtitle: 'Photograph the bill with your camera',
          busy: _active == PhotoSource.camera,
          onTap: busy ? null : () => _choose(PhotoSource.camera),
        ),
        const SizedBox(height: Space.md),
        SourceOption(
          icon: Icons.photo_library_outlined,
          title: 'Upload from gallery',
          subtitle: 'Choose a photo you already took',
          busy: _active == PhotoSource.gallery,
          onTap: busy ? null : () => _choose(PhotoSource.gallery),
        ),
        const SizedBox(height: Space.xl),
        AppButton(
          label: 'Enter details manually',
          icon: Icons.edit_note_rounded,
          kind: AppButtonKind.text,
          onPressed: busy ? null : _manual,
        ),
      ],
    );
  }
}
