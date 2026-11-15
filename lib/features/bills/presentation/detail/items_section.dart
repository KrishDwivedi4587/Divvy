import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/bill_text.dart';
import '../../domain/engine/money.dart';
import '../../domain/models/bill_record.dart';
import '../../domain/models/settlement.dart';

/// What was bought, who shared each item, the charges on top, and the totals.
class ItemsSection extends StatelessWidget {
  const ItemsSection({
    required this.record,
    required this.settlement,
    super.key,
  });

  final BillRecord record;
  final Settlement settlement;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final names = {for (final p in record.participants) p.id: p.name};
    final showWho = record.splitMode == SplitMode.byItem;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Items'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < record.items.length; i++) ...[
                if (i > 0) const Hairline(indent: Space.lg),
                Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.items[i].quantity > 1
                                  ? '${record.items[i].name} × '
                                        '${record.items[i].quantity}'
                                  : record.items[i].name,
                              style: t.bodyLarge,
                            ),
                            if (showWho)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  [
                                    for (final id
                                        in record.assignments[record
                                                .items[i]
                                                .id] ??
                                            const <String>[])
                                      names[id] ?? '?',
                                  ].join(', '),
                                  style: t.bodySmall?.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      MoneyText(
                        record.items[i].lineTotal,
                        record.currency,
                        style: t.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        const SectionHeader('Totals'),
        AppCard(
          child: Column(
            children: [
              _row(context, 'Subtotal', settlement.itemsSubtotal, record),
              for (final a in settlement.adjustmentTotals)
                _row(context, _label(a.adjustmentId), a.amount, record),
              const SizedBox(height: Space.sm),
              const Hairline(),
              const SizedBox(height: Space.sm),
              _row(context, 'Total', settlement.grandTotal, record, bold: true),
            ],
          ),
        ),
      ],
    );
  }

  String _label(String adjustmentId) {
    for (final a in record.adjustments) {
      if (a.id == adjustmentId) return adjustmentLabel(a);
    }
    return 'Charge';
  }

  Widget _row(
    BuildContext context,
    String label,
    Paise amount,
    BillRecord record, {
    bool bold = false,
  }) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final style = bold ? t.titleMedium : t.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(
                color: bold ? c.textPrimary : c.textSecondary,
              ),
            ),
          ),
          MoneyText(amount, record.currency, style: style),
        ],
      ),
    );
  }
}
