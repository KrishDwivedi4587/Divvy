/**
 * Full settlement — roadmap §8 Step 4.
 *
 * `computeSettlement` is the engine's single entry point. It takes a plain
 * `Bill` and returns a plain `Settlement`; it knows nothing about React, the
 * store, or the database, which is what lets the whole money model be proven on
 * a laptop with no device.
 *
 * Settlements are always recomputed and never persisted (D9): stored totals can
 * go stale, derived ones cannot.
 */

import type {
  Adjustment,
  AdjustmentShare,
  Bill,
  ID,
  ItemShare,
  Paise,
  PersonSettlement,
  Settlement,
} from '@/domain/types';
import { apportionSigned, type Weighted } from './apportion';
import { DomainError, percentOf, toPaise } from './money';
import { compareIds, splitItem } from './splitItem';

/**
 * Computes every person's share of a bill.
 *
 * Order of operations follows a real Indian restaurant bill (D6): items, then
 * adjustments in their explicit `order`, each applied to either the items
 * subtotal or the running total. That is why GST-on-(items + service charge)
 * comes out right rather than approximately right.
 *
 * @throws DomainError if the bill is structurally invalid.
 */
export function computeSettlement(bill: Bill): Settlement {
  validate(bill);

  const people = [...bill.people].sort((a, b) => compareIds(a.id, b.id));

  /* 1 — items subtotal: ALL items, assigned or not. */
  const itemsSubtotal = toPaise(bill.items.reduce((sum, item) => sum + item.lineTotal, 0));

  /* 2/3 — split each item, accumulate per-person subtotals. */
  const itemSharesByPerson = new Map<ID, ItemShare[]>();
  for (const p of people) itemSharesByPerson.set(p.id, []);

  const unassignedItemIds: ID[] = [];
  let unassignedAmount = 0;

  for (const item of bill.items) {
    const assignees = bill.assignments[item.id] ?? [];

    if (assignees.length === 0) {
      unassignedItemIds.push(item.id);
      unassignedAmount += item.lineTotal;
      continue;
    }

    const shares = splitItem(item.lineTotal, assignees);
    for (const [personId, share] of shares) {
      itemSharesByPerson.get(personId)?.push({
        itemId: item.id,
        share,
        assigneeCount: assignees.length,
      });
    }
  }

  const subtotals = new Map<ID, number>();
  for (const p of people) {
    const shares = itemSharesByPerson.get(p.id) ?? [];
    subtotals.set(
      p.id,
      shares.reduce((sum, s) => sum + s.share, 0),
    );
  }

  /* 5 — adjustments, in order, each apportioned across the running base. */
  const runningBase = new Map<ID, number>(subtotals);
  const adjustmentSharesByPerson = new Map<ID, AdjustmentShare[]>();
  for (const p of people) adjustmentSharesByPerson.set(p.id, []);

  const adjustmentTotals: { adjustmentId: ID; amount: Paise }[] = [];

  const ordered = [...bill.adjustments].sort((a, b) => a.order - b.order || compareIds(a.id, b.id));

  for (const adj of ordered) {
    const runningSum = sumValues(runningBase);
    const pool = adj.base === 'itemsSubtotal' ? itemsSubtotal : toPaise(runningSum);

    const magnitude = amountFor(adj, pool);
    const signed = adj.isNegative ? -magnitude : magnitude;
    adjustmentTotals.push({ adjustmentId: adj.id, amount: toPaise(signed) });

    // Weights are clamped at zero. A large discount can push someone's running
    // base negative (their discount share exceeded their subtotal), and a
    // proportional share of a *negative* weight is meaningless — it would hand
    // that person a negative slice of a positive charge. Clamping means such a
    // person simply receives none of the next proportional adjustment.
    //
    // This does not weaken the invariant: apportion still distributes the
    // amount exactly across whatever weights it is given, and if every weight
    // clamps to zero it falls back to an equal split.
    const weights: Weighted[] = people.map((p) => ({
      id: p.id,
      weight: Math.max(0, runningBase.get(p.id) ?? 0),
    }));

    const shares = apportionSigned(magnitude, weights, adj.isNegative);
    for (const s of shares) {
      adjustmentSharesByPerson.get(s.id)?.push({ adjustmentId: adj.id, share: s.share });
      runningBase.set(s.id, (runningBase.get(s.id) ?? 0) + s.share);
    }
  }

  /* 6 — per-person totals. */
  const perPerson: PersonSettlement[] = people.map((p) => {
    const itemShares = itemSharesByPerson.get(p.id) ?? [];
    const adjustmentShares = adjustmentSharesByPerson.get(p.id) ?? [];
    const subtotal = subtotals.get(p.id) ?? 0;
    const total = subtotal + adjustmentShares.reduce((sum, a) => sum + a.share, 0);

    return {
      personId: p.id,
      itemShares,
      subtotal: toPaise(subtotal),
      adjustmentShares,
      total: toPaise(total),
    };
  });

  /* 7/8 — grand total and the invariant. */
  const grandTotal = toPaise(
    itemsSubtotal + adjustmentTotals.reduce((sum, a) => sum + a.amount, 0),
  );
  const sumOfPeople = perPerson.reduce((sum, p) => sum + p.total, 0);
  const reconciles = sumOfPeople === grandTotal - unassignedAmount;

  return {
    perPerson,
    itemsSubtotal,
    adjustmentTotals,
    grandTotal,
    unassignedItemIds,
    unassignedAmount: toPaise(unassignedAmount),
    reconciles,
  };
}

