/**
 * Money primitives — roadmap §8 principles 1 and 2.
 *
 * All money is integer paise. There is no floating-point arithmetic anywhere in
 * this file or anything that depends on it: `0.1 + 0.2 !== 0.3` makes the
 * project's central guarantee (everyone's totals sum to the bill total)
 * impossible to keep with floats.
 *
 * Pure TypeScript. Imports nothing from react, react-native, expo or the store.
 */

import type { Paise } from '@/domain/types';

/* ------------------------------------------------------------------ *
 * Errors                                                              *
 * ------------------------------------------------------------------ */

export type DomainErrorCode =
  | 'NOT_AN_INTEGER'
  | 'NOT_FINITE'
  | 'NEGATIVE_AMOUNT'
  | 'UNSAFE_MAGNITUDE'
  | 'INVALID_BASIS_POINTS'
  | 'DUPLICATE_ID'
  | 'UNKNOWN_PERSON'
  | 'UNKNOWN_ITEM'
  | 'NO_PEOPLE'
  | 'INVALID_QUANTITY';

/**
 * Thrown for structurally invalid domain data — a programmer or data-integrity
 * error, not something a user can type.
 *
 * The engine uses two deliberately different error strategies:
 *   - Invalid *domain data* throws `DomainError`. It means a bug upstream, and
 *     failing loudly is better than silently producing wrong money.
 *   - Invalid *user input* (see `parseAmount`) returns a typed result instead,
 *     because the UI has to render an inline message rather than crash.
 */
export class DomainError extends Error {
  readonly code: DomainErrorCode;

  constructor(code: DomainErrorCode, message: string) {
    super(message);
    this.name = 'DomainError';
    this.code = code;
  }
}

/* ------------------------------------------------------------------ *
 * Construction and guards                                             *
 * ------------------------------------------------------------------ */

/**
 * Products computed inside the apportionment (amount × weight) must stay exact.
 * Above 2^53 JavaScript integers silently lose precision, which would corrupt
 * money without any error. This bound is checked rather than assumed.
 */
const MAX_SAFE = Number.MAX_SAFE_INTEGER;

export function isPaise(value: number): boolean {
  return Number.isSafeInteger(value);
}

/** Wraps a raw integer as Paise, rejecting anything that is not a safe integer. */
export function toPaise(value: number): Paise {
  if (!Number.isFinite(value)) {
    throw new DomainError('NOT_FINITE', `Amount must be finite, got ${value}`);
  }
  if (!Number.isInteger(value)) {
    throw new DomainError('NOT_AN_INTEGER', `Amount must be whole paise, got ${value}`);
  }
  if (!Number.isSafeInteger(value)) {
    throw new DomainError('UNSAFE_MAGNITUDE', `Amount exceeds safe integer range: ${value}`);
  }
  return value as Paise;
}

/** Guards a product against silent precision loss above 2^53. */
export function assertSafeProduct(a: number, b: number): void {
  if (Math.abs(a) > MAX_SAFE / Math.max(1, Math.abs(b))) {
    throw new DomainError(
      'UNSAFE_MAGNITUDE',
      `Product ${a} × ${b} would exceed Number.MAX_SAFE_INTEGER`,
    );
  }
}

export const ZERO = 0 as Paise;

/** Sums paise exactly. */
export function sumPaise(values: readonly Paise[]): Paise {
  let total = 0;
  for (const v of values) total += v;
  return toPaise(total);
}

/* ------------------------------------------------------------------ *
 * Rounding                                                            *
 * ------------------------------------------------------------------ */

/**
 * The engine's single rounding rule: **half away from zero**, applied to whole
 * paise, and applied at exactly one place — converting a percentage into a
 * paise amount (`percentOf`).
 *
 * Nothing else rounds. Every distribution across people is exact by
 * construction via largest-remainder, so no second rounding rule can exist to
 * disagree with this one.
 *
 * Half away from zero (rather than half up) keeps `f(-x) === -f(x)`, which is
 * what makes the discount path in `apportion` symmetric with the charge path.
 */
