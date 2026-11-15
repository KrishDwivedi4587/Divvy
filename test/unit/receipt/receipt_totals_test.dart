import 'package:divvy/features/receipt_scanning/domain/parsed_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/parse_helpers.dart';

/// Which printed total is the payable one, and when the parser must ask.
void main() {
  test('one clear total is used and nothing is flagged', () {
    final r = parseLines([
      'Dhaba',
      'Thali 500.00',
      'Lassi 100.00',
      'Total 600.00',
    ]);
    expect(r.total!.value, 60000);
    expect(r.totalCandidates.map((t) => t.value), [60000]);
    expect(r.warnings, isNot(contains(ParseWarning.multipleTotals)));
  });

  test('a repeated total is one candidate, not two', () {
    final r = parseLines([
      'Dhaba',
      'Thali 500.00',
      'Total 500.00',
      'Total 500.00',
    ]);
    expect(r.totalCandidates.map((t) => t.value), [50000]);
    expect(r.warnings, isNot(contains(ParseWarning.multipleTotals)));
  });

  test(
    'a plainly worded total outranks a bare one, with no question asked',
    () {
      final r = parseLines([
        'Dhaba',
        'Thali 500.00',
        'Total 500.00',
        'Net Payable Rs. 1,250.00',
      ]);
      expect(r.total!.value, 125000);
      expect(r.totalCandidates.map((t) => t.value), [50000, 125000]);
      expect(r.warnings, isNot(contains(ParseWarning.multipleTotals)));
    },
  );

  test('of two bare totals, the one the items add up to wins', () {
    final r = parseLines([
      'Dhaba',
      'Thali 500.00',
      'Lassi 100.00',
      'Total 600.00',
      'Total 900.00',
    ]);
    expect(r.total!.value, 60000);
    expect(r.warnings, isNot(contains(ParseWarning.multipleTotals)));
  });

  test('two bare totals that neither add up are flagged, not guessed', () {
    final r = parseLines([
      'Dhaba',
      'Thali 500.00',
      'Total 700.00',
      'Total 900.00',
    ]);
    expect(r.warnings, contains(ParseWarning.multipleTotals));
    expect(r.totalCandidates.map((t) => t.value), [70000, 90000]);
    // The bottom-most is still offered as the best guess.
    expect(r.total!.value, 90000);
  });

  test('two different plainly worded totals are flagged too', () {
    final r = parseLines([
      'Dhaba',
      'Thali 500.00',
      'Amount Payable 700.00',
      'Grand Total 900.00',
    ]);
    expect(r.warnings, contains(ParseWarning.multipleTotals));
  });

  test('a receipt with no total says so and invents none', () {
    final r = parseLines(['Dhaba', 'Thali 500.00', 'Lassi 100.00']);
    expect(r.total, isNull);
    expect(r.totalCandidates, isEmpty);
    expect(r.warnings, contains(ParseWarning.totalNotFound));
  });
}
