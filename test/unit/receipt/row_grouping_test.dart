import 'package:divvy/features/receipt_scanning/domain/recognized_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/receipt_fixtures.dart';

List<String> rowTexts(RecognizedText t) =>
    groupIntoRows(t).map((r) => r.text).toList();

void main() {
  const rows = <RowSpec>[
    Single('THE SPICE TABLE'),
    Pair('1 x Paneer Tikka', '340.00'),
    Pair('1 x Dal Makhani', '280.00'),
    Pair('1 x Cold Coffee', '150.00'),
    Pair('TOTAL', '770.00'),
  ];
  const expected = [
    'THE SPICE TABLE',
    '1 x Paneer Tikka 340.00',
    '1 x Dal Makhani 280.00',
    '1 x Cold Coffee 150.00',
    'TOTAL 770.00',
  ];

  test('puts a name and its price column back on one row', () {
    expect(rowTexts(layout(rows)), expected);
  });

  test('does not depend on the order the recogniser returns lines in', () {
    final level = layout(rows);
    final reversed = RecognizedText(
      lines: level.lines.reversed.toList(),
      rawText: level.rawText,
    );
    expect(rowTexts(reversed), expected);
  });

  for (final tilt in [-8.0, -4.0, 2.0, 5.0, 8.0]) {
    test('still pairs prices with the right item at a $tilt degree tilt', () {
      // At a few degrees the price column sits about half a row above or below
      // its name, so grouping by raw height would pair prices with the wrong
      // item. Estimating and removing the skew is what prevents that.
      expect(rowTexts(layout(rows, tiltDegrees: tilt)), expected);
    });
  }

  test('rows come out top to bottom', () {
    final texts = rowTexts(layout(spiceTable, tiltDegrees: 5));
    expect(texts.first, 'THE SPICE TABLE');
    expect(texts.last, 'Thank you. Visit again!');
    expect(
      texts.indexOf('Sub Total 930.00'),
      lessThan(texts.indexOf('TOTAL Rs 1025.33')),
    );
  });

  test('plain text becomes one row per line, blanks dropped', () {
    final t = RecognizedText.fromPlainText('Tea 20.00\n\n  \nCoffee 30.00');
    expect(rowTexts(t), ['Tea 20.00', 'Coffee 30.00']);
  });

  test('nothing recognised gives no rows', () {
    expect(
      groupIntoRows(const RecognizedText(lines: [], rawText: '')),
      isEmpty,
    );
  });

  test('a single line is a single row', () {
    final t = RecognizedText.fromPlainText('Only line');
    expect(rowTexts(t), ['Only line']);
  });
}
