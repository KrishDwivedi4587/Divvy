import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/money_text.dart';
import '../../../shared/providers/app_providers.dart';
import '../../bills/domain/models/bill_record.dart';

/// One bill in a list: what it was, when, who was on it, what it came to, and
/// whether anyone still owes.
///
/// With large accessibility text there is no room to put the amount beside the
/// title, so the row reflows into a single column rather than squeezing.
class BillTile extends ConsumerWidget {
  const BillTile({required this.bill, required this.onTap, super.key});

  final BillSummary bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)();
    final large = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.3;

    final status = bill.isSettled ? 'Settled' : '${bill.unsettledCount} unpaid';
    final statusStyle = t.bodySmall?.copyWith(
      color: bill.isSettled ? c.textTertiary : c.textPrimary,
      fontWeight: bill.isSettled ? FontWeight.w400 : FontWeight.w600,
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bill.title,
          style: t.titleSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Space.xs),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.sm,
          children: [
            Text(
              friendlyDate(bill.billDate, now),
              style: t.bodySmall?.copyWith(color: c.textSecondary),
            ),
            if (bill.hasReceipt)
              Icon(
                Icons.receipt_long_outlined,
                size: 14,
                color: c.textTertiary,
                semanticLabel: 'Has a receipt photo',
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        AvatarStack(names: bill.participantNames, size: 24),
      ],
    );

    final amount = MoneyText(
      bill.grandTotal,
      bill.currency,
      style: t.titleSmall,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        child: large
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.md,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      amount,
                      Text(status, style: statusStyle),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: Space.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      amount,
                      const SizedBox(height: Space.xs),
                      Text(status, style: statusStyle),
                    ],
                  ),
                  const SizedBox(width: Space.xs),
                  Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                ],
              ),
      ),
    );
  }
}
