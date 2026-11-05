import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/avatar.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/bill_draft.dart';

/// One item with a chip per person: tap a person to give them the item or take
/// it back. An item nobody has is flagged, because it would not be charged to
/// anyone.
class SplitItemCard extends StatelessWidget {
  const SplitItemCard({
    required this.item,
    required this.participants,
    required this.assigned,
    required this.currency,
    required this.onToggle,
    required this.onEveryone,
    super.key,
  });

  final DraftItem item;
  final List<DraftParticipant> participants;
  final Set<String> assigned;
  final Currency currency;
  final void Function(String participantId) onToggle;
  final VoidCallback onEveryone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final everyone = assigned.length == participants.length;
    final none = assigned.isEmpty;

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Corners.card,
        border: Border.all(color: none ? c.warning : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.quantity > 1
                      ? '${item.name} × ${item.quantity}'
                      : item.name,
                  style: t.titleSmall,
                ),
              ),
              MoneyText(item.lineTotal, currency, style: t.titleSmall),
            ],
          ),
          if (none)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: c.warning),
                  const SizedBox(width: Space.xs),
                  Text(
                    'Choose who shared this',
                    style: t.bodySmall?.copyWith(color: c.warning),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              _Chip(label: 'Everyone', selected: everyone, onTap: onEveryone),
              for (final p in participants)
                _Chip(
                  label: p.name,
                  tone: p.colorIndex,
                  selected: assigned.contains(p.id),
                  onTap: () => onToggle(p.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.tone,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: Space.minTap - 8),
          padding: EdgeInsets.fromLTRB(
            tone == null ? Space.md : 6,
            6,
            Space.md,
            6,
          ),
          decoration: BoxDecoration(
            color: selected ? c.ink : c.surface,
            borderRadius: BorderRadius.circular(Corners.pill),
            border: Border.all(color: selected ? c.ink : c.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tone != null) ...[
                PersonAvatar(name: label, tone: tone!, size: 26),
                const SizedBox(width: Space.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: selected ? c.onInk : c.textPrimary),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: Space.xs),
                Icon(Icons.check_rounded, size: 16, color: c.onInk),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
