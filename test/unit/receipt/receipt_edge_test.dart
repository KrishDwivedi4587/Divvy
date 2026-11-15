import 'package:divvy/features/receipt_scanning/domain/parsed_receipt.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_parser.dart';
import 'package:divvy/features/receipt_scanning/domain/recognized_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fuzz.dart';
import '../../support/parse_helpers.dart';

void main() {
  group('nothing usable', () {
    test('no recognised text is reported as such', () {
      final r = const ReceiptParser().parse(
        const RecognizedText(lines: [], rawText: ''),
        now: parserNow,
      );
      expect(r.isEmpty, isTrue);
      expect(r.warnings, [ParseWarning.noTextFound]);
    });

    test('only whitespace is the same as no text', () {
      final r = parseText('   \n \n');
      expect(r.warnings, [ParseWarning.noTextFound]);
    });

    test('numbers and codes with no items give no items', () {
      final r = parseText(
        [
          'Tel 079 2640 1234',
          'FSSAI 12345678901234',
          '24ABCDE1234F1Z5',
          '4821',
        ].join('\n'),
      );
      expect(r.items, isEmpty);
      expect(r.total, isNull);
      expect(r.warnings, contains(ParseWarning.noItemsFound));
    });

    test('prose is not turned into items', () {
      final r = parseText('Thank you for dining with us\nPlease visit again');
      expect(r.items, isEmpty);
      expect(r.charges, isEmpty);
    });
  });

  group('recognition noise', () {
    test('O read for 0 is repaired but the line is marked less certain', () {
      final clean = parseText('Cafe\nPaneer Tikka 340.00\nTotal 340.00');
      final noisy = parseText('Cafe\nPaneer Tikka 34O.OO\nTotal 340.00');
      expect(itemSummary(noisy), [('Paneer Tikka', 1, 34000)]);
      expect(
        noisy.items.single.confidence,
        lessThan(clean.items.single.confidence),
      );
    });

    test('l read for 1 in front of an x is a quantity of one', () {
      final r = parseText('Cafe\nl x Dal Makhani 280.00\nTotal 280.00');
      expect(itemSummary(r), [('Dal Makhani', 1, 28000)]);
    });

    test('a TOTAL read with a zero for the O is still the total', () {
      final r = parseLines([
        'Cafe',
        'Tea 20.00',
        'Coffee 30.00',
        'T0TAL 50.00',
      ]);
      expect(r.total!.value, 5000);
      expect(r.items, hasLength(2));
      expect(r.warnings, isNot(contains(ParseWarning.totalNotFound)));
    });

    test('digits inside prices and sizes are never repaired', () {
      final r = parseLines(['Cafe', 'Cola 300ml 40.00', 'Total 40.00']);
      expect(itemSummary(r), [('Cola 300ml', 1, 4000)]);
    });

    test('a very short name is kept but marked for checking', () {
      final r = parseText('Cafe\nTea 20.00\nXy 10.00\nTotal 30.00');
      final xy = r.items.firstWhere((i) => i.name == 'Xy');
      expect(xy.confidence, lessThan(0.7));
    });

    test('an amount with no name is not an item', () {
      final r = parseText('Cafe\n340.00\nTea 20.00\nTotal 20.00');
      expect(itemSummary(r), [('Tea', 1, 2000)]);
    });

    test('a negative price is not an item', () {
      final r = parseText('Cafe\nTea 20.00\nVoid -50.00\nTotal 20.00');
      expect(itemSummary(r), [('Tea', 1, 2000)]);
    });

    test('identical items are both kept', () {
      final r = parseText('Cafe\nTea 20.00\nTea 20.00\nTotal 40.00');
      expect(itemSummary(r), [('Tea', 1, 2000), ('Tea', 1, 2000)]);
    });

    test('lines under the total are not read as items', () {
      final r = parseText('Cafe\nTea 20.00\nTotal 20.00\nCoffee 30.00');
      expect(itemSummary(r), [('Tea', 1, 2000)]);
    });
  });

  group('amounts', () {
    test('lakh grouping and a currency prefix', () {
      final r = parseText(
        'Banquet\nHall hire 1,20,000.00\nNet Payable Rs. 1,20,000.00',
      );
      expect(r.total!.value, 12000000);
      expect(itemSummary(r), [('Hall hire', 1, 12000000)]);
    });

    test('is deterministic', () {
      const text = 'Cafe\n2026-11-05\n2 x Tea 40.00\nGST 5% 2.00\nTotal 42.00';
      final first = parseText(text);
      final second = parseText(text);
      expect(itemSummary(first), itemSummary(second));
      expect(chargeSummary(first), chargeSummary(second));
      expect(first.total, second.total);
    });
  });

  test('never throws, whatever it is given', () {
    const alphabet = 'abcXYZ019 .,:-+()%/*xO₹\n\n';
    fuzz((rnd) {
      for (var i = 0; i < 400; i++) {
        final text = String.fromCharCodes([
          for (var k = 0; k < rnd.nextInt(300); k++)
            alphabet.codeUnitAt(rnd.nextInt(alphabet.length)),
        ]);
        final r = parseText(text);
        for (final item in r.items) {
          expect(item.quantity, greaterThanOrEqualTo(1), reason: text);
          expect(item.lineTotal.value, greaterThanOrEqualTo(0), reason: text);
          expect(item.confidence, inInclusiveRange(0, 1), reason: text);
        }
        for (final c in r.charges) {
          expect(c.amount.value, greaterThanOrEqualTo(0), reason: text);
        }
      }
    });
  });
}
