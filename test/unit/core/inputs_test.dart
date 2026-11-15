import 'package:divvy/core/utils/decimal_input.dart';
import 'package:divvy/features/bills/domain/engine/percent.dart';
import 'package:divvy/features/people/domain/person_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fuzz.dart';

void main() {
  group('sanitizeDecimalInput', () {
    const cases = <(String, String)>[
      ('', ''),
      ('340', '340'),
      ('340.5', '340.5'),
      ('340.50', '340.50'),
      ('340.', '340.'),
      ('.5', '.5'),
      ('abc', ''),
      ('12abc34', '1234'),
      ('1.2.3', '1.23'),
      ('12.345', '12.34'),
      ('-5', '5'),
      ('₹1,234.50', '1234.50'),
    ];
    for (final (raw, expected) in cases) {
      test('sanitises "$raw" to "$expected"', () {
        expect(sanitizeDecimalInput(raw), expected);
      });
    }

    test('caps integer digits so an absurd paste cannot overflow', () {
      expect(sanitizeDecimalInput('123456789012'), '12345678');
    });

    test('honours a custom decimal limit, including none', () {
      expect(sanitizeDecimalInput('12.345', maxDecimals: 3), '12.345');
      expect(sanitizeDecimalInput('12.5', maxDecimals: 0), '125');
    });

    test('drops a comma rather than guessing a decimal separator', () {
      // Guessing wrong would turn 1,234 into 1.234, a thousand-fold error.
      expect(sanitizeDecimalInput('1,234'), '1234');
    });
  });

  group('normalizeDecimalText', () {
    const cases = <(String, String)>[
      ('', ''),
      ('   ', ''),
      ('.', ''),
      ('340.', '340'),
      ('.5', '0.5'),
      (' 12.50 ', '12.50'),
      ('7', '7'),
    ];
    for (final (input, expected) in cases) {
      test('normalises "$input" to "$expected"', () {
        expect(normalizeDecimalText(input), expected);
      });
    }
  });

  group('parsePercent', () {
    const accepted = <(String, int)>[
      ('5', 500),
      ('5%', 500),
      ('5.5', 550),
      ('12.25', 1225),
      ('0', 0),
      ('100', 10000),
      (' 18 % ', 1800),
      ('0.01', 1),
    ];
    for (final (input, expected) in accepted) {
      test('parses "$input" as $expected basis points', () {
        final result = parsePercent(input);
        expect(result, isA<PercentOk>());
        expect((result as PercentOk).basisPoints, expected);
      });
    }

    const rejected = <(String, PercentFailure)>[
      ('', PercentFailure.empty),
      ('abc', PercentFailure.notANumber),
      ('-5', PercentFailure.negative),
      ('5.123', PercentFailure.tooManyDecimals),
      ('100.01', PercentFailure.tooLarge),
      ('101', PercentFailure.tooLarge),
      ('1.2.3', PercentFailure.notANumber),
    ];
    for (final (input, reason) in rejected) {
      test('rejects "$input" as ${reason.wireName}', () {
        final result = parsePercent(input);
        expect(result, isA<PercentError>());
        expect((result as PercentError).reason, reason);
      });
    }

    test('produces only whole basis points, never a double', () {
      fuzz((rnd) {
        for (var i = 0; i < 1000; i++) {
          final whole = rnd.nextInt(100);
          final frac = rnd.nextInt(100).toString().padLeft(2, '0');
          final result = parsePercent('$whole.$frac');
          expect(result, isA<PercentOk>());
          expect(
            (result as PercentOk).basisPoints,
            whole * 100 + int.parse(frac),
          );
        }
      });
    });

    test('treats exactly 100% as the ceiling', () {
      expect(maxBasisPoints, 10000);
    });
  });

  group('formatPercent', () {
    const cases = <(int, String)>[
      (500, '5%'),
      (550, '5.5%'),
      (1225, '12.25%'),
      (1, '0.01%'),
      (0, '0%'),
      (10000, '100%'),
    ];
    for (final (bp, expected) in cases) {
      test('formats $bp as $expected', () {
        expect(formatPercent(bp), expected);
      });
    }

    test('round-trips through parsePercent', () {
      for (var bp = 0; bp <= 10000; bp += 7) {
        final parsed = parsePercent(formatPercent(bp));
        expect(parsed, isA<PercentOk>());
        expect((parsed as PercentOk).basisPoints, bp);
      }
    });
  });

  group('initialsFor', () {
    const cases = <(String, String)>[
      ('Priya', 'PR'),
      ('Raj Patel', 'RP'),
      ('  raj   patel  ', 'RP'),
      ('Mary Jane Watson', 'MJ'),
      ('You', 'YO'),
      ('A', 'A'),
      ('aarav', 'AA'),
      ('', '?'),
      ('   ', '?'),
      ('!!!', '?'),
      ('Zoë', 'ZO'),
    ];
    for (final (name, expected) in cases) {
      test('derives "$name" -> "$expected"', () {
        expect(initialsFor(name), expected);
      });
    }
  });

  group('checkPersonName', () {
    test('accepts and tidies a valid name', () {
      final result = checkPersonName('  Priya   Shah ', const []);
      expect((result as NameOk).name, 'Priya Shah');
    });

    test('rejects an empty name', () {
      final result = checkPersonName('   ', const []);
      expect((result as NameRejected).reason, NameCheckFailure.empty);
    });

    test('rejects a duplicate regardless of case', () {
      final result = checkPersonName('RAJ', const ['Raj']);
      expect((result as NameRejected).reason, NameCheckFailure.duplicate);
    });

    test('rejects a name that is too long', () {
      final result = checkPersonName('x' * 25, const []);
      expect((result as NameRejected).reason, NameCheckFailure.tooLong);
    });

    test('accepts a name exactly at the length limit', () {
      expect(checkPersonName('x' * 24, const []), isA<NameOk>());
    });

    test('enforces the people limit before anything else', () {
      final full = List.generate(maxPeople, (i) => 'P$i');
      final result = checkPersonName('New', full);
      expect((result as NameRejected).reason, NameCheckFailure.limit);
    });
  });
}
