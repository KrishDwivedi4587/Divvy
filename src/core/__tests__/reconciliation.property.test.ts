/**
 * The flagship test — roadmap §13.1.
 *
 * Generates 1,000 random bills and asserts the invariant that the whole project
 * rests on:
 *
 *     Σ perPerson.total === grandTotal − unassignedAmount
 *
 * exactly, as integers. Nothing here checks a specific number; it checks that
 * no combination of items, people, assignments, charges and discounts can make
 * a paisa appear or disappear.
 *
 * The generator is seeded, so a failure is reproducible: the seed is printed
 * with the failing case rather than being lost.
 *
 * No property-testing library is used. A seeded LCG and a loop cover this
 * adequately, and adding a dependency to the one module that must be trivially
 * auditable would be a poor trade.
 */

import type { Adjustment, Bill, BillItem, Paise, Person } from '@/domain/types';
import { computeSettlement } from '../settle';

/** Mulberry32 — small, fast, deterministic. */
function makeRng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function generateBill(seed: number): Bill {
  const rng = makeRng(seed);
  const int = (min: number, max: number) => min + Math.floor(rng() * (max - min + 1));

  const peopleCount = int(1, 8);
  const people: Person[] = Array.from({ length: peopleCount }, (_, i) => ({
    id: `person-${String(i).padStart(2, '0')}`,
    name: `Person ${i}`,
    colorIndex: i % 8,
    initials: `P${i}`,
  }));

  const itemCount = int(1, 20);
  const items: BillItem[] = Array.from({ length: itemCount }, (_, i) => {
    // ₹1 – ₹5,000 in paise.
    const lineTotal = int(100, 500000);
    return {
      id: `item-${String(i).padStart(2, '0')}`,
      name: `Item ${i}`,
      quantity: 1,
      unitPrice: lineTotal as Paise,
      lineTotal: lineTotal as Paise,
      source: 'manual' as const,
    };
  });

  const assignments: Record<string, string[]> = {};
  for (const item of items) {
    const roll = rng();
    if (roll < 0.12) {
      assignments[item.id] = []; // deliberately unassigned
    } else if (roll < 0.24) {
      assignments[item.id] = people.map((p) => p.id); // shared by everyone
    } else {
      const count = int(1, peopleCount);
      const shuffled = [...people].sort(() => rng() - 0.5);
      assignments[item.id] = shuffled.slice(0, count).map((p) => p.id);
    }
  }

  const adjustmentCount = int(0, 4);
  const adjustments: Adjustment[] = Array.from({ length: adjustmentCount }, (_, i) => {
    const isPercent = rng() < 0.7;
    const isNegative = rng() < 0.2;
    return {
      id: `adj-${String(i).padStart(2, '0')}`,
      label: `Adjustment ${i}`,
      kind: isNegative ? ('discount' as const) : ('tax' as const),
      mode: isPercent ? ('percent' as const) : ('amount' as const),
      // percent: 0–30%. amount: ₹0–₹500.
      value: isPercent ? int(0, 3000) : int(0, 50000),
      order: i,
      base: rng() < 0.5 ? ('itemsSubtotal' as const) : ('runningTotal' as const),
      isNegative,
    };
  });

  return {
    id: `bill-${seed}`,
    title: `Generated ${seed}`,
    createdAt: '2026-09-01T00:00:00.000Z',
    people,
    items,
    assignments,
    adjustments,
  };
}

describe('reconciliation invariant', () => {
  const CASES = 1000;

  it(`holds for ${CASES} randomly generated bills`, () => {
    for (let seed = 1; seed <= CASES; seed++) {
      const bill = generateBill(seed);
      const s = computeSettlement(bill);

      const sumOfPeople = s.perPerson.reduce((a, x) => a + x.total, 0);
      const expected = s.grandTotal - s.unassignedAmount;

      if (sumOfPeople !== expected || !s.reconciles) {
        throw new Error(
          `RECONCILIATION FAILED at seed ${seed}\n` +
            `  Σ perPerson.total = ${sumOfPeople}\n` +
            `  grandTotal        = ${s.grandTotal}\n` +
            `  unassignedAmount  = ${s.unassignedAmount}\n` +
            `  expected          = ${expected}\n` +
            `  reconciles flag   = ${s.reconciles}`,
        );
      }

      expect(sumOfPeople).toBe(expected);
      expect(s.reconciles).toBe(true);
    }
  });

  it(`produces only finite whole numbers across ${CASES} bills`, () => {
    for (let seed = 1; seed <= CASES; seed++) {
      const s = computeSettlement(generateBill(seed));

      const numbers: number[] = [
        s.itemsSubtotal,
        s.grandTotal,
        s.unassignedAmount,
        ...s.adjustmentTotals.map((a) => a.amount),
      ];
      for (const person of s.perPerson) {
        numbers.push(person.subtotal, person.total);
        numbers.push(...person.itemShares.map((i) => i.share));
        numbers.push(...person.adjustmentShares.map((a) => a.share));
      }

      for (const n of numbers) {
        if (!Number.isInteger(n) || !Number.isFinite(n)) {
          throw new Error(`Non-integer or non-finite value ${n} at seed ${seed}`);
        }
      }
    }
  });

  it('per-item shares always sum to the item line total', () => {
    for (let seed = 1; seed <= 200; seed++) {
      const bill = generateBill(seed);
      const s = computeSettlement(bill);

      const perItem = new Map<string, number>();
      for (const person of s.perPerson) {
        for (const share of person.itemShares) {
          perItem.set(share.itemId, (perItem.get(share.itemId) ?? 0) + share.share);
        }
      }

      for (const item of bill.items) {
        const assigned = bill.assignments[item.id] ?? [];
        const allocated = perItem.get(item.id) ?? 0;
        const expected = assigned.length === 0 ? 0 : item.lineTotal;
        expect(allocated).toBe(expected);
      }
    }
  });

  it('each adjustment total equals the sum of its per-person shares', () => {
    for (let seed = 1; seed <= 200; seed++) {
      const s = computeSettlement(generateBill(seed));

      for (const adjustment of s.adjustmentTotals) {
        const distributed = s.perPerson.reduce(
          (sum, person) =>
            sum +
            person.adjustmentShares
              .filter((a) => a.adjustmentId === adjustment.adjustmentId)
              .reduce((x, a) => x + a.share, 0),
          0,
        );
        expect(distributed).toBe(adjustment.amount);
      }
    }
  });

  it('is deterministic: the same seed always produces the same settlement', () => {
    for (const seed of [1, 42, 500, 999]) {
      const first = JSON.stringify(computeSettlement(generateBill(seed)));
      const second = JSON.stringify(computeSettlement(generateBill(seed)));
      expect(second).toBe(first);
    }
  });
});
