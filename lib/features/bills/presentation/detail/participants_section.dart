import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/avatar.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../shared/providers/data_providers.dart';
import '../../domain/bill_text.dart';
import '../../domain/engine/money.dart';
import '../../domain/models/bill_record.dart';
import '../../domain/models/settlement.dart';

/// Everyone on the bill: what they owe, how it was worked out, and whether they
/// have paid the payer back.
class ParticipantsSection extends ConsumerWidget {
  const ParticipantsSection({
    required this.record,
    required this.settlement,
    super.key,
  });

  final BillRecord record;
  final Settlement settlement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byId = {for (final p in settlement.perPerson) p.personId: p};
    final people = record.participants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Who owes what'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < people.length; i++) ...[
                if (i > 0) const Hairline(indent: Space.lg),
                _ParticipantTile(
                  record: record,
                  participant: people[i],
                  share: byId[people[i].id]!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantTile extends ConsumerStatefulWidget {
  const _ParticipantTile({
    required this.record,
    required this.participant,
    required this.share,
  });

  final BillRecord record;
  final BillParticipant participant;
  final PersonSettlement share;

  @override
  ConsumerState<_ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends ConsumerState<_ParticipantTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final record = widget.record;
    final p = widget.participant;
    final isPayer = p.id == record.payerParticipantId;

    final status = isPayer
        ? 'Paid the bill'
        : p.isSettled
        ? 'Paid back'
        : 'Owes';

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              children: [
                PersonAvatar(name: p.name, tone: p.colorIndex, size: 40),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: t.titleSmall),
                      Text(
                        status,
                        style: t.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                MoneyText(
                  widget.share.total,
                  record.currency,
                  style: t.titleMedium,
                ),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: c.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (_open) ShareBreakdown(record: record, share: widget.share),
        if (!isPayer)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: p.isSettled
                  ? TextButton(
                      onPressed: () => ref
                          .read(billActionsProvider)
                          .setSettled(p.id, settled: false),
                      child: const Text('Undo · marked paid'),
                    )
                  : OutlinedButton(
                      onPressed: () => ref
                          .read(billActionsProvider)
                          .setSettled(p.id, settled: true),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('Mark as paid'),
                    ),
            ),
          ),
      ],
    );
  }
}

/// The lines that add up to one person's total.
class ShareBreakdown extends StatelessWidget {
  const ShareBreakdown({required this.record, required this.share, super.key});

  final BillRecord record;
  final PersonSettlement share;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final items = {for (final i in record.items) i.id: i};
    final adjustments = {for (final a in record.adjustments) a.id: a};

    Widget line(String label, String amount, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: t.bodyMedium?.copyWith(
                color: bold ? c.textPrimary : c.textSecondary,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            amount,
            style: t.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    String money(Paise amount) => formatMoney(amount, record.currency);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Space.lg + 52, 0, Space.lg, Space.md),
      child: Column(
        children: [
          for (final s in share.itemShares)
            line(
              s.assigneeCount > 1
                  ? '${items[s.itemId]?.name ?? 'Item'} (1 of ${s.assigneeCount})'
                  : items[s.itemId]?.name ?? 'Item',
              money(s.share),
            ),
          for (final a in share.adjustmentShares)
            line(
              adjustments[a.adjustmentId] == null
                  ? 'Charge'
                  : adjustmentLabel(adjustments[a.adjustmentId]!),
              money(a.share),
            ),
          const SizedBox(height: Space.xs),
          line('Total', money(share.total), bold: true),
        ],
      ),
    );
  }
}
