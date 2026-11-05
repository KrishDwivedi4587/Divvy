import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/errors/domain_error.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/avatar.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/bill_draft.dart';
import '../../domain/models/settlement.dart';

/// "Paid by": one person chosen from the bill's participants.
class PayerSelector extends StatelessWidget {
  const PayerSelector({
    required this.participants,
    required this.payerId,
    required this.onSelected,
    super.key,
  });

  final List<DraftParticipant> participants;
  final String? payerId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final p in participants)
          Semantics(
            button: true,
            selected: p.id == payerId,
            label: 'Paid by ${p.name}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onSelected(p.id),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.fromLTRB(6, 6, Space.md, 6),
                decoration: BoxDecoration(
                  color: p.id == payerId ? c.ink : c.surface,
                  borderRadius: BorderRadius.circular(Corners.pill),
                  border: Border.all(
                    color: p.id == payerId ? c.ink : c.borderStrong,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PersonAvatar(name: p.name, tone: p.colorIndex, size: 26),
                    const SizedBox(width: Space.sm),
                    Flexible(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: p.id == payerId ? c.onInk : c.textPrimary,
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

/// What each person would pay, updating as the split changes.
class TotalsPreview extends StatelessWidget {
  const TotalsPreview({required this.draft, required this.now, super.key});

  final BillDraft draft;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;

    Settlement? settlement;
    try {
      settlement = draft.settle(now);
    } on DomainError {
      settlement = null;
    }
    if (settlement == null) return const SizedBox.shrink();
    final s = settlement;
    final byId = {for (final p in s.perPerson) p.personId: p.total};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Each person pays'),
        AppCard(
          child: Column(
            children: [
              for (final p in draft.participants)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Row(
                    children: [
                      PersonAvatar(name: p.name, tone: p.colorIndex, size: 32),
                      const SizedBox(width: Space.md),
                      Expanded(child: Text(p.name, style: t.bodyLarge)),
                      MoneyText(
                        byId[p.id]!,
                        draft.currency,
                        style: t.titleSmall,
                      ),
                    ],
                  ),
                ),
              if (!s.unassignedAmount.isZero) ...[
                const SizedBox(height: Space.sm),
                const Hairline(),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: c.warning,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        'Some items are not assigned yet, so these totals '
                        'are incomplete.',
                        style: t.bodySmall?.copyWith(color: c.warning),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
