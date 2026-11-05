import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/spacing.dart';
import 'app_button.dart';

/// Shown in place of a list or screen that has nothing in it yet. It says what
/// the thing is and what to do about it, and the action actually does it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
              ),
              child: Icon(icon, color: c.textSecondary, size: 26),
            ),
            const SizedBox(height: Space.lg),
            Text(title, style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: Space.xs),
            Text(
              message,
              style: t.bodyMedium?.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Space.xl),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when something that should have loaded did not.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      message: message,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          if (label != null) ...[
            const SizedBox(height: Space.lg),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
