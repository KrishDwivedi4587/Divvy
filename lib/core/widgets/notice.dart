import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/spacing.dart';

enum NoticeTone { info, warning, error }

/// A message with an icon and words, so its meaning never depends on colour.
class Notice extends StatelessWidget {
  const Notice({
    required this.message,
    this.tone = NoticeTone.info,
    this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final NoticeTone tone;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context).textTheme;
    final (icon, accent) = switch (tone) {
      NoticeTone.info => (Icons.info_outline_rounded, c.textSecondary),
      NoticeTone.warning => (Icons.warning_amber_rounded, c.warning),
      NoticeTone.error => (Icons.error_outline_rounded, c.danger),
    };

    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: Corners.control,
        border: Border.all(color: tone == NoticeTone.info ? c.border : accent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!, style: theme.titleSmall?.copyWith(height: 1.3)),
                Text(
                  message,
                  style: theme.bodyMedium?.copyWith(color: c.textSecondary),
                ),
                if (actionLabel != null && onAction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: GestureDetector(
                      onTap: onAction,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        actionLabel!,
                        style: theme.labelMedium?.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
