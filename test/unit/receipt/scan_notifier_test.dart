import 'package:divvy/features/bills/application/bill_draft_notifier.dart';
import 'package:divvy/features/receipt_scanning/application/scan_notifier.dart';
import 'package:divvy/features/receipt_scanning/domain/parsed_receipt.dart';
import 'package:divvy/features/receipt_scanning/domain/recognized_text.dart';
import 'package:divvy/features/receipt_scanning/domain/text_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_container.dart';
import '../../support/receipt_fixtures.dart';

void main() {
  test('starts idle', () async {
    final app = await makeApp();
    expect(app.container.read(scanProvider), isA<ScanIdle>());
  });

  test('reads the photo and fills the draft', () async {
    final app = await makeApp(
      recognizer: FakeTextRecognizer(result: layout(spiceTable)),
    );
    await app.container.read(scanProvider.notifier).scan('/tmp/receipt.jpg');

    final state = app.container.read(scanProvider);
    expect(state, isA<ScanDone>());
    expect((state as ScanDone).receipt.warnings, isEmpty);
    expect(app.recognizer.requested, ['/tmp/receipt.jpg']);

    final draft = app.container.read(billDraftProvider);
    expect(draft.merchant, 'The Spice Table');
    expect(draft.items, hasLength(4));
  });

  test('shows a scanning state while it works', () async {
    final app = await makeApp(
      recognizer: FakeTextRecognizer(
        result: layout(spiceTable),
        delay: const Duration(milliseconds: 20),
      ),
    );
    final done = app.container.read(scanProvider.notifier).scan('/tmp/x.jpg');
    expect(app.container.read(scanProvider), isA<Scanning>());
    await done;
    expect(app.container.read(scanProvider), isA<ScanDone>());
  });

  test(
    'a photo with no text is done, with a warning and an empty draft',
    () async {
      final app = await makeApp(
        recognizer: FakeTextRecognizer(
          result: RecognizedText.fromPlainText(''),
        ),
      );
      await app.container.read(scanProvider.notifier).scan('/tmp/blank.jpg');

      final state = app.container.read(scanProvider) as ScanDone;
      expect(state.receipt.warnings, [ParseWarning.noTextFound]);
      expect(state.receipt.isEmpty, isTrue);
      expect(app.container.read(billDraftProvider).items, isEmpty);
    },
  );

  test('a recogniser failure is reported, never thrown', () async {
    final app = await makeApp(
      recognizer: FakeTextRecognizer(
        error: const TextRecognitionException('model missing'),
      ),
    );
    await app.container.read(scanProvider.notifier).scan('/tmp/x.jpg');

    final state = app.container.read(scanProvider);
    expect(state, isA<ScanFailed>());
    expect((state as ScanFailed).message, contains('enter the bill by hand'));
    expect(state.message, isNot(contains('model missing')));
  });

  test(
    'a recogniser that never answers times out instead of hanging',
    () async {
      final app = await makeApp(
        recognizer: FakeTextRecognizer(
          result: layout(spiceTable),
          delay: const Duration(seconds: 2),
        ),
        scanTimeout: const Duration(milliseconds: 50),
      );
      await app.container.read(scanProvider.notifier).scan('/tmp/x.jpg');

      final state = app.container.read(scanProvider);
      expect(state, isA<ScanFailed>());
      expect((state as ScanFailed).message, contains('took too long'));
      // Nothing from a scan that gave up reaches the draft.
      expect(app.container.read(billDraftProvider).items, isEmpty);
    },
  );

  test('the real wait is 45 seconds', () {
    expect(ScanNotifier.defaultTimeout, const Duration(seconds: 45));
  });

  test('reset returns to idle', () async {
    final app = await makeApp(
      recognizer: FakeTextRecognizer(result: layout(spiceTable)),
    );
    final n = app.container.read(scanProvider.notifier);
    await n.scan('/tmp/x.jpg');
    n.reset();
    expect(app.container.read(scanProvider), isA<ScanIdle>());
  });
}
