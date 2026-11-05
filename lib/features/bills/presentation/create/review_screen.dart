import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/navigation.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../../core/widgets/step_progress.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../account/presentation/account_widgets.dart';
import '../../../receipt_scanning/application/scan_notifier.dart';
import '../../application/bill_draft_notifier.dart';
import '../../domain/bill_draft.dart';
import '../../domain/bill_text.dart';
import '../../domain/engine/money.dart';
import '../../domain/models/bill.dart';
import 'charge_editor_sheet.dart';
import 'item_editor_sheet.dart';
import 'review_notices.dart';
import 'review_parts.dart';
import 'review_rows.dart';

/// Step 2: check what was read, correct it, and add anything missing. Works the
/// same whether the bill came from a photo or is being entered by hand.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late final TextEditingController _merchant = TextEditingController(
    text: ref.read(billDraftProvider).merchant,
  );

  @override
  void dispose() {
    _merchant.dispose();
    super.dispose();
  }

  BillDraftNotifier get _draft => ref.read(billDraftProvider.notifier);

  Future<void> _editItem(DraftItem? existing) async {
    final draft = ref.read(billDraftProvider);
    final edit = await showItemEditor(
      context,
      currency: draft.currency,
      newId: ref.read(idGeneratorProvider)(),
      existing: existing,
    );
    switch (edit) {
      case ItemSaved(:final item):
        if (existing == null) {
          _draft.addItem(item);
        } else {
          _draft.updateItem(item);
        }
      case ItemDeleted():
        if (existing != null) _draft.removeItem(existing.id);
      case null:
        break;
    }
  }

  Future<void> _editCharge(
    DraftAdjustment? existing, {
    AdjustmentKind kind = AdjustmentKind.tax,
  }) async {
    final draft = ref.read(billDraftProvider);
    final edit = await showChargeEditor(
      context,
      currency: draft.currency,
      newId: _draft.newAdjustmentId(),
      kind: kind,
      existing: existing,
    );
    switch (edit) {
      case ChargeSaved(:final charge):
        if (existing == null) {
          _draft.addAdjustment(charge);
        } else {
          _draft.updateAdjustment(charge);
        }
      case ChargeDeleted():
        if (existing != null) _draft.removeAdjustment(existing.id);
      case null:
        break;
    }
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final current = ref.read(billDraftProvider).billDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null) _draft.setDate(picked);
  }

  Future<void> _pickCurrency() async {
    final current = ref.read(billDraftProvider).currency;
    final chosen = await showAppSheet<Currency>(
      context,
      builder: (_) => ChoiceList<Currency>(
        title: 'Currency',
        values: Currency.values,
        selected: current,
        label: (c) => '${c.symbol}  ${c.label}',
      ),
    );
    if (chosen != null) _draft.setCurrency(chosen);
  }

  Future<void> _addChargeMenu() async {
    final kind = await showAppSheet<AdjustmentKind>(
      context,
      builder: (_) => ChoiceList<AdjustmentKind>(
        title: 'Add a charge',
        values: const [
          AdjustmentKind.tax,
          AdjustmentKind.service,
          AdjustmentKind.discount,
          AdjustmentKind.tip,
          AdjustmentKind.other,
        ],
        selected: AdjustmentKind.other,
        label: defaultChargeLabel,
      ),
    );
    if (kind != null) await _editCharge(null, kind: kind);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final draft = ref.watch(billDraftProvider);
    final scan = ref.watch(scanProvider);
    final totals = draft.reviewTotals();
    final canContinue = draft.items.isNotEmpty && totals.items > Paise.zero;

    return ScreenScaffold(
      title: 'Review',
      belowHeader: const StepProgress(step: 2, of: 5, label: 'Details'),
      footer: AppButton(
        label: 'Continue',
        icon: Icons.arrow_forward_rounded,
        onPressed: canContinue
            ? () => context.open(AppRoutes.createPeople)
            : null,
      ),
      children: [
        if (draft.imagePath != null) ...[
          PhotoStrip(path: draft.imagePath!),
          const SizedBox(height: Space.lg),
        ],
        ...reviewNotices(
          scan: scan,
          stated: draft.statedTotal,
          computed: totals.grand,
          currency: draft.currency,
        ),
        AppCard(
          child: Column(
            children: [
              AppTextField(
                label: 'Merchant',
                hint: 'Where was this? (optional)',
                controller: _merchant,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                onChanged: _draft.setMerchant,
              ),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  Expanded(
                    child: ReviewField(
                      label: 'Date',
                      value: formatShortDate(draft.billDate),
                      icon: Icons.calendar_today_outlined,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: ReviewField(
                      label: 'Currency',
                      value: '${draft.currency.symbol} ${draft.currency.code}',
                      icon: Icons.payments_outlined,
                      onTap: _pickCurrency,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        SectionHeader(
          'Items',
          trailing: AddLink(label: 'Add item', onTap: () => _editItem(null)),
        ),
        if (draft.items.isEmpty)
          AppCard(
            muted: true,
            child: Text(
              'No items yet. Add what was ordered, or add one line for the '
              'whole bill.',
              style: t.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < draft.items.length; i++) ...[
                  if (i > 0) const Hairline(indent: Space.lg),
                  ItemRow(
                    item: draft.items[i],
                    currency: draft.currency,
                    onTap: () => _editItem(draft.items[i]),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: Space.xl),
        SectionHeader(
          'Taxes, charges and tip',
          trailing: AddLink(label: 'Add', onTap: _addChargeMenu),
        ),
        if (draft.adjustments.isEmpty)
          AppCard(
            muted: true,
            child: Text(
              'None. Add a tax, service charge, discount or tip if the bill '
              'has one.',
              style: t.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < draft.adjustments.length; i++) ...[
                  if (i > 0) const Hairline(indent: Space.lg),
                  ChargeRow(
                    charge: draft.adjustments[i],
                    amount:
                        totals.charges[draft.adjustments[i].id] ?? Paise.zero,
                    currency: draft.currency,
                    onTap: () => _editCharge(draft.adjustments[i]),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: Space.xl),
        AppCard(
          child: Column(
            children: [
              TotalLine(
                label: 'Items',
                amount: totals.items,
                currency: draft.currency,
              ),
              if (draft.adjustments.isNotEmpty)
                TotalLine(
                  label: 'Taxes and charges',
                  amount: totals.grand - totals.items,
                  currency: draft.currency,
                ),
              const SizedBox(height: Space.sm),
              const Hairline(),
              const SizedBox(height: Space.sm),
              TotalLine(
                label: 'Total',
                amount: totals.grand,
                currency: draft.currency,
                strong: true,
              ),
            ],
          ),
        ),
        if (draft.ocrText != null && draft.ocrText!.trim().isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          RawTextExpander(text: draft.ocrText!),
        ],
      ],
    );
  }
}
