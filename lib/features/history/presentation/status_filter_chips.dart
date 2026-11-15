import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/spacing.dart';
import '../../bills/domain/bill_repository.dart';

/// All / Unsettled / Settled as a row of pills.
class StatusFilterChips extends StatelessWidget {
  const StatusFilterChips({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final BillStatusFilter selected;
  final ValueChanged<BillStatusFilter> onSelected;

  static const _labels = {
    BillStatusFilter.all: 'All',
    BillStatusFilter.unsettled: 'Unsettled',
    BillStatusFilter.settled: 'Settled',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        children: [
          for (final entry in _labels.entries) ...[
            Semantics(
              button: true,
              selected: entry.key == selected,
              label: '${entry.value} bills',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onSelected(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entry.key == selected ? c.ink : c.surface,
                    borderRadius: BorderRadius.circular(Corners.pill),
                    border: Border.all(
                      color: entry.key == selected ? c.ink : c.border,
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: t.labelMedium?.copyWith(
                      color: entry.key == selected ? c.onInk : c.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
          ],
        ],
      ),
    );
  }
}
