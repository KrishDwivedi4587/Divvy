import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/errors/domain_error.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/expandable_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/notice.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/states.dart';
import '../../../../shared/providers/data_providers.dart';
import '../../../receipt_scanning/presentation/receipt_image.dart';
import '../../domain/bill_text.dart';
import '../../domain/engine/settle.dart';
import '../../domain/models/bill_record.dart';
import '../../domain/models/settlement.dart';
import 'items_section.dart';
import 'participants_section.dart';

enum _Action { rename, copy, delete }

class BillDetailScreen extends ConsumerWidget {
  const BillDetailScreen({required this.billId, super.key});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = ref.watch(billDetailProvider(billId));

    return bill.when(
      loading: () => const ScreenScaffold(title: 'Bill', body: LoadingState()),
      error: (e, _) => ScreenScaffold(
        title: 'Bill',
        body: ErrorState(
          message: "This bill couldn't be loaded.",
          onRetry: () => ref.invalidate(billDetailProvider(billId)),
        ),
      ),
      data: (record) {
        if (record == null) {
          return const ScreenScaffold(
            title: 'Bill',
            body: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Bill not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        return _Loaded(record: record);
      },
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.record});

  final BillRecord record;

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _Action action,
    Settlement? settlement,
  ) async {
    switch (action) {
      case _Action.rename:
        final title = await _askTitle(context, record.title);
        if (title != null && context.mounted) {
          await ref.read(billActionsProvider).rename(record.id, title);
        }
      case _Action.copy:
        if (settlement == null) return;
        await Clipboard.setData(
          ClipboardData(text: buildShareText(record, settlement)),
        );
        if (context.mounted) showMessage(context, 'Summary copied');
      case _Action.delete:
        final ok = await confirmAction(
          context,
          title: 'Delete this bill?',
          message:
              'The bill, its receipt photo and its history are removed '
              'from this phone. This cannot be undone.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok || !context.mounted) return;
        await ref.read(billActionsProvider).delete(record.id);
        if (context.mounted) Navigator.of(context).maybePop();
    }
  }

  Future<String?> _askTitle(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename bill'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(context).pop(text.isEmpty ? null : text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;

    Settlement? settlement;
    String? problem;
    try {
      settlement = computeSettlement(record.toEngineBill());
      if (!settlement.reconciles ||
          settlement.grandTotal != record.grandTotal) {
        problem =
            "This bill's saved total doesn't match its items. The figures "
            'below are recalculated from the items.';
      }
    } on DomainError {
      problem = "This bill's data is damaged and can't be calculated.";
    }

    return ScreenScaffold(
      title: record.title,
      subtitle: fullDate(record.billDate),
      actions: [
        PopupMenuButton<_Action>(
          tooltip: 'More',
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (a) => _onAction(context, ref, a, settlement),
          itemBuilder: (_) => [
            const PopupMenuItem(value: _Action.rename, child: Text('Rename')),
            if (settlement != null)
              const PopupMenuItem(
                value: _Action.copy,
                child: Text('Copy summary'),
              ),
            PopupMenuItem(
              value: _Action.delete,
              child: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ],
      children: [
        _Hero(record: record),
        if (problem != null) ...[
          const SizedBox(height: Space.lg),
          Notice(tone: NoticeTone.warning, message: problem),
        ],
        if (record.receiptPath != null) ...[
          const SizedBox(height: Space.xl),
          _Receipt(path: record.receiptPath!),
        ],
        if (settlement != null) ...[
          const SizedBox(height: Space.xl),
          ParticipantsSection(record: record, settlement: settlement),
          const SizedBox(height: Space.xl),
          ItemsSection(record: record, settlement: settlement),
        ],
        if (record.ocrText != null && record.ocrText!.trim().isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          _RecognisedText(text: record.ocrText!),
        ],
        const SizedBox(height: Space.xl),
        Text(
          'Saved ${friendlyDate(record.createdAt.toLocal(), DateTime.now())}',
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: c.textTertiary),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.record});

  final BillRecord record;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final owing = record.unsettledDebtors.length;
    final payer = record.payer;

    final how = switch (record.splitMode) {
      SplitMode.equal => 'Split equally',
      SplitMode.byItem => 'Split by item',
      SplitMode.custom => 'Split by amounts',
    };

    return AppCard(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total', style: t.bodySmall?.copyWith(color: c.textSecondary)),
          MoneyText(record.grandTotal, record.currency, style: t.displayMedium),
          const SizedBox(height: Space.md),
          Text(
            '$how · ${peopleCount(record.participants.length)}'
            '${payer == null ? '' : ' · Paid by ${payer.name}'}',
            style: t.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Icon(
                owing == 0
                    ? Icons.check_circle_outline_rounded
                    : Icons.schedule_rounded,
                size: 18,
                color: c.textSecondary,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  owing == 0
                      ? 'Everyone has paid'
                      : '$owing ${owing == 1 ? 'person has' : 'people have'} '
                            'not paid yet',
                  style: t.labelMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final image = StoredReceiptImage(relativePath: path, cacheWidth: 1200);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Receipt'),
        GestureDetector(
          onTap: () => ReceiptViewer.show(
            context,
            StoredReceiptImage(relativePath: path),
          ),
          child: Semantics(
            button: true,
            label: 'View receipt photo full screen',
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: Corners.card,
                border: Border.all(color: c.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  Positioned(
                    right: Space.sm,
                    bottom: Space.sm,
                    child: Container(
                      padding: const EdgeInsets.all(Space.sm),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(
                        Icons.open_in_full_rounded,
                        size: 16,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The raw text the recogniser read, for checking a parse against what was
/// actually on the receipt.
class _RecognisedText extends StatelessWidget {
  const _RecognisedText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ExpandableCard(
      title: 'Recognised text',
      subtitle: 'What Divvy read from the photo',
      child: RawText(text),
    );
  }
}