/** Percentage adjustments round once, here, and nowhere else. */
function amountFor(adj: Adjustment, pool: Paise): Paise {
  if (adj.mode === 'amount') return toPaise(Math.abs(adj.value));
  return percentOf(toPaise(Math.abs(pool)), Math.abs(adj.value));
}

function sumValues(map: Map<ID, number>): number {
  let total = 0;
  for (const v of map.values()) total += v;
  return total;
}

/**
 * Rejects structurally invalid bills loudly rather than returning plausible but
 * wrong money. Every check here corresponds to a bug that would otherwise be
 * invisible in the totals.
 */
function validate(bill: Bill): void {
  if (bill.people.length === 0) {
    throw new DomainError('NO_PEOPLE', 'A bill must have at least one person to settle');
  }

  const personIds = new Set<ID>();
  for (const p of bill.people) {
    if (personIds.has(p.id)) {
      throw new DomainError('DUPLICATE_ID', `Duplicate person id: ${p.id}`);
    }
    personIds.add(p.id);
  }

  const itemIds = new Set<ID>();
  for (const item of bill.items) {
    if (itemIds.has(item.id)) {
      throw new DomainError('DUPLICATE_ID', `Duplicate item id: ${item.id}`);
    }
    itemIds.add(item.id);

    if (item.lineTotal < 0) {
      throw new DomainError(
        'NEGATIVE_AMOUNT',
        `Item ${item.id} has a negative line total: ${item.lineTotal}`,
      );
    }
    if (!Number.isInteger(item.lineTotal)) {
      throw new DomainError('NOT_AN_INTEGER', `Item ${item.id} line total must be whole paise`);
    }
    if (!Number.isInteger(item.quantity) || item.quantity < 1) {
      throw new DomainError(
        'INVALID_QUANTITY',
        `Item ${item.id} quantity must be an integer >= 1, got ${item.quantity}`,
      );
    }
  }

  for (const [itemId, assignees] of Object.entries(bill.assignments)) {
    if (!itemIds.has(itemId)) {
      throw new DomainError('UNKNOWN_ITEM', `Assignment refers to unknown item: ${itemId}`);
    }
    for (const personId of assignees) {
      if (!personIds.has(personId)) {
        throw new DomainError(
          'UNKNOWN_PERSON',
          `Item ${itemId} is assigned to unknown person: ${personId}`,
        );
      }
    }
  }

  const adjustmentIds = new Set<ID>();
  for (const adj of bill.adjustments) {
    if (adjustmentIds.has(adj.id)) {
      throw new DomainError('DUPLICATE_ID', `Duplicate adjustment id: ${adj.id}`);
    }
    adjustmentIds.add(adj.id);

    if (!Number.isInteger(adj.value)) {
      throw new DomainError(
        'INVALID_BASIS_POINTS',
        `Adjustment ${adj.id} value must be an integer (basis points or paise)`,
      );
    }
  }
}
