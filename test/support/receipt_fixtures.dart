import 'dart:math' as math;

import 'package:divvy/features/receipt_scanning/domain/recognized_text.dart';

/// One visual row of a receipt: a single centred line, or a name on the left
/// with an amount in a right-hand column, which is how a recogniser returns it
/// (two separate lines that only line up by position).
sealed class RowSpec {
  const RowSpec();
}

class Single extends RowSpec {
  const Single(this.text);
  final String text;
}

class Pair extends RowSpec {
  const Pair(this.left, this.right);
  final String left;
  final String right;
}

/// Lays rows out on a page like a recogniser would report them, optionally
/// rotated by [tiltDegrees] about the page centre as a hand-held photo is.
RecognizedText layout(List<RowSpec> rows, {double tiltDegrees = 0}) {
  const pitch = 70.0;
  const height = 40.0;
  const nameLeft = 40.0;
  const nameWidth = 480.0;
  const priceLeft = 700.0;
  const priceWidth = 240.0;
  const pageCentre = OcrPoint(500, 600);
  final theta = tiltDegrees * math.pi / 180;

  OcrPoint rotate(double x, double y) {
    final dx = x - pageCentre.x;
    final dy = y - pageCentre.y;
    return OcrPoint(
      pageCentre.x + dx * math.cos(theta) - dy * math.sin(theta),
      pageCentre.y + dx * math.sin(theta) + dy * math.cos(theta),
    );
  }

  OcrLine line(String text, double left, double top, double width) {
    return OcrLine(text, [
      rotate(left, top),
      rotate(left + width, top),
      rotate(left + width, top + height),
      rotate(left, top + height),
    ]);
  }

  final lines = <OcrLine>[];
  for (var i = 0; i < rows.length; i++) {
    final top = 100.0 + i * pitch;
    switch (rows[i]) {
      case Single(:final text):
        lines.add(line(text, nameLeft, top, 900));
      case Pair(:final left, :final right):
        if (left.isNotEmpty) lines.add(line(left, nameLeft, top, nameWidth));
        if (right.isNotEmpty) {
          lines.add(line(right, priceLeft, top, priceWidth));
        }
    }
  }

  // Recognisers return blocks in their own order, not top to bottom; shuffle
  // deterministically so tests never depend on input order.
  final shuffled = [...lines];
  for (var i = shuffled.length - 1; i > 0; i--) {
    final j = (i * 7 + 3) % (i + 1);
    final tmp = shuffled[i];
    shuffled[i] = shuffled[j];
    shuffled[j] = tmp;
  }
  return RecognizedText(
    lines: shuffled,
    rawText: shuffled.map((l) => l.text).join('\n'),
  );
}

/// The sample bill from the project's presentation ("The Spice Table"), as the
/// rows a recogniser would find on it. These are hand-written to describe the
/// sample image, not captured from a device.
const List<RowSpec> spiceTable = [
  Single('THE SPICE TABLE'),
  Single('12 Riverfront Road, Ahmedabad'),
  Single('GSTIN 24ABCDE1234F1Z5'),
  Pair('Bill No: 0482', 'Table: 7'),
  Pair('Date: 14/11/2026', '21:14'),
  Pair('ITEM', 'AMOUNT'),
  Pair('1 x Paneer Tikka', '340.00'),
  Pair('1 x Dal Makhani', '280.00'),
  Pair('1 x Cold Coffee', '150.00'),
  Pair('4 x Butter Naan', '160.00'),
  Pair('Sub Total', '930.00'),
  Pair('Service Chg 5%', '46.50'),
  Pair('GST 5%', '48.83'),
  Pair('TOTAL', 'Rs 1025.33'),
  Single('Thank you. Visit again!'),
];
