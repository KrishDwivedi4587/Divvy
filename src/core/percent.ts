/**
 * Percentage parsing and formatting — basis points, never floats.
 *
 * Roadmap §8 principle 2: percentages are integer basis points (5% = 500), so a
 * tax rate is never 0.05000000000000001. This mirrors `parseAmount` in money.ts:
 * the integer and fractional parts are read as digit strings and combined with
 * integer arithmetic, so no float ever touches a rate.
 *
 * Pure TypeScript.
 */

export type PercentFailure =
  'empty' | 'not-a-number' | 'negative' | 'too-many-decimals' | 'too-large';

export type PercentResult =
  { ok: true; basisPoints: number } | { ok: false; reason: PercentFailure };

/** 100%. A charge above this is almost certainly a typo, so it is rejected. */
export const MAX_BASIS_POINTS = 10_000;

/** Parses "5", "5.5", "12.25" or "5%" into basis points. */
export function parsePercent(input: string): PercentResult {
  const cleaned = input.replace(/%/g, '').replace(/\s/g, '');

  if (cleaned === '') return { ok: false, reason: 'empty' };
  if (cleaned.startsWith('-')) return { ok: false, reason: 'negative' };
  if (/^\d+\.\d{3,}$/.test(cleaned)) return { ok: false, reason: 'too-many-decimals' };

  const match = /^(\d+)(?:\.(\d{1,2}))?$/.exec(cleaned);
  if (!match) return { ok: false, reason: 'not-a-number' };

  const whole = Number(match[1]);
  const fraction = (match[2] ?? '').padEnd(2, '0');
  const basisPoints = whole * 100 + Number(fraction);

  if (!Number.isSafeInteger(basisPoints) || basisPoints > MAX_BASIS_POINTS) {
    return { ok: false, reason: 'too-large' };
  }
  return { ok: true, basisPoints };
}

/** 500 → "5%", 550 → "5.5%", 1225 → "12.25%". */
export function formatPercent(basisPoints: number): string {
  const whole = Math.floor(basisPoints / 100);
  const fraction = basisPoints - whole * 100;
  if (fraction === 0) return `${whole}%`;
  const digits = String(fraction).padStart(2, '0').replace(/0$/, '');
  return `${whole}.${digits}%`;
}
