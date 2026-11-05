import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../../bills/application/bill_draft_notifier.dart';
import '../domain/parsed_receipt.dart';
import '../domain/text_recognizer.dart';

/// Where reading a receipt photo has got to.
sealed class ScanState {
  const ScanState();
}

final class ScanIdle extends ScanState {
  const ScanIdle();
}

final class Scanning extends ScanState {
  const Scanning();
}

final class ScanDone extends ScanState {
  const ScanDone(this.receipt);

  final ParsedReceipt receipt;
}

final class ScanFailed extends ScanState {
  const ScanFailed(this.message);

  /// Plain language, safe to show as is.
  final String message;
}

/// Runs recognition and parsing on the current photo and fills the draft with
/// what it found.
///
/// It never blocks the user: if recognition fails or finds nothing, the state
/// says so and the review screen offers manual entry. Nothing is applied to the
/// draft unless the parser found it.
class ScanNotifier extends Notifier<ScanState> {
  /// How long recognition may take before the user is let out of the wait.
  static const Duration defaultTimeout = Duration(seconds: 45);

  @override
  ScanState build() => const ScanIdle();

  void reset() => state = const ScanIdle();

  Future<void> scan(String imagePath) async {
    state = const Scanning();
    try {
      final recognized = await ref
          .read(textRecognizerProvider)
          .recognize(imagePath)
          .timeout(ref.read(scanTimeoutProvider));
      final parsed = ref
          .read(receiptParserProvider)
          .parse(recognized, now: ref.read(clockProvider)());
      ref.read(billDraftProvider.notifier).applyParsed(parsed);
      state = ScanDone(parsed);
    } on TextRecognitionException {
      state = const ScanFailed(
        "Divvy couldn't read this photo. You can retake it, or enter the "
        'bill by hand.',
      );
    } on Exception {
      state = const ScanFailed(
        'Reading the receipt took too long or failed. You can retake the '
        'photo, or enter the bill by hand.',
      );
    }
  }
}

final scanProvider = NotifierProvider<ScanNotifier, ScanState>(
  ScanNotifier.new,
);

/// Injectable so tests can exercise the timeout without waiting for it.
final scanTimeoutProvider = Provider<Duration>(
  (ref) => ScanNotifier.defaultTimeout,
);
