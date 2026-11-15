import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/features/receipt_scanning/domain/parsed_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/parse_helpers.dart';

void main() {
  test('an Indian GST bill with CGST and SGST, suffix and bare quantities', () {
    final r = parseText(
      [
        'HOTEL SAGAR RATNA',
        'Date: 03-Nov-2026',
        '2 Masala Dosa 180.00',
        'Filter Coffee x2 60.00',
        '7 Up 300ml 40.00',
        'Sub Total 280.00',
        'CGST @ 2.5% 7.00',
        'SGST @ 2.5% 7.00',
        'Grand Total 294.00',
      ].join('\n'),
    );
    expect(r.merchant, 'Hotel Sagar Ratna');
    expect(r.date, DateTime(2026, 11, 3));
    expect(itemSummary(r), [
      ('Masala Dosa', 2, 18000),
      ('Filter Coffee', 2, 6000),
      // 4000 is not divisible by 7, so "7" is part of the name, not a quantity.
      ('7 Up 300ml', 1, 4000),
    ]);
    expect(chargeSummary(r), [('tax', 700), ('tax', 700)]);
    expect(r.charges.map((c) => c.rateBasisPoints), [250, 250]);
    expect(r.total!.value, 29400);
    expect(r.warnings, isEmpty);
  });

  test('a quantity column: name, quantity, rate, amount', () {
    final r = parseText(
      [
        'Spice Hut',
        '2026-11-05',
        'Butter Naan 4 40.00 160.00',
        'Dal Fry 1 120.00 120.00',
        'Sub Total 280.00',
        'Total 280.00',
      ].join('\n'),
    );
    expect(itemSummary(r), [('Butter Naan', 4, 16000), ('Dal Fry', 1, 12000)]);
    expect(r.items.first.unitPrice.value, 4000);
    expect(r.warnings, isEmpty);
  });

  test('a discount and a round-off are signed correctly', () {
    final r = parseText(
      [
        'Burger Palace',
        '01/11/2026',
        '2 x Burger 300.00',
        'Fries 120.00',
        'Sub Total 420.00',
        'Discount 10% -42.00',
        'Service Charge 5% 18.90',
        'Round Off 0.10',
        'Total 397.00',
      ].join('\n'),
    );
    expect(chargeSummary(r), [
      ('discount', -4200),
      ('service', 1890),
      ('other', 10),
    ]);
    expect(r.charges.first.isNegative, isTrue);
    // 5% of the discounted 378.00 is 18.90, so the printed amount is plausible.
    expect(r.charges[1].confidence, greaterThanOrEqualTo(0.7));
    expect(r.total!.value, 39700);
    expect(r.warnings, isNot(contains(ParseWarning.totalMismatch)));
  });

  test('a printed amount that does not fit its printed rate is flagged', () {
    final r = parseText(
      [
        'Cafe',
        'Tea 100.00',
        'Sub Total 100.00',
        'GST 18% 5.00',
        'Total 105.00',
      ].join('\n'),
    );
    expect(r.charges.single.amount.value, 500);
    expect(r.charges.single.confidence, lessThan(0.7));
  });

  test('unit prices are multiplied out when that matches the subtotal', () {
    final r = parseText(
      [
        'Tandoor Corner',
        '2026-11-05',
        'Paneer Tikka 340.00',
        'Butter Naan x4 40.00',
        'Sub Total 500.00',
        'Total 500.00',
      ].join('\n'),
    );
    expect(itemSummary(r), [
      ('Paneer Tikka', 1, 34000),
      ('Butter Naan', 4, 16000),
    ]);
    expect(r.items.last.unitPrice.value, 4000);
    expect(r.warnings, [ParseWarning.amountsTreatedAsUnitPrices]);
  });

  test('a bill with no subtotal still reconciles against the total', () {
    final r = parseText(
      [
        'Chai Stop',
        '2026-11-05',
        'Masala Chai 40.00',
        'Samosa 30.00',
        'Total 70.00',
      ].join('\n'),
    );
    expect(r.subtotal, isNull);
    expect(itemSummary(r), [('Masala Chai', 1, 4000), ('Samosa', 1, 3000)]);
    expect(r.total!.value, 7000);
    expect(r.warnings, isEmpty);
  });

  test('a euro receipt with decimal commas', () {
    final r = parseText(
      [
        'Café Lumière',
        '2026-11-05',
        'Pasta 12,50',
        'Wine 6,00',
        'Total 18,50 €',
      ].join('\n'),
    );
    expect(r.merchant, 'Café Lumière');
    expect(r.currency, Currency.eur);
    expect(itemSummary(r), [('Pasta', 1, 1250), ('Wine', 1, 600)]);
    expect(r.total!.value, 1850);
    expect(r.warnings, isEmpty);
  });

  test('a receipt that prints whole rupees only', () {
    final r = parseText(
      [
        'Chai Point',
        '2026-11-05',
        '2 x Masala Chai 60',
        'Samosa 40',
        'Total 100',
      ].join('\n'),
    );
    expect(itemSummary(r), [('Masala Chai', 2, 6000), ('Samosa', 1, 4000)]);
    expect(r.total!.value, 10000);
    expect(r.warnings, isEmpty);
  });

  test('a bare "Total" is beaten by a plainly worded one', () {
    final r = parseText(
      [
        'Dhaba',
        'Thali 500.00',
        'Total Qty 3',
        'Total 500.00',
        'Net Payable Rs. 1,250.00',
      ].join('\n'),
    );
    expect(r.total!.value, 125000);
  });
}
