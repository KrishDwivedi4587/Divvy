// Generates random receipts, renders them the way a recogniser would report
// them (separate name and price columns, random tilt, random quantity style and
// amount formatting), parses them back and requires the exact items, charges
// and totals that went in. A failure prints its seed.

import 'dart:math';

import 'package:divvy/features/bills/domain/engine/money.dart';
import 'package:divvy/features/receipt_scanning/domain/parsed_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fuzz.dart';
import '../../support/parse_helpers.dart';
import '../../support/receipt_fixtures.dart';

const _names = [
  'Paneer Tikka',
  'Dal Makhani',
  'Cold Coffee',
  'Masala Dosa',
  'Veg Biryani',
  'Gulab Jamun',
  'Sweet Lassi',
  'Tomato Soup',
  'Chicken Roll',
  'Mango Shake',
  'Aloo Paratha',
  'Idli Sambar',
];

String _amount(int paise, Random rnd, {bool negative = false}) {
  final rupees = paise ~/ 100;
  final frac = (paise % 100).toString().padLeft(2, '0');
  var whole = rupees.toString();
  if (rnd.nextBool() && rupees >= 1000) {
    final head = whole.substring(0, whole.length - 3);
    whole = '$head,${whole.substring(whole.length - 3)}';
  }
  return '${negative ? '-' : ''}$whole.$frac';
}

void main() {
  test('200 random receipts parse back exactly', () {
    fuzz((rnd) {
      for (var n = 0; n < 200; n++) {
        final names = [..._names]..shuffle(rnd);
        final count = 2 + rnd.nextInt(6);
        final rows = <RowSpec>[
          const Single('SPICE GARDEN'),
          const Single('12 Riverfront Road, Ahmedabad'),
          const Pair('Date: 14/11/2026', '21:14'),
          const Pair('ITEM', 'AMOUNT'),
        ];
        final expectedItems = <(String, int, int)>[];
        var sub = 0;

        for (var i = 0; i < count; i++) {
          final qty = 1 + rnd.nextInt(4);
          final unit = (20 + rnd.nextInt(880)) * 100 + rnd.nextInt(2) * 50;
          final total = unit * qty;
          sub += total;
          final label = qty == 1
              ? names[i]
              : switch (rnd.nextInt(3)) {
                  0 => '$qty x ${names[i]}',
                  1 => '$qty ${names[i]}',
                  _ => '${names[i]} x$qty',
                };
          rows.add(Pair(label, _amount(total, rnd)));
          expectedItems.add((names[i], qty, total));
        }

        rows.add(Pair('Sub Total', _amount(sub, rnd)));
        final expectedCharges = <(String, int)>[];
        var running = sub;
        if (rnd.nextInt(3) == 0) {
          final d = percentOf(Paise(sub), 1000).value;
          rows.add(Pair('Discount 10%', _amount(d, rnd, negative: true)));
          expectedCharges.add(('discount', -d));
          running -= d;
        }
        if (rnd.nextBool()) {
          final s = percentOf(Paise(sub), 500).value;
          rows.add(Pair('Service Chg 5%', _amount(s, rnd)));
          expectedCharges.add(('service', s));
          running += s;
        }
        if (rnd.nextBool()) {
          final g = percentOf(Paise(running), 1800).value;
          rows.add(Pair('GST 18%', _amount(g, rnd)));
          expectedCharges.add(('tax', g));
          running += g;
        }
        rows.add(Pair('TOTAL', 'Rs ${_amount(running, rnd)}'));

        final tilt = (rnd.nextDouble() - 0.5) * 12;
        final r = parseRows(rows, tilt: tilt);
        final why = 'receipt $n, tilt ${tilt.toStringAsFixed(1)}';

        expect(itemSummary(r), expectedItems, reason: why);
        expect(chargeSummary(r), expectedCharges, reason: why);
        expect(r.subtotal!.value, sub, reason: why);
        expect(r.total!.value, running, reason: why);
        expect(r.merchant, 'Spice Garden', reason: why);
        expect(r.date, DateTime(2026, 11, 14), reason: why);
        expect(r.warnings, isEmpty, reason: why);
        expect(r.warnings, isNot(contains(ParseWarning.totalMismatch)));
      }
    });
  });
}
