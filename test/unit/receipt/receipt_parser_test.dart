import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/features/receipt_scanning/domain/parsed_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/parse_helpers.dart';
import '../../support/receipt_fixtures.dart';

void expectSpiceTable(ParsedReceipt r) {
  expect(r.merchant, 'The Spice Table');
  expect(r.date, DateTime(2026, 11, 14));
  expect(r.currency, Currency.inr);
  expect(itemSummary(r), [
    ('Paneer Tikka', 1, 34000),
    ('Dal Makhani', 1, 28000),
    ('Cold Coffee', 1, 15000),
    ('Butter Naan', 4, 16000),
  ]);
  expect(r.items.last.unitPrice.value, 4000);
  expect(chargeSummary(r), [('service', 4650), ('tax', 4883)]);
  expect(r.charges.first.rateBasisPoints, 500);
  expect(r.subtotal!.value, 93000);
  expect(r.total!.value, 102533);
  expect(r.itemsSum.value + r.chargesSum.value, r.total!.value);
  expect(r.warnings, isEmpty);
  for (final i in r.items) {
    expect(i.confidence, greaterThanOrEqualTo(0.7), reason: i.name);
  }
}

void main() {
  group('the Spice Table sample receipt', () {
    test('parses from plain text rows', () {
      expectSpiceTable(
        parseText(
          [
            'THE SPICE TABLE',
            '12 Riverfront Road, Ahmedabad',
            'GSTIN 24ABCDE1234F1Z5',
            'Bill No: 0482   Table: 7',
            'Date: 14/11/2026   21:14',
            'ITEM   AMOUNT',
            '1 x Paneer Tikka   340.00',
            '1 x Dal Makhani   280.00',
            '1 x Cold Coffee   150.00',
            '4 x Butter Naan   160.00',
            'Sub Total   930.00',
            'Service Chg 5%   46.50',
            'GST 5%   48.83',
            'TOTAL   Rs 1025.33',
            'Thank you. Visit again!',
          ].join('\n'),
        ),
      );
    });

    test('parses from separate name and price columns', () {
      expectSpiceTable(parseRows(spiceTable));
    });

    for (final tilt in [-7.0, -3.0, 4.0, 6.0]) {
      test('parses a photo tilted $tilt degrees', () {
        expectSpiceTable(parseRows(spiceTable, tilt: tilt));
      });
    }

    test('keeps the raw text and the rows it actually read', () {
      final r = parseRows(spiceTable);
      expect(r.rawText, contains('Paneer Tikka'));
      expect(r.rowsText, contains('1 x Paneer Tikka 340.00'));
      expect(r.rowsText.split('\n').length, spiceTable.length);
    });
  });

  group('warnings', () {
    test('a printed total that does not match the items is flagged', () {
      final r = parseText(
        ['Cafe', 'Tea 20.00', 'Coffee 30.00', 'Total 60.00'].join('\n'),
      );
      expect(r.total!.value, 6000);
      expect(r.itemsSum.value, 5000);
      expect(r.warnings, contains(ParseWarning.totalMismatch));
    });

    test('items that do not match the printed subtotal are flagged', () {
      final r = parseText(
        [
          'Cafe',
          'Tea 20.00',
          'Coffee 30.00',
          'Sub Total 55.00',
          'Total 55.00',
        ].join('\n'),
      );
      expect(r.warnings, contains(ParseWarning.itemsDoNotMatchSubtotal));
    });

    test('a missing total is reported, not invented', () {
      final r = parseText(['Cafe', 'Tea 20.00', 'Coffee 30.00'].join('\n'));
      expect(r.total, isNull);
      expect(r.warnings, contains(ParseWarning.totalNotFound));
      expect(itemSummary(r), hasLength(2));
    });

    test('an ambiguous date is flagged but still read day-first', () {
      final r = parseText(['Cafe', 'Date 05/11/2026', 'Tea 20.00'].join('\n'));
      expect(r.date, DateTime(2026, 11, 5));
      expect(r.warnings, contains(ParseWarning.dateAmbiguous));
    });

    test('a missing date is reported, not invented', () {
      final r = parseText(['Cafe', 'Tea 20.00', 'Total 20.00'].join('\n'));
      expect(r.date, isNull);
      expect(r.warnings, contains(ParseWarning.dateNotFound));
    });
  });
}
