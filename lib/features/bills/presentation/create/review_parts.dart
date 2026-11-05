import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/expandable_card.dart';
import '../../../receipt_scanning/presentation/receipt_image.dart';

/// A small receipt thumbnail that opens the full-size viewer, kept compact so
/// the items stay on screen.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Receipt photo. Tap to view full screen.',
      child: GestureDetector(
        onTap: () => ReceiptViewer.show(context, ReceiptImage(path: path)),
        child: AppCard(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Corners.sm),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: ColoredBox(
                    color: c.surfaceMuted,
                    child: ReceiptImage(
                      path: path,
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receipt photo', style: t.titleSmall),
                    Text(
                      'Tap to compare with the items below',
                      style: t.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_full_rounded, size: 18, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A read-only looking field that opens a picker when tapped.
class ReviewField extends StatelessWidget {
  const ReviewField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelMedium?.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.sm),
          InkWell(
            onTap: onTap,
            borderRadius: Corners.control,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              decoration: BoxDecoration(
                borderRadius: Corners.control,
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: c.textSecondary),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      value,
                      style: t.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddLink extends StatelessWidget {
  const AddLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      ),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(label),
    );
  }
}

/// What the recogniser read, for checking the parse against the receipt.
class RawTextExpander extends StatelessWidget {
  const RawTextExpander({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ExpandableCard(
      title: 'What Divvy read',
      subtitle: 'The raw text from the photo',
      child: RawText(text),
    );
  }
}
