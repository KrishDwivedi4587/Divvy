/// Text-input helpers for decimal fields.
///
/// Pure Dart. These sit between a text field and the money parsers: the
/// sanitiser keeps what the user types well-formed, and the normaliser turns a
/// transitional value like "340." into something the parsers accept.
library;

/// Filters raw keyboard input down to a plausible decimal number: digits and at
/// most one decimal point, with a capped number of decimal places.
///
/// It deliberately does not try to be clever about locale. A comma is dropped
/// rather than reinterpreted as a decimal separator: guessing wrong would turn
/// "1,234" into 1.234, a thousand-fold error in a money field, whereas dropping
/// the comma keeps the digits the user actually typed.
String sanitizeDecimalInput(
  String raw, {
  int maxDecimals = 2,
  int maxIntegerDigits = 8,
}) {
  final out = StringBuffer();
  var seenDot = false;
  var decimals = 0;
  var integerDigits = 0;

  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    final isDigit = rune >= 0x30 && rune <= 0x39;
    if (isDigit) {
      if (seenDot) {
        if (decimals >= maxDecimals) continue;
        decimals += 1;
      } else {
        if (integerDigits >= maxIntegerDigits) continue;
        integerDigits += 1;
      }
      out.write(ch);
    } else if (ch == '.' && !seenDot && maxDecimals > 0) {
      seenDot = true;
      out.write(ch);
    }
  }

  return out.toString();
}

/// Turns a transitional text value into one the parsers accept:
/// "" stays "", "340." becomes "340", ".5" becomes "0.5".
String normalizeDecimalText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed == '.') return '';
  var out = trimmed;
  if (out.startsWith('.')) out = '0$out';
  if (out.endsWith('.')) out = out.substring(0, out.length - 1);
  return out;
}
