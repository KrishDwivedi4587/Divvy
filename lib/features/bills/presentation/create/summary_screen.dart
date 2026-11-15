import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/notice.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/states.dart';
import '../../../../core/widgets/step_progress.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/data_providers.dart';
import '../../../receipt_scanning/application/scan_notifier.dart';
import '../../application/bill_draft_notifier.dart';
import '../../application/bill_service.dart';
import '../../domain/bill_draft.dart';
import '../../domain/bill_text.dart';
import '../../domain/engine/settle.dart';
import '../../domain/models/bill_record.dart';
import 'create_people_screen.dart' show minToSplit;
import 'review_parts.dart';
import 'review_rows.dart';
import 'summary_people.dart';

/// Step 5: the final numbers, checked once more, then saved.
class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _save(BillDraft draft) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    // Navigation replaces this screen, so keep the router and messenger now.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final record = await ref.read(billActionsProvider).save(draft);
      ref.invalidate(billDraftProvider);
      ref.invalidate(scanProvider);
      router.go(AppRoutes.history);
      // Not awaited: a push completes only when that screen is closed.
      unawaited(router.push<void>(AppRoutes.bill(record.id)));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Bill saved')));
    } on BillNotSavable {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'This bill is not complete yet. Go back and check each step.';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            "Couldn't save the bill. Nothing was changed. Try again, and "
            'if it keeps happening, free up some space on your phone.';
      });
    }
  }

  String _label(BillRecord record, String adjustmentId) {
    for (final a in record.adjustments) {
      if (a.id == adjustmentId) return adjustmentLabel(a);
    }
    return 'Charge';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final draft = ref.watch(billDraftProvider);
    final now = ref.watch(clockProvider)();
    final problems = draft.problems(now);

    // Reached directly or with the flow incomplete: say so, don't crash.
    if (problems.isNotEmpty || draft.participants.length < minToSplit) {
      return ScreenScaffold(
        title: 'Summary',
        body: EmptyState(
          icon: Icons.fact_check_outlined,
          title: 'This bill is not finished',
          message: 'Go back and complete the earlier steps.',
          actionLabel: 'Back',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final record = draft.toRecord(id: 'preview', now: now);
    final settlement = computeSettlement(record.toEngineBill());
    final payer = record.payer;
    final mismatch = draft.totalMismatch(now);

    return ScreenScaffold(
      title: 'Summary',
      belowHeader: const StepProgress(step: 5, of: 5, label: 'Save'),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Notice(tone: NoticeTone.error, message: _error!),
            ),
          AppButton(
            label: 'Save bill',
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: () => _save(draft),
          ),
        ],
      ),
      children: [
        AppCard(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.title,
                style: t.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                fullDate(record.billDate),
                style: t.bodySmall?.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: Space.lg),
              Text(
                'Total',
                style: t.bodySmall?.copyWith(color: c.textSecondary),
              ),
              MoneyText(
                settlement.grandTotal,
                record.currency,
                style: t.displayMedium,
              ),
              const SizedBox(height: Space.sm),
              Text(
                '${peopleCount(record.participants.length)}'
                '${payer == null ? '' : ' · Paid by ${payer.name}'}',
                style: t.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        if (mismatch != null) ...[
          const SizedBox(height: Space.lg),
          const Notice(
            tone: NoticeTone.warning,
            message:
                'This differs from the total printed on the receipt. If '
                'that is not expected, go back and check the items.',
          ),
        ],
        const SizedBox(height: Space.xl),
        SummaryPeople(record: record, settlement: settlement),
        const SizedBox(height: Space.xl),
        AppCard(
          child: Column(
            children: [
              TotalLine(
                label: 'Items',
                amount: settlement.itemsSubtotal,
                currency: record.currency,
              ),
              for (final a in settlement.adjustmentTotals)
                TotalLine(
                  label: _label(record, a.adjustmentId),
                  amount: a.amount,
                  currency: record.currency,
                ),
              const SizedBox(height: Space.sm),
              const Hairline(),
              const SizedBox(height: Space.sm),
              TotalLine(
                label: 'Total',
                amount: settlement.grandTotal,
                currency: record.currency,
                strong: true,
              ),
            ],
          ),
        ),
        if (draft.imagePath != null) ...[
          const SizedBox(height: Space.xl),
          PhotoStrip(path: draft.imagePath!),
        ],
      ],
    );
  }
}
