/**
 * Largest-remainder (Hamilton) apportionment — roadmap §8 Step 3.
 *
 * Distributing a tax or service charge proportionally is the place where naive
 * code loses paise: each person's exact share is fractional, and rounding them
 * independently produces a total that misses the real charge by a few paise.
 *
 * Largest remainder fixes that by construction. Everyone gets their floor, and
 * the leftover paise go to whoever was cut most by flooring. The result sums to
 * the requested amount *exactly*, every time — not approximately.
 *
 * Pure. Imports nothing from react, react-native, expo or the store.
 */

import type { ID, Paise } from '@/domain/types';
import { assertSafeProduct, DomainError, toPaise } from './money';
import { compareIds } from './splitItem';

export interface Weighted {
  id: ID;
  /** Non-negative. Typically a person's running subtotal in paise. */
  weight: number;
}

export interface Share {
  id: ID;
  share: Paise;
}

/**
 * Distributes `amount` across `entries` in proportion to their weights.
 *
 * `amount` must be **non-negative**. Discounts are handled by the caller
 * apportioning the absolute value and negating the result — see
 * `apportionSigned` and the note below.
 *
 * When every weight is zero (charges exist but nobody has been assigned
 * anything yet) it falls back to an equal split, which is the only defensible
 * answer and keeps the invariant intact.
 */
export function apportion(amount: Paise, entries: readonly Weighted[]): Share[] {
  if (amount < 0) {
    throw new DomainError(
      'NEGATIVE_AMOUNT',
      `apportion() requires a non-negative amount; use apportionSigned() for discounts`,
    );
  }
  if (entries.length === 0) return [];

  for (const e of entries) {
    if (e.weight < 0 || !Number.isFinite(e.weight)) {
      throw new DomainError('NEGATIVE_AMOUNT', `Weight must be non-negative, got ${e.weight}`);
    }
  }

  const totalWeight = entries.reduce((sum, e) => sum + e.weight, 0);

  // Nobody has a subtotal but a charge still has to land somewhere.
  const effective =
    totalWeight === 0 ? entries.map((e) => ({ id: e.id, weight: 1 })) : [...entries];
  const W = totalWeight === 0 ? effective.length : totalWeight;

  // floor(A × wᵢ / W), with the exact integer remainder kept for the tie-break.
  const rows = effective.map((e) => {
    assertSafeProduct(amount, e.weight);
    const product = amount * e.weight;
    const floor = Math.floor(product / W);
    return { id: e.id, floor, remainder: product - floor * W };
  });

  const allocated = rows.reduce((sum, r) => sum + r.floor, 0);
  let leftover = amount - allocated; // 0 <= leftover < entries.length

  // Largest remainder first; ties broken by id so the result is deterministic.
  const ranked = [...rows].sort((a, b) => b.remainder - a.remainder || compareIds(a.id, b.id));

  const bonus = new Set<ID>();
  for (const row of ranked) {
    if (leftover <= 0) break;
    bonus.add(row.id);
    leftover -= 1;
  }

  // Returned in the caller's original order, not ranked order.
  return rows.map((r) => ({
    id: r.id,
    share: toPaise(r.floor + (bonus.has(r.id) ? 1 : 0)),
  }));
}

/**
 * Apportions a signed amount.
 *
 * **The D7 trap.** A discount must not be pushed through `apportion` as a
 * negative number: `Math.floor(-7 / 3)` is `-3`, not `-2`, so the floors
 * overshoot, `leftover` goes negative, and the totals stop reconciling. The
 * only safe formulation is to apportion the magnitude and negate afterwards,
 * which is exactly what this does.
 */
export function apportionSigned(
  amount: Paise,
  entries: readonly Weighted[],
  isNegative: boolean,
): Share[] {
  const magnitude = toPaise(Math.abs(amount));
  const shares = apportion(magnitude, entries);
  if (!isNegative) return shares;
  return shares.map((s) => ({ id: s.id, share: toPaise(-s.share) }));
}
