import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/spacing.dart';

/// A row of segments showing how far through a flow the user is.
class StepProgress extends StatelessWidget {
  const StepProgress({
    required this.step,
    required this.of,
    required this.label,
    super.key,
  });

  /// 1-based.
  final int step;
  final int of;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= of; i++) ...[
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= step ? c.ink : c.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < of) const SizedBox(width: Space.xs),
              ],
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Step $step of $of · $label',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
