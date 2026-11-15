import 'dart:math';
import 'dart:ui';

import 'package:divvy/features/receipt_scanning/data/mlkit_text_recognizer.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

mlkit.TextLine line(
  String text, {
  List<Point<int>> corners = const [],
  Rect rect = Rect.zero,
  double? confidence,
}) {
  return mlkit.TextLine(
    text: text,
    elements: const [],
    boundingBox: rect,
    recognizedLanguages: const ['en'],
    cornerPoints: corners,
    confidence: confidence,
    angle: null,
  );
}

mlkit.TextBlock block(List<mlkit.TextLine> lines) => mlkit.TextBlock(
  text: lines.map((l) => l.text).join('\n'),
  lines: lines,
  boundingBox: Rect.zero,
  recognizedLanguages: const ['en'],
  cornerPoints: const [],
);

List<Point<int>> box(int x, int y, int w, int h) => [
  Point(x, y),
  Point(x + w, y),
  Point(x + w, y + h),
  Point(x, y + h),
];

void main() {
  test('converts blocks and lines, keeping corners and confidence', () {
    final result = mlkit.RecognizedText(
      text: 'Tea\n20.00',
      blocks: [
        block([line('Tea', corners: box(40, 100, 200, 40), confidence: 0.9)]),
        block([line('20.00', corners: box(700, 100, 120, 40))]),
      ],
    );

    final converted = MlKitTextRecognizer.convert(result);
    expect(converted.rawText, 'Tea\n20.00');
    expect(converted.lines.map((l) => l.text), ['Tea', '20.00']);
    expect(converted.lines.first.confidence, 0.9);
    expect(converted.lines.last.confidence, isNull);
    expect(converted.lines.first.corners, hasLength(4));
    expect(converted.lines.first.width, 200);
    expect(converted.lines.first.height, 40);
  });

  test('falls back to the bounding box when corners are missing', () {
    final result = mlkit.RecognizedText(
      text: 'Tea',
      blocks: [
        block([line('Tea', rect: const Rect.fromLTRB(10, 20, 110, 60))]),
      ],
    );
    final converted = MlKitTextRecognizer.convert(result);
    expect(converted.lines.single.corners, hasLength(4));
    expect(converted.lines.single.width, 100);
    expect(converted.lines.single.height, 40);
  });

  test('converted output feeds the parser end to end', () {
    // Name and price as separate lines in separate blocks, as ML Kit returns
    // them, with the price column slightly higher (a tilted photo).
    final result = mlkit.RecognizedText(
      text: '',
      blocks: [
        block([
          line('Cafe', corners: box(300, 40, 300, 40)),
          line('Tea', corners: box(40, 120, 200, 40)),
          line('Total', corners: box(40, 200, 200, 40)),
        ]),
        block([
          line('20.00', corners: box(700, 112, 120, 40)),
          line('20.00', corners: box(700, 192, 120, 40)),
        ]),
      ],
    );

    final parsed = const ReceiptParser().parse(
      MlKitTextRecognizer.convert(result),
      now: DateTime(2026, 11, 20),
    );
    expect(parsed.items.map((i) => (i.name, i.lineTotal.value)), [
      ('Tea', 2000),
    ]);
    expect(parsed.total!.value, 2000);
  });
}
