import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/spacing.dart';

/// One tappable line in a settings card: icon, title, an optional current
/// value, and a chevron.
class AccountRow extends StatelessWidget {
  const AccountRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.detail,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final color = destructive ? c.danger : c.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(title, style: t.bodyLarge?.copyWith(color: color)),
            ),
            if (detail != null)
              Text(
                detail!,
                style: t.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            const SizedBox(width: Space.xs),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// A sheet body that offers a short list of options and pops with the one
/// tapped.
class ChoiceList<T> extends StatelessWidget {
  const ChoiceList({
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    this.note,
    super.key,
  });

  final String title;
  final String? note;
  final List<T> values;
  final T selected;
  final String Function(T) label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: t.titleLarge),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              note!,
              style: t.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ),
        const SizedBox(height: Space.md),
        for (final v in values)
          InkWell(
            onTap: () => Navigator.of(context).pop(v),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Row(
                children: [
                  Expanded(child: Text(label(v), style: t.bodyLarge)),
                  if (v == selected) const Icon(Icons.check_rounded, size: 22),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
