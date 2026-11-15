import 'package:intl/intl.dart';

import '../../features/bills/domain/engine/money.dart';

/// The currencies Divvy can display. All use two minor-unit digits, which is
/// what the engine's integer arithmetic assumes.
enum Currency {
  inr('INR', '₹', 'en_IN', 'Indian rupee'),
  usd('USD', r'$', 'en_US', 'US dollar'),
  eur('EUR', '€', 'en_IE', 'Euro'),
  gbp('GBP', '£', 'en_GB', 'Pound sterling');

  const Currency(this.code, this.symbol, this.locale, this.label);

  final String code;
  final String symbol;

  /// The locale whose digit grouping this currency uses (Indian lakh/crore
  /// grouping for the rupee, thousands grouping for the rest).
  final String locale;
  final String label;

  static Currency fromCode(String? code) =>
      values.firstWhere((c) => c.code == code, orElse: () => inr);

  /// Reads a currency symbol or code out of free text such as a receipt line.
  /// Returns null when nothing is recognised, rather than guessing.
  static Currency? detect(String text) {
    final lower = text.toLowerCase();
    if (text.contains('₹') ||
        RegExp(r'\brs\.?\s*\d', caseSensitive: false).hasMatch(text) ||
        lower.contains('inr')) {
      return inr;
    }
    if (text.contains('€') || lower.contains('eur')) return eur;
    if (text.contains('£') || lower.contains('gbp')) return gbp;
    if (text.contains(r'$') || lower.contains('usd')) return usd;
    return null;
  }
}

/// Formats [value] in [currency] from integer minor units, never through a
/// double: the whole part is grouped by `intl` as an int and the two-digit
/// fraction is appended as text.
String formatMoney(Paise value, Currency currency) {
  final negative = value.isNegative;
  final abs = value.value.abs();
  final whole = abs ~/ 100;
  final fraction = (abs % 100).toString().padLeft(2, '0');
  final grouped = NumberFormat.decimalPattern(currency.locale).format(whole);
  return '${negative ? '-' : ''}${currency.symbol}$grouped.$fraction';
}
