import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/spacing.dart';

/// The frame every screen shares: a safe-area-aware header, scrolling content
/// with the standard gutter, and an optional action bar pinned to the bottom
/// that rides above the keyboard.
///
/// Tapping empty space or dragging the content dismisses the keyboard, which
/// matters on iPhone where the decimal keypad has no Return key.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    required this.title,
    this.children,
    this.body,
    this.footer,
    this.subtitle,
    this.showBack = true,
    this.actions = const [],
    this.belowHeader,
    super.key,
  }) : assert(
         (children == null) != (body == null),
         'Pass exactly one of children or body.',
       );

  final String title;
  final String? subtitle;

  /// Content that scrolls, laid out in a list with the standard gutter.
  final List<Widget>? children;

  /// Custom content that manages its own scrolling.
  final Widget? body;

  /// Pinned under the content, above the keyboard and home indicator.
  final Widget? footer;
  final bool showBack;
  final List<Widget> actions;

  /// A widget between the header and the content, such as a progress bar.
  final Widget? belowHeader;

  /// The widest the content gets, so it stays readable on a large screen.
  static const double maxWidth = 640;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.gutter, 0),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: t.bodySmall?.copyWith(color: c.textSecondary),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );

    final content =
        body ??
        ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.lg,
            Space.gutter,
            Space.xxl,
          ),
          children: children!,
        );

    final pinned = footer;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          bottom: pinned == null,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  header,
                  ?belowHeader,
                  Expanded(child: content),
                  if (pinned != null) _FooterBar(child: pinned),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterBar extends StatelessWidget {
  const _FooterBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter)
              .copyWith(top: Space.md, bottom: Space.md),
          child: child,
        ),
      ),
    );
  }
}
