import 'package:divvy/features/receipt_scanning/domain/receipt_dates.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_keywords.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyLabel', () {
    const cases = <(String, RowKind)>[
      ('Sub Total', RowKind.subtotal),
      ('SUBTOTAL', RowKind.subtotal),
      ('Sub-Total', RowKind.subtotal),
      ('Taxable Value', RowKind.subtotal),
      ('TOTAL', RowKind.total),
      ('Grand Total', RowKind.total),
      ('Net Payable', RowKind.total),
      ('Amount Due', RowKind.total),
      ('GST 5%', RowKind.tax),
      ('CGST @ 2.5%', RowKind.tax),
      ('S.GST 2.5%', RowKind.tax),
      ('VAT', RowKind.tax),
      ('Service Tax', RowKind.tax),
      ('Service Charge', RowKind.service),
      ('Service Chg 5%', RowKind.service),
      ('SVC CHRG', RowKind.service),
      ('Discount 10%', RowKind.discount),
      ('Coupon', RowKind.discount),
      ('Tip', RowKind.tip),
      ('Gratuity', RowKind.tip),
      ('Round Off', RowKind.roundOff),
      ('Rounding', RowKind.roundOff),
      ('Packing Charges', RowKind.otherCharge),
      ('Delivery Fee', RowKind.otherCharge),
      ('ITEM', RowKind.header),
      ('Qty Rate Amount', RowKind.header),
      ('GSTIN 24ABCDE1234F1Z5', RowKind.skip),
      ('Bill No: 0482', RowKind.skip),
      ('Table: 7', RowKind.skip),
      ('Table No 12', RowKind.skip),
      // The word "table" alone is a name or a menu item, not a table number.
      ('THE SPICE TABLE', RowKind.item),
      ('Table Water', RowKind.item),
      ('Date: 14/11/2026', RowKind.skip),
      ('Paneer Tikka', RowKind.item),
      ('2 x Masala Dosa', RowKind.item),
      ('Chargrilled Chicken', RowKind.item),
      ('', RowKind.item),
    ];
    for (final (label, kind) in cases) {
      test('"$label" is ${kind.name}', () {
        expect(classifyLabel(label), kind);
      });
    }

    test('a column total is not the bill total', () {
      expect(classifyLabel('Total Qty'), isNot(RowKind.total));
      expect(classifyLabel('Total Tax'), isNot(RowKind.total));
      expect(classifyLabel('Total Items'), isNot(RowKind.total));
    });

    test('only plainly worded totals are strong', () {
      expect(isStrongTotalLabel('Grand Total'), isTrue);
      expect(isStrongTotalLabel('Amount Payable'), isTrue);
      expect(isStrongTotalLabel('TOTAL'), isFalse);
    });
  });

  group('findDate', () {
    DateTime? read(String text) => findDate(text, maxYear: 2030)?.date;

    const unambiguous = <(String, int, int, int)>[
      ('Date: 14/11/2026', 2026, 11, 14),
      ('14-11-26', 2026, 11, 14),
      ('14.11.2026', 2026, 11, 14),
      ('2026-11-14', 2026, 11, 14),
      ('2026/11/14', 2026, 11, 14),
      ('14 Nov 2026', 2026, 11, 14),
      ('14th November, 2026', 2026, 11, 14),
      ('Nov 14, 2026', 2026, 11, 14),
      ('3-Nov-2026', 2026, 11, 3),
      ('Date 31/12/2026 21:14', 2026, 12, 31),
      ('11/14/2026', 2026, 11, 14), // only valid month-first
    ];
    for (final (text, y, m, d) in unambiguous) {
      test('reads "$text" as $y-$m-$d', () {
        final r = findDate(text, maxYear: 2030)!;
        expect(r.date, DateTime(y, m, d));
        expect(r.ambiguous, isFalse);
      });
    }

    test('flags a date that could be day-first or month-first', () {
      final r = findDate('05/11/2026', maxYear: 2030)!;
      expect(r.date, DateTime(2026, 11, 5)); // day-first, as Indian receipts
      expect(r.ambiguous, isTrue);
    });

    test('a date with equal day and month is not ambiguous', () {
      expect(findDate('05/05/2026', maxYear: 2030)!.ambiguous, isFalse);
    });

    test('rejects impossible dates and misread numbers', () {
      expect(read('31/02/2026'), isNull);
      expect(read('45/11/2026'), isNull);
      expect(read('14/11/1999'), isNull);
      expect(read('14/11/2099'), isNull);
      expect(read('Tel 079-2640-1234'), isNull);
      expect(read('Bill No 0482'), isNull);
      expect(read('21:14'), isNull);
      expect(read(''), isNull);
    });

    test('finds a date inside a longer line', () {
      expect(
        read('Bill 0482  Date: 14/11/2026  Table 7'),
        DateTime(2026, 11, 14),
      );
    });
  });
}
