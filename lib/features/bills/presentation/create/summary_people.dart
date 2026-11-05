import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/avatar.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/models/bill_record.dart';
import '../../domain/models/settlement.dart';
import '../detail/participants_section.dart';

/// Each person's total, tap to see how it was worked out. This is the same
/// breakdown the saved bill shows.
class SummaryPeople extends StatefulWidget {
  const SummaryPeople({
    required this.record,
    required this.settlement,
    super.key,
  });

  final BillRecord record;
  final Settlement settlement;

  @override
  State<SummaryPeople> createState() => _SummaryPeopleState();
}

class _SummaryPeopleState extends State<SummaryPeople> {
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final record = widget.record;
    final byId = {for (final p in widget.settlement.perPerson) p.personId: p};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Each person pays'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < record.participants.length; i++) ...[
                if (i > 0) const Hairline(indent: Space.lg),
                InkWell(
                  onTap: () => setState(() {
                    final id = record.participants[i].id;
                    if (!_open.remove(id)) _open.add(id);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Row(
                      children: [
                        PersonAvatar(
                          name: record.participants[i].name,
                          tone: record.participants[i].colorIndex,
                          size: 40,
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.participants[i].name,
                                style: t.titleSmall,
                              ),
                              if (record.participants[i].id ==
                                  record.payerParticipantId)
                                Text(
                                  'Paid the bill',
                                  style: t.bodySmall?.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        MoneyText(
                          byId[record.participants[i].id]!.total,
                          record.currency,
                          style: t.titleMedium,
                        ),
                        Icon(
                          _open.contains(record.participants[i].id)
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: c.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_open.contains(record.participants[i].id))
                  ShareBreakdown(
                    record: record,
                    share: byId[record.participants[i].id]!,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
