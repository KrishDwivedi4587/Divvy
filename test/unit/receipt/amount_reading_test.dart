import 'package:divvy/features/receipt_scanning/domain/amount_reading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('readAmount', () {
    const accepted = <(String, int)>[
      ('340.00', 34000),
      ('340.5', 34050),
      ('340', 34000),
      ('1,234.50', 123450),
      ('1,00,000.00', 10000000),
      ('1,234', 123400),
      ('₹340.00', 34000),
      ('Rs.340.00', 34000),
      ('Rs1025.33', 102533),
      ('INR500', 50000),
      ('9,50', 950),
      ('1.234,50', 123450),
      (r'$12.50', 1250),
      ('340.00*', 34000),
      ('340.00A', 34000),
      ('0.50', 50),
    ];
    for (final (input, paise) in accepted) {
      test('reads "$input" as $paise', () {
        final a = readAmount(input);
        expect(a, isNotNull);
        expect(a!.value.value, paise);
        expect(a.negative, isFalse);
      });
    }

    const negatives = ['-50.00', '(50.00)', '50.00-', '−50.00', '-₹50.00'];
    for (final input in negatives) {
      test('reads "$input" as a negative 5000', () {
        final a = readAmount(input);
        expect(a!.value.value, 5000);
        expect(a.negative, isTrue);
        expect(a.signed.value, -5000);
      });
    }

    const notAmounts = [
      '',
      'Paneer',
      '14/11/2026',
      '21:14',
      '5%',
      '24ABCDE1234F1Z5',
      '9876543210', // a phone number
      '1.2.3',
      'x',
      '--',
    ];
    for (final input in notAmounts) {
      test('does not read "$input" as an amount', () {
        expect(readAmount(input), isNull);
      });
    }

    test('repairs the letter O and l read in place of digits', () {
      final a = readAmount('34O.OO');
      expect(a!.value.value, 34000);
      expect(a.repaired, isTrue);
      expect(readAmount('1l5.00')!.value.value, 11500);
    });

    test('does not repair ordinary words', () {
      expect(readAmount('Oil'), isNull);
      expect(readAmount('lol'), isNull);
    });

    test('records whether decimals and a currency sign were printed', () {
      expect(readAmount('340.00')!.hasDecimals, isTrue);
      expect(readAmount('340')!.hasDecimals, isFalse);
      expect(readAmount('₹340')!.hasCurrency, isTrue);
      expect(readAmount('340')!.hasCurrency, isFalse);
    });
  });

  group('analyseRow', () {
    test('folds a lone currency sign into the amount after it', () {
      final words = analyseRow('TOTAL Rs 1025.33');
      expect(words.map((w) => w.text), ['TOTAL', '1025.33']);
      expect(words.last.amount!.hasCurrency, isTrue);
      expect(words.last.amount!.value.value, 102533);
    });

    test('keeps ordinary words and finds every amount', () {
      final words = analyseRow('Butter Naan 4 40.00 160.00');
      final amounts = [
        for (final w in words)
          if (w.amount != null) w.amount!.value.value,
      ];
      // "4" is a plausible amount on its own; the parser decides it is a
      // quantity from context.
      expect(amounts, [400, 4000, 16000]);
    });

    test('an empty row has no words', () {
      expect(analyseRow('   '), isEmpty);
    });
  });
}
