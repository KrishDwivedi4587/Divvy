import 'package:divvy/core/errors/domain_error.dart';
import 'package:divvy/features/bills/domain/engine/money.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';
import '../../support/fuzz.dart';

Matcher throwsDomainError([DomainErrorCode? code]) => throwsA(
  isA<DomainError>().having(
    (e) => e.code,
    'code',
    code == null ? anything : equals(code),
  ),
);

void main() {
  group('parseAmount', () {
    const accepted = <(String, int)>[
      ('340', 34000),
      ('340.5', 34050),
      ('340.50', 34050),
      ('₹1,234.50', 123450),
      ('1,00,000', 10000000),
      ('0', 0),
      ('0.01', 1),
      ('Rs 500', 50000),
      ('Rs.500', 50000),
      ('  340  ', 34000),
    ];
    for (final (input, expected) in accepted) {
      test('parses $input to $expected paise', () {
        final result = parseAmount(input);
        expect(result, isA<ParseOk>());
        expect((result as ParseOk).value.value, expected);
      });
    }

    const rejected = <(String, ParseFailure)>[
      ('', ParseFailure.empty),
      ('abc', ParseFailure.notANumber),
      ('-5', ParseFailure.negative),
      ('3.999', ParseFailure.tooManyDecimals),
      ('12.345', ParseFailure.tooManyDecimals),
      ('1.2.3', ParseFailure.notANumber),
      ('12abc', ParseFailure.notANumber),
    ];
    for (final (input, reason) in rejected) {
      test('rejects "$input" with reason ${reason.wireName}', () {
        final result = parseAmount(input);
        expect(result, isA<ParseError>());
        expect((result as ParseError).reason, reason);
      });
    }

    test('rejects an amount too large to hold exactly', () {
      final result = parseAmount('9' * 30);
      expect((result as ParseError).reason, ParseFailure.tooLarge);
    });

    test('never produces a fractional paise value', () {
      fuzz((rnd) {
        for (var i = 0; i < 1000; i++) {
          final rupees = rnd.nextInt(100000);
          final paise = rnd.nextInt(100);
          final text = '$rupees.${paise.toString().padLeft(2, '0')}';
          final result = parseAmount(text);
          expect(result, isA<ParseOk>());
          expect((result as ParseOk).value.value, rupees * 100 + paise);
        }
      });
    });
  });

  group('formatPaise', () {
    const cases = <(int, String)>[
      (0, '₹0.00'),
      (1, '₹0.01'),
      (99, '₹0.99'),
      (100, '₹1.00'),
      (123450, '₹1,234.50'),
      (10000000, '₹1,00,000.00'),
      (1234567890, '₹1,23,45,678.90'),
      (-34000, '-₹340.00'),
    ];
    for (final (input, expected) in cases) {
      test('formats $input as $expected', () {
        expect(formatPaise(p(input)), expected);
      });
    }

    test('uses Indian digit grouping, not Western', () {
      expect(formatPaise(p(10000000)), '₹1,00,000.00');
      expect(formatPaise(p(10000000)), isNot('₹100,000.00'));
    });

    test('round-trips through parseAmount for 10,000 random values', () {
      fuzz((rnd) {
        for (var i = 0; i < 10000; i++) {
          final value = p(rnd.nextInt(100000000));
          final reparsed = parseAmount(formatPaise(value));
          expect(reparsed, isA<ParseOk>());
          expect((reparsed as ParseOk).value, value);
        }
      });
    });
  });

  group('divRoundHalfAwayFromZero', () {
    const cases = <(int, int, int)>[
      (10, 4, 3), // 2.5 -> 3
      (-10, 4, -3), // -2.5 -> -3, away from zero
      (14, 4, 4), // 3.5 -> 4
      (11, 4, 3), // 2.75 -> 3
      (9, 4, 2), // 2.25 -> 2
      (0, 4, 0),
      (7, 1, 7),
    ];
    for (final (num, den, expected) in cases) {
      test('$num / $den rounds to $expected', () {
        expect(divRoundHalfAwayFromZero(num, den), expected);
      });
    }

    test('is symmetric: f(-x) == -f(x)', () {
      for (var n = 1; n <= 500; n++) {
        expect(
          divRoundHalfAwayFromZero(-n, 7),
          -divRoundHalfAwayFromZero(n, 7),
        );
        expect(
          divRoundHalfAwayFromZero(n, -7),
          -divRoundHalfAwayFromZero(n, 7),
        );
      }
    });

    test('a zero numerator gives zero whatever the signs', () {
      // The TypeScript engine had to normalise negative zero here. Dart
      // integers have no negative zero, so this holds by construction; the
      // test pins the behaviour regardless.
      expect(divRoundHalfAwayFromZero(0, 7), 0);
      expect(divRoundHalfAwayFromZero(0, -7), 0);
      expect(divRoundHalfAwayFromZero(0, 7).isNegative, isFalse);
    });

    test('throws on division by zero', () {
      expect(() => divRoundHalfAwayFromZero(1, 0), throwsDomainError());
    });
  });

  group('percentOf', () {
    test('applies basis points: 5% of 930.00 is 46.50', () {
      expect(percentOf(p(93000), 500), p(4650));
    });

    test('rounds half away from zero: 5% of 97650 is 4882.5 -> 4883', () {
      expect(percentOf(p(97650), 500), p(4883));
    });

    test('handles 0%', () => expect(percentOf(p(93000), 0), p(0)));
    test('handles 100%', () => expect(percentOf(p(93000), 10000), p(93000)));
    test('handles 18% GST', () => expect(percentOf(p(100000), 1800), p(18000)));

    test('rejects a product that would lose precision', () {
      expect(
        () => percentOf(p(maxSafeInteger ~/ 2), 10000),
        throwsDomainError(DomainErrorCode.unsafeMagnitude),
      );
    });

    test('always returns a whole number of paise, matching exact rounding', () {
      fuzz((rnd) {
        for (var i = 0; i < 2000; i++) {
          final amount = rnd.nextInt(10000000);
          final bp = rnd.nextInt(3000);
          // Independent check using only integer arithmetic on the product.
          final product = amount * bp;
          final expected = product ~/ 10000 + (product % 10000 >= 5000 ? 1 : 0);
          expect(percentOf(p(amount), bp).value, expected);
        }
      });
    });
  });

  group('toPaise', () {
    test('accepts safe integers', () {
      expect(toPaise(0), p(0));
      expect(toPaise(-500), p(-500));
    });

    test('accepts a whole-valued double', () => expect(toPaise(12.0), p(12)));

    test('rejects a fractional value', () {
      expect(
        () => toPaise(1.5),
        throwsDomainError(DomainErrorCode.notAnInteger),
      );
    });

    test('rejects NaN and infinity', () {
      expect(
        () => toPaise(double.nan),
        throwsDomainError(DomainErrorCode.notFinite),
      );
      expect(
        () => toPaise(double.infinity),
        throwsDomainError(DomainErrorCode.notFinite),
      );
    });

    test('rejects a magnitude beyond the safe range', () {
      expect(
        () => toPaise(maxSafeInteger + 1),
        throwsDomainError(DomainErrorCode.unsafeMagnitude),
      );
    });
  });

  group('sumPaise', () {
    test('sums exactly', () {
      expect(sumPaise([p(3333), p(3333), p(3334)]), p(10000));
    });

    test('returns zero for an empty list', () {
      expect(sumPaise(const []), p(0));
    });
  });
}
