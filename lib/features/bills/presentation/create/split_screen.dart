import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/navigation.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/notice.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/segmented_pills.dart';
import '../../../../core/widgets/step_progress.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../application/bill_draft_notifier.dart';
import '../../domain/bill_draft.dart';
import '../../domain/models/bill_record.dart';
import 'custom_amounts_section.dart';
import 'split_item_card.dart';
import 'split_parts.dart';

String _modeLabel(SplitMode m) => switch (m) {
  SplitMode.equal => 'Equally',
  SplitMode.byItem => 'By item',
  SplitMode.custom => 'Amounts',
};

String? _problemText(BillProblem p) => switch (p) {
  BillProblem.unassignedItems => 'Every item needs at least one person.',
  BillProblem.customAmountsMismatch =>
    'The amounts must add up to the items total.',
  BillProblem.noPayer => 'Choose who paid the bill.',
  _ => null,
};

/// Step 4: decide how the bill is divided, and who paid.
class SplitScreen extends ConsumerWidget {
  const SplitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final draft = ref.watch(billDraftProvider);
    final notifier = ref.read(billDraftProvider.notifier);
    final now = ref.watch(clockProvider)();
    final problems = draft.problems(now);
    final blocking = [
      for (final p in problems)
        if (_problemText(p) != null) p,
    ];

    return ScreenScaffold(
      title: 'Split the bill',
      belowHeader: const StepProgress(step: 4, of: 5, label: 'Split'),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (blocking.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Text(
                _problemText(blocking.first)!,
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: c.warning),
              ),
            ),
          AppButton(
            label: 'See summary',
            icon: Icons.arrow_forward_rounded,
            onPressed: problems.isEmpty
                ? () => context.open(AppRoutes.createSummary)
                : null,
          ),
        ],
      ),
      children: [
        SegmentedPills<SplitMode>(
          values: SplitMode.values,
          selected: draft.splitMode,
          label: _modeLabel,
          onChanged: notifier.setSplitMode,
        ),
        const SizedBox(height: Space.xl),
        const SectionHeader('Paid by'),
        PayerSelector(
          participants: draft.participants,
          payerId: draft.payerId,
          onSelected: notifier.setPayer,
        ),
        const SizedBox(height: Space.xl),
        switch (draft.splitMode) {
          SplitMode.equal => const Notice(
            message:
                'Every item is shared equally by everyone on the bill, and '
                'taxes and charges are shared in proportion.',
          ),
          SplitMode.byItem => _ByItem(draft: draft),
          SplitMode.custom => const CustomAmountsSection(),
        },
        const SizedBox(height: Space.xl),
        TotalsPreview(draft: draft, now: now),
      ],
    );
  }
}

class _ByItem extends ConsumerWidget {
  const _ByItem({required this.draft});

  final BillDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(billDraftProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Who had what'),
        // On its own line: beside the heading it cannot fit at large text sizes.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: notifier.assignEverythingToEveryone,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: EdgeInsets.zero,
            ),
            child: const Text('Everyone shares all'),
          ),
        ),
        const SizedBox(height: Space.xs),
        for (final item in draft.items) ...[
          SplitItemCard(
            item: item,
            participants: draft.participants,
            assigned: draft.allocations[item.id] ?? const <String>{},
            currency: draft.currency,
            onToggle: (pid) => notifier.toggleAllocation(item.id, pid),
            onEveryone: () {
              final everyone =
                  (draft.allocations[item.id] ?? const <String>{}).length ==
                  draft.participants.length;
              if (everyone) {
                notifier.clearItemAssignment(item.id);
              } else {
                notifier.assignItemToEveryone(item.id);
              }
            },
          ),
          const SizedBox(height: Space.md),
        ],
      ],
    );
  }
}
