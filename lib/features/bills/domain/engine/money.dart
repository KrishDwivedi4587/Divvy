/// Money primitives.
///
/// All money is integer minor units (paise for rupees, cents for dollars).
/// There is no floating-point arithmetic anywhere in this file or anything that
/// depends on it: `0.1 + 0.2 != 0.3` makes the project's central guarantee
/// (everyone's totals sum to the bill total) impossible to keep with doubles.
///
/// Pure Dart. Imports nothing from Flutter, the database or the UI.
library;

import '../../../../core/errors/domain_error.dart';

/// Integer minor units. NEVER a double. NEVER whole rupees. Rs 123.45 is 12345.
///
/// An extension type, so a raw `int` cannot be passed where money is expected:
/// mixing rupees and paise becomes a compile error rather than a silent
/// hundred-fold bug, at no runtime cost.
extension type const Paise(int value) {
  static const Paise zero = Paise(0);

  Paise operator +(Paise other) => Paise(value + other.value);
  Paise operator -(Paise other) => Paise(value - other.value);
  Paise operator -() => Paise(-value);
  bool operator <(Paise other) => value < other.value;
  bool operator <=(Paise other) => value <= other.value;
  bool operator >(Paise other) => value > other.value;
  bool operator >=(Paise other) => value >= other.value;

  bool get isNegative => value < 0;
  bool get isZero => value == 0;
}

/// Products computed inside the apportionment (amount x weight) must stay
/// exact. This is JavaScript's `Number.MAX_SAFE_INTEGER`, kept as the engine's
/// limit so behaviour matches the original engine (and so the same code stays
/// exact if it is ever compiled to the web, where integers are doubles).
const int maxSafeInteger = 9007199254740991;

/// Wraps a raw number as [Paise], rejecting anything that is not a safe integer.
Paise toPaise(num value) {
  if (value is double && !value.isFinite) {
    throw DomainError(
      DomainErrorCode.notFinite,
      'Amount must be finite, got $value',
    );
  }
  if (value is double && value != value.truncateToDouble()) {
    throw DomainError(
      DomainErrorCode.notAnInteger,
      'Amount must be whole minor units, got $value',
    );
  }
  final whole = value.toInt();
  if (whole.abs() > maxSafeInteger) {
    throw DomainError(
      DomainErrorCode.unsafeMagnitude,
      'Amount exceeds safe integer range: $value',
    );
  }
  return Paise(whole);
}

/// Guards a product against silent precision loss above 2^53.
void assertSafeProduct(int a, int b) {
  final divisor = b.abs() < 1 ? 1 : b.abs();
  if (a.abs() > maxSafeInteger ~/ divisor) {
    throw DomainError(
      DomainErrorCode.unsafeMagnitude,
      'Product $a x $b would exceed the safe integer range',
    );
  }
}

/// Sums amounts exactly.
Paise sumPaise(Iterable<Paise> values) {
  var total = 0;
  for (final v in values) {
    total += v.value;
  }
  return toPaise(total);
}

/// The engine's single rounding rule: **half away from zero**, applied to whole
/// minor units, and applied at exactly one place: converting a percentage into
/// an amount ([percentOf]).
///
/// Nothing else rounds. Every distribution across people is exact by
/// construction via largest-remainder, so no second rounding rule can exist to
/// disagree with this one.
///
/// Half away from zero (rather than half up) keeps `f(-x) == -f(x)`, which is
/// what makes the discount path in `apportion` symmetric with the charge path.
int divRoundHalfAwayFromZero(int numerator, int denominator) {
  if (denominator == 0) {
    throw const DomainError(DomainErrorCode.notFinite, 'Division by zero');
  }
  final negative = (numerator < 0) != (denominator < 0);
  final absNum = numerator.abs();
  final absDen = denominator.abs();

  final quotient = absNum ~/ absDen;
  final remainder = absNum - quotient * absDen;

  // remainder/absDen >= 0.5  <=>  remainder*2 >= absDen. Integer-only.
  final rounded = remainder * 2 >= absDen ? quotient + 1 : quotient;
  return negative ? -rounded : rounded;
}

/// Applies a basis-point rate to an amount. 500 bp = 5%.
///
/// Basis points keep percentages integral, so a "5% GST" never becomes
/// 0.05000000000000001.
Paise percentOf(Paise amount, int basisPoints) {
  assertSafeProduct(amount.value, basisPoints);
  return toPaise(divRoundHalfAwayFromZero(amount.value * basisPoints, 10000));
}

/// Why a typed amount could not be read.
enum ParseFailure {
  empty('empty'),
  notANumber('not-a-number'),
  negative('negative'),
  tooManyDecimals('too-many-decimals'),
  tooLarge('too-large');

  const ParseFailure(this.wireName);
  final String wireName;
}

/// The outcome of reading user input: either a value or a reason, never a throw.
sealed class ParseResult {
  const ParseResult();
}

final class ParseOk extends ParseResult {
  const ParseOk(this.value);
  final Paise value;
}

final class ParseError extends ParseResult {
  const ParseError(this.reason);
  final ParseFailure reason;
}

final RegExp _currencyPrefix = RegExp(
  r'^\s*(?:₹|Rs\.?|INR)\s*',
  caseSensitive: false,
);
final RegExp _separators = RegExp(r'[\s,]');
final RegExp _tooManyDecimals = RegExp(r'^\d+\.\d{3,}$');
final RegExp _amountShape = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

/// Parses a user-typed rupee amount into paise. Accepts `340`, `340.5`,
/// `340.50`, `₹1,234.50`, `Rs 500`, `1,00,000`.
///
/// Never uses `double.parse`: the integer and fractional parts are read
/// separately as digit strings, so no double ever touches a money value.
ParseResult parseAmount(String input) {
  final cleaned = input
      .replaceFirst(_currencyPrefix, '')
      .replaceAll(_separators, '')
      .trim();

  if (cleaned.isEmpty) return const ParseError(ParseFailure.empty);
  if (cleaned.startsWith('-')) return const ParseError(ParseFailure.negative);

  // Distinguish "too many decimals" from "not a number" so the UI can say why.
  if (_tooManyDecimals.hasMatch(cleaned)) {
    return const ParseError(ParseFailure.tooManyDecimals);
  }

  final match = _amountShape.firstMatch(cleaned);
  if (match == null) return const ParseError(ParseFailure.notANumber);

  final rupees = int.tryParse(match.group(1)!);
  if (rupees == null) return const ParseError(ParseFailure.tooLarge);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final paise = rupees * 100 + int.parse(fraction);

  if (rupees > maxSafeInteger ~/ 100 || paise > maxSafeInteger) {
    return const ParseError(ParseFailure.tooLarge);
  }
  return ParseOk(Paise(paise));
}

/// Formats paise as Indian-grouped rupees: 10000000 -> "₹1,00,000.00".
///
/// Grouping is implemented directly rather than through a locale library so
/// money formatting is byte-identical on every device and in every test.
String formatPaise(Paise value) {
  final sign = value.isNegative ? '-' : '';
  final abs = value.value.abs();

  final rupees = abs ~/ 100;
  final paise = abs - rupees * 100;

  return '$sign₹${_groupIndian(rupees)}.${paise.toString().padLeft(2, '0')}';
}

/// Last three digits, then groups of two: 12345678 -> "1,23,45,678".
String _groupIndian(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final groups = <String>[];
  for (var end = rest.length; end > 0; end -= 2) {
    final start = end - 2 < 0 ? 0 : end - 2;
    groups.insert(0, rest.substring(start, end));
  }
  return '${groups.join(',')},$last3';
}