export function divRoundHalfAwayFromZero(numerator: number, denominator: number): number {
  if (denominator === 0) {
    throw new DomainError('NOT_FINITE', 'Division by zero');
  }
  const sign = numerator < 0 !== denominator < 0 ? -1 : 1;
  const absNum = Math.abs(numerator);
  const absDen = Math.abs(denominator);

  const quotient = Math.floor(absNum / absDen);
  const remainder = absNum - quotient * absDen;

  // remainder/absDen >= 0.5  ⟺  remainder*2 >= absDen. Integer-only comparison.
  const rounded = remainder * 2 >= absDen ? quotient + 1 : quotient;

  // Normalise -0 to 0. There is no negative zero rupees, and letting -0 escape
  // makes `Object.is` comparisons in tests fail for no useful reason.
  const result = sign * rounded;
  return result === 0 ? 0 : result;
}

/**
 * Applies a basis-point rate to a paise amount. 500 bp = 5%.
 *
 * Basis points keep percentages integral, so a "5% GST" never becomes
 * 0.05000000000000001.
 */
export function percentOf(amount: Paise, basisPoints: number): Paise {
  if (!Number.isInteger(basisPoints)) {
    throw new DomainError('INVALID_BASIS_POINTS', `Basis points must be an integer`);
  }
  assertSafeProduct(amount, basisPoints);
  return toPaise(divRoundHalfAwayFromZero(amount * basisPoints, 10_000));
}

/* ------------------------------------------------------------------ *
 * Parsing user input                                                  *
 * ------------------------------------------------------------------ */

export type ParseFailure =
  'empty' | 'not-a-number' | 'negative' | 'too-many-decimals' | 'too-large';

export type ParseResult = { ok: true; value: Paise } | { ok: false; reason: ParseFailure };

/**
 * Parses a user-typed rupee amount into paise. Accepts `340`, `340.5`,
 * `340.50`, `₹1,234.50`, `Rs 500`, `1,00,000`.
 *
 * Never uses `parseFloat`: the integer and fractional parts are read separately
 * as digit strings, so no float ever touches a money value.
 */
export function parseAmount(input: string): ParseResult {
  const cleaned = input
    .replace(/^\s*(?:₹|Rs\.?|INR)\s*/i, '')
    .replace(/[\s,]/g, '')
    .trim();

  if (cleaned === '') return { ok: false, reason: 'empty' };
  if (cleaned.startsWith('-')) return { ok: false, reason: 'negative' };

  // Distinguish "too many decimals" from "not a number" so the UI can say why.
  if (/^\d+\.\d{3,}$/.test(cleaned)) return { ok: false, reason: 'too-many-decimals' };

  const match = /^(\d+)(?:\.(\d{1,2}))?$/.exec(cleaned);
  if (!match) return { ok: false, reason: 'not-a-number' };

  const rupees = Number(match[1]);
  const fraction = (match[2] ?? '').padEnd(2, '0');
  const paise = rupees * 100 + Number(fraction);

  if (!Number.isSafeInteger(paise)) return { ok: false, reason: 'too-large' };
  return { ok: true, value: paise as Paise };
}

/* ------------------------------------------------------------------ *
 * Formatting                                                          *
 * ------------------------------------------------------------------ */

/**
 * Formats paise as Indian-grouped rupees: 10000000 → "₹1,00,000.00".
 *
 * Grouping is implemented directly rather than through
 * `Intl.NumberFormat('en-IN')` (which roadmap §8 suggests) for two reasons:
 * Hermes ships a reduced Intl on some Android builds, and Intl inserts a
 * non-breaking space before the symbol in some ICU versions. Money formatting
 * has to be byte-identical on every device and in every test, so the ~10 lines
 * are worth not depending on the platform's ICU build.
 */
export function formatPaise(value: Paise): string {
  const negative = value < 0;
  const abs = Math.abs(value);

  const rupees = Math.floor(abs / 100);
  const paise = abs - rupees * 100;

  return `${negative ? '-' : ''}₹${groupIndian(rupees)}.${String(paise).padStart(2, '0')}`;
}

/** Last three digits, then groups of two: 12345678 → "1,23,45,678". */
function groupIndian(n: number): string {
  const s = String(n);
  if (s.length <= 3) return s;
  const last3 = s.slice(-3);
  const rest = s.slice(0, -3);
  return `${rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',')},${last3}`;
}
