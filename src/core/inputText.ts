/**
 * Text-input helpers for decimal fields.
 *
 * Pure TypeScript. These sit between a `TextInput` and the money parsers: the
 * sanitiser keeps what the user types well-formed, and the normaliser turns a
 * transitional value like "340." into something the parsers accept.
 */

/**
 * Filters raw keyboard input down to a plausible decimal number: digits and at
 * most one decimal point, with a capped number of decimal places.
 *
 * It deliberately does not try to be clever about locale. A comma is dropped
 * rather than reinterpreted as a decimal separator: guessing wrong would turn
 * "1,234" into 1.234, a thousand-fold error in a money field, whereas dropping
 * the comma keeps the digits the user actually typed.
 */
export function sanitizeDecimalInput(raw: string, maxDecimals = 2, maxIntegerDigits = 8): string {
  let out = '';
  let seenDot = false;
  let decimals = 0;
  let integerDigits = 0;

  for (const ch of raw) {
    if (ch >= '0' && ch <= '9') {
      if (seenDot) {
        if (decimals >= maxDecimals) continue;
        decimals += 1;
      } else {
        if (integerDigits >= maxIntegerDigits) continue;
        integerDigits += 1;
      }
      out += ch;
    } else if (ch === '.' && !seenDot && maxDecimals > 0) {
      seenDot = true;
      out += ch;
    }
  }

  return out;
}

/**
 * Turns a transitional text value into one the parsers accept:
 * "" stays "", "340." becomes "340", ".5" becomes "0.5".
 */
export function normalizeDecimalText(text: string): string {
  const trimmed = text.trim();
  if (trimmed === '' || trimmed === '.') return '';
  let out = trimmed;
  if (out.startsWith('.')) out = `0${out}`;
  if (out.endsWith('.')) out = out.slice(0, -1);
  return out;
}
