/// Percentage parsing and formatting: basis points, never doubles.
///
/// Percentages are integer basis points (5% = 500), so a tax rate is never
/// 0.05000000000000001. This mirrors `parseAmount` in money.dart: the integer
/// and fractional parts are read as digit strings and combined with integer
/// arithmetic, so no double ever touches a rate.
///
/// Pure Dart.
library;

import 'money.dart';

/// Why a typed percentage could not be read.
enum PercentFailure {
  empty('empty'),
  notANumber('not-a-number'),
  negative('negative'),
  tooManyDecimals('too-many-decimals'),
  tooLarge('too-large');

  const PercentFailure(this.wireName);
  final String wireName;
}

sealed class PercentResult {
  const PercentResult();
}

final class PercentOk extends PercentResult {
  const PercentOk(this.basisPoints);
  final int basisPoints;
}

final class PercentError extends PercentResult {
  const PercentError(this.reason);
  final PercentFailure reason;
}

/// 100%. A charge above this is almost certainly a typo, so it is rejected.
const int maxBasisPoints = 10000;

final RegExp _percentSign = RegExp('%');
final RegExp _whitespace = RegExp(r'\s');
final RegExp _tooManyDecimals = RegExp(r'^\d+\.\d{3,}$');
final RegExp _percentShape = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

/// Parses "5", "5.5", "12.25" or "5%" into basis points.
PercentResult parsePercent(String input) {
  final cleaned = input
      .replaceAll(_percentSign, '')
      .replaceAll(_whitespace, '');

  if (cleaned.isEmpty) return const PercentError(PercentFailure.empty);
  if (cleaned.startsWith('-')) {
    return const PercentError(PercentFailure.negative);
  }
  if (_tooManyDecimals.hasMatch(cleaned)) {
    return const PercentError(PercentFailure.tooManyDecimals);
  }

  final match = _percentShape.firstMatch(cleaned);
  if (match == null) return const PercentError(PercentFailure.notANumber);

  final whole = int.tryParse(match.group(1)!);
  if (whole == null) return const PercentError(PercentFailure.tooLarge);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final basisPoints = whole * 100 + int.parse(fraction);

  if (whole > maxSafeInteger ~/ 100 || basisPoints > maxBasisPoints) {
    return const PercentError(PercentFailure.tooLarge);
  }
  return PercentOk(basisPoints);
}

/// 500 -> "5%", 550 -> "5.5%", 1225 -> "12.25%".
String formatPercent(int basisPoints) {
  final whole = basisPoints ~/ 100;
  final fraction = basisPoints - whole * 100;
  if (fraction == 0) return '$whole%';
  final digits = fraction
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0$'), '');
  return '$whole.$digits%';
}
