import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/spacing.dart';

/// A short row of mutually exclusive choices, as one connected control with the
/// selected segment filled in ink. Used for split modes and amount-or-percent.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(Corners.md + 3),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == selected,
                label: label(v),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: v == selected ? c.ink : Colors.transparent,
                      borderRadius: Corners.control,
                    ),
                    child: Text(
                      label(v),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelMedium?.copyWith(
                        color: v == selected ? c.onInk : c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
