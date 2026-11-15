import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/features/bills/domain/engine/money.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';
import '../../support/fuzz.dart';

void main() {
  group('formatMoney', () {
    test('formats rupees with Indian grouping', () {
      expect(formatMoney(p(10000000), Currency.inr), '₹1,00,000.00');
      expect(formatMoney(p(123450), Currency.inr), '₹1,234.50');
      expect(formatMoney(p(1), Currency.inr), '₹0.01');
      expect(formatMoney(p(-34000), Currency.inr), '-₹340.00');
    });

    test('formats other currencies with thousands grouping', () {
      expect(formatMoney(p(10000000), Currency.usd), r'$100,000.00');
      expect(formatMoney(p(123450), Currency.gbp), '£1,234.50');
      expect(formatMoney(p(99), Currency.eur), '€0.99');
    });

    test(
      'agrees with the engine formatter for 10,000 random rupee amounts',
      () {
        // formatPaise is the original hand-written Indian grouping; the intl
        // based formatter must never disagree with it.
        fuzz((rnd) {
          for (var i = 0; i < 10000; i++) {
            final v = p(rnd.nextInt(2000000000) - 1000000000);
            expect(formatMoney(v, Currency.inr), formatPaise(v));
          }
        });
      },
    );
  });

  group('Currency.detect', () {
    test('reads symbols and codes', () {
      expect(Currency.detect('Rs 1025.33'), Currency.inr);
      expect(Currency.detect('TOTAL ₹ 540'), Currency.inr);
      expect(Currency.detect('Total INR 540.00'), Currency.inr);
      expect(Currency.detect(r'Total $12.50'), Currency.usd);
      expect(Currency.detect('Total € 9,50'), Currency.eur);
      expect(Currency.detect('Total £4.20'), Currency.gbp);
    });

    test('does not guess when there is no sign of a currency', () {
      expect(Currency.detect('TOTAL 540.00'), isNull);
      expect(Currency.detect('Thank you. Visit again!'), isNull);
    });

    test('falls back to rupees for an unknown stored code', () {
      expect(Currency.fromCode('XYZ'), Currency.inr);
      expect(Currency.fromCode(null), Currency.inr);
      expect(Currency.fromCode('GBP'), Currency.gbp);
    });
  });
}
