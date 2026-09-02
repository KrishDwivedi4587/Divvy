/**
 * Splitting one item across its assignees — roadmap §8 Step 1.
 *
 * Pure. Imports nothing from react, react-native, expo or the store.
 */

import type { ID, Paise } from '@/domain/types';
import { DomainError, toPaise } from './money';

/**
 * Divides an item's line total equally across k assignees, exactly.
 *
 * `base = floor(total / k)`, and the `remainder` leftover paise go one each to
 * the first `remainder` assignees in ascending id order. So ₹100.00 across
 * three people is 3334 / 3333 / 3333 — summing to exactly 10000, with someone
 * paying one extra paisa.
 *
 * Two properties matter and are tested:
 *   - **Exact**: Σ shares === lineTotal, always. No paisa is created or lost.
 *   - **Deterministic**: sorting by id means the same bill always produces the
 *     same answer, which is what makes "why did Aarav pay a paisa more?"
 *     answerable rather than mysterious.
 *
 * An item with no assignees returns an empty map; its value becomes part of the
 * settlement's `unassignedAmount` rather than being silently absorbed by
 * someone.
 */
export function splitItem(lineTotal: Paise, assigneeIds: readonly ID[]): Map<ID, Paise> {
  const shares = new Map<ID, Paise>();

  if (lineTotal < 0) {
    throw new DomainError('NEGATIVE_AMOUNT', `Item line total cannot be negative: ${lineTotal}`);
  }

  const k = assigneeIds.length;
  if (k === 0) return shares;

  const unique = new Set(assigneeIds);
  if (unique.size !== k) {
    throw new DomainError(
      'DUPLICATE_ID',
      `An item cannot be assigned to the same person twice: ${assigneeIds.join(', ')}`,
    );
  }

  const base = Math.floor(lineTotal / k);
  const remainder = lineTotal - base * k; // 0 <= remainder < k

  const ordered = [...assigneeIds].sort(compareIds);
  ordered.forEach((id, index) => {
    shares.set(id, toPaise(index < remainder ? base + 1 : base));
  });

  return shares;
}

/**
 * Total ordering on ids. Extracted so every tie-break in the engine —
 * here and in `apportion` — uses the same rule.
 */
export function compareIds(a: ID, b: ID): number {
  return a < b ? -1 : a > b ? 1 : 0;
}
