import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../shared/providers/app_providers.dart';

/// The absolute path of a stored receipt, or null if the file is missing.
final storedReceiptProvider = FutureProvider.autoDispose
    .family<String?, String>(
      (ref, relativePath) =>
          ref.watch(receiptStorageProvider).resolve(relativePath),
    );

/// A receipt photo, with loading and "couldn't show it" states so a bad or
/// missing file never leaves a blank box or throws.
class ReceiptImage extends StatelessWidget {
  const ReceiptImage({
    required this.path,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.compact = false,
    super.key,
  });

  /// An absolute file path.
  final String path;
  final BoxFit fit;

  /// For thumbnails too small to hold the full "couldn't show this photo"
  /// message: a failure shows just an icon.
  final bool compact;

  /// Decode at this width to keep memory down for large photos.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, loadedSync) {
        if (loadedSync || frame != null) return child;
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stack) => compact
          ? Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 20,
                color: context.colors.textTertiary,
                semanticLabel: "Couldn't show this photo",
              ),
            )
          : const ReceiptUnavailable(),
    );
  }
}

class ReceiptUnavailable extends StatelessWidget {
  const ReceiptUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: c.textTertiary, size: 32),
            const SizedBox(height: Space.sm),
            Text(
              "Couldn't show this photo",
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A stored receipt by its relative path: resolves the file, then shows it.
class StoredReceiptImage extends ConsumerWidget {
  const StoredReceiptImage({
    required this.relativePath,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    super.key,
  });

  final String relativePath;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(storedReceiptProvider(relativePath))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const ReceiptUnavailable(),
          data: (path) => path == null
              ? const ReceiptUnavailable()
              : ReceiptImage(path: path, fit: fit, cacheWidth: cacheWidth),
        );
  }
}

/// A small receipt preview for list rows. A bill without a photo (or whose
/// photo is missing) gets a quiet placeholder of the same size, so every row
/// lines up and nothing ever shows an error box at this size.
class ReceiptThumb extends ConsumerWidget {
  const ReceiptThumb({this.relativePath, this.width = 44, super.key});

  final String? relativePath;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final placeholder = Icon(
      Icons.receipt_long_outlined,
      size: 20,
      color: c.textTertiary,
    );
    final path = relativePath;
    final Widget child = path == null
        ? placeholder
        : ref
              .watch(storedReceiptProvider(path))
              .maybeWhen(
                data: (file) => file == null
                    ? placeholder
                    : Image.file(
                        File(file),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        cacheWidth: (width * 3).round(),
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => placeholder,
                      ),
                orElse: () => const SizedBox.shrink(),
              );
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: width * 1.25,
        decoration: BoxDecoration(
          color: c.surfaceMuted,
          borderRadius: BorderRadius.circular(Corners.sm),
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// Full-screen, pinch to zoom, on black.
class ReceiptViewer extends StatelessWidget {
  const ReceiptViewer({required this.image, super.key});

  final Widget image;

  static Future<void> show(BuildContext context, Widget image) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReceiptViewer(image: image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: image),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: IconButton.filled(
                  tooltip: 'Close',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
