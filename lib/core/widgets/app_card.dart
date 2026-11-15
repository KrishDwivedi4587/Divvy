import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/spacing.dart';

/// A flat bordered surface. Depth comes from the border and the surface colour,
/// never from a shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.muted = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Uses the recessed surface instead of the raised one.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: muted ? c.surfaceMuted : c.surface,
        borderRadius: Corners.card,
        border: Border.all(color: c.border),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      borderRadius: Corners.card,
      child: InkWell(onTap: onTap, borderRadius: Corners.card, child: box),
    );
  }
}

/// A small label above a group of content, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm, top: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: c.textSecondary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A hairline between rows inside a card.
class Hairline extends StatelessWidget {
  const Hairline({this.indent = 0, super.key});

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: indent);
}
