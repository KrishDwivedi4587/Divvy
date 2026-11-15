import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/spacing.dart';
import 'app_card.dart';

/// A card that expands to reveal [child] when tapped.
class ExpandableCard extends StatelessWidget {
  const ExpandableCard({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      // The card paints a background, so the tap ripple needs a Material of
      // its own above that or it would be drawn underneath and be invisible.
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: Space.lg),
            childrenPadding: const EdgeInsets.fromLTRB(
              Space.lg,
              0,
              Space.lg,
              Space.lg,
            ),
            title: Text(title, style: t.titleSmall),
            subtitle: Text(
              subtitle,
              style: t.bodySmall?.copyWith(color: c.textSecondary),
            ),
            children: [Align(alignment: Alignment.centerLeft, child: child)],
          ),
        ),
      ),
    );
  }
}

/// Selectable monospace text, for showing raw recognised text.
class RawText extends StatelessWidget {
  const RawText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        color: context.colors.textSecondary,
        height: 1.5,
      ),
    );
  }
}
