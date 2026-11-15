import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/bill_draft.dart';
import '../../domain/bill_text.dart';
import '../../domain/engine/money.dart';
import '../../domain/models/bill.dart';

/// One item on the review list. Items the reader was unsure about are marked,
/// so the user knows exactly where to look.
class ItemRow extends StatelessWidget {
  const ItemRow({
    required this.item,
    required this.currency,
    required this.onTap,
    super.key,
  });

  final DraftItem item;
  final Currency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final check = item.needsReview;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.quantity > 1
                        ? '${item.name} × ${item.quantity}'
                        : item.name,
                    style: t.bodyLarge,
                  ),
                  if (check)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: c.warning,
                          ),
                          const SizedBox(width: Space.xs),
                          Text(
                            'Check this line',
                            style: t.bodySmall?.copyWith(color: c.warning),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            MoneyText(item.lineTotal, currency, style: t.bodyLarge),
            const SizedBox(width: Space.xs),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// One tax, charge, discount or tip on the review list.
class ChargeRow extends StatelessWidget {
  const ChargeRow({
    required this.charge,
    required this.amount,
    required this.currency,
    required this.onTap,
    super.key,
  });

  final DraftAdjustment charge;

  /// The amount this charge works out to, signed.
  final Paise amount;
  final Currency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final label = adjustmentLabel(
      Adjustment(
        id: charge.id,
        label: charge.label,
        kind: charge.kind,
        mode: charge.mode,
        value: charge.value,
        order: 0,
        base: AdjustmentBase.itemsSubtotal,
        isNegative: charge.isNegative,
      ),
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          children: [
            Expanded(child: Text(label, style: t.bodyLarge)),
            MoneyText(amount, currency, style: t.bodyLarge),
            const SizedBox(width: Space.xs),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// A label and an amount on one line, for totals.
class TotalLine extends StatelessWidget {
  const TotalLine({
    required this.label,
    required this.amount,
    required this.currency,
    this.strong = false,
    super.key,
  });

  final String label;
  final Paise amount;
  final Currency currency;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final style = strong ? t.titleMedium : t.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(
                color: strong ? c.textPrimary : c.textSecondary,
              ),
            ),
          ),
          MoneyText(amount, currency, style: style),
        ],
      ),
    );
  }
}

/// The total printed on the receipt, under Divvy's own, tappable to correct.
/// A tick says the two agree, so a user knows nothing was missed.
class PrintedTotalRow extends StatelessWidget {
  const PrintedTotalRow({
    required this.amount,
    required this.currency,
    required this.matches,
    required this.onTap,
    super.key,
  });

  final Paise amount;
  final Currency currency;
  final bool matches;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label:
          'Printed on receipt ${formatMoney(amount, currency)}, '
          '${matches ? 'matches' : 'does not match'}. Tap to correct.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Corners.control,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Icon(
                matches
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                size: 16,
                color: matches ? c.textSecondary : c.warning,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  'Printed on receipt',
                  style: t.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ),
              MoneyText(
                amount,
                currency,
                style: t.bodySmall?.copyWith(color: c.textSecondary),
              ),
              const SizedBox(width: Space.sm),
              Icon(Icons.edit_outlined, size: 16, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
