import 'package:flutter/material.dart';

import '../constants/spacing.dart';

enum AppButtonKind { primary, secondary, text }

/// The button used everywhere. It is full-width by default (the common case on
/// a phone), shows a spinner while [loading], and is disabled by passing a null
/// [onPressed].
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = AppButtonKind.primary,
    this.loading = false,
    this.expand = true,
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonKind kind;
  final bool loading;
  final bool expand;

  /// Colours the button with the danger colour, for deleting things.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final callback = (onPressed != null && !loading) ? onPressed : null;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 20),
        if (loading || icon != null) const SizedBox(width: Space.sm),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    final button = switch (kind) {
      AppButtonKind.primary => FilledButton(
        onPressed: callback,
        style: destructive
            ? FilledButton.styleFrom(backgroundColor: error)
            : null,
        child: content,
      ),
      AppButtonKind.secondary => OutlinedButton(
        onPressed: callback,
        style: destructive
            ? OutlinedButton.styleFrom(
                foregroundColor: error,
                side: BorderSide(color: error),
              )
            : null,
        child: content,
      ),
      AppButtonKind.text => TextButton(
        onPressed: callback,
        style: destructive
            ? TextButton.styleFrom(foregroundColor: error)
            : null,
        child: content,
      ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
