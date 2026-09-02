import type { Adjustment, Bill, BillItem, ID, Paise, Person } from '@/domain/types';
import { DomainError } from '../money';
import { computeSettlement } from '../settle';

const p = (n: number) => n as Paise;

function person(id: ID, name = id): Person {
  return { id, name, colorIndex: 0, initials: name.slice(0, 2).toUpperCase() };
}

function item(id: ID, name: string, lineTotal: number, quantity = 1): BillItem {
  return {
    id,
    name,
    quantity,
    unitPrice: p(Math.floor(lineTotal / quantity)),
    lineTotal: p(lineTotal),
    source: 'manual',
  };
}

function bill(partial: Partial<Bill>): Bill {
  return {
    id: 'bill-1',
    title: 'Test bill',
    createdAt: '2026-09-01T00:00:00.000Z',
    people: [],
    items: [],
    assignments: {},
    adjustments: [],
    ...partial,
  };
}

const totalOf = (s: { perPerson: { total: Paise }[] }) =>
  s.perPerson.reduce((a, x) => a + x.total, 0);

const byId = (s: ReturnType<typeof computeSettlement>) =>
  Object.fromEntries(s.perPerson.map((x) => [x.personId, x]));

/* ------------------------------------------------------------------ *
 * Golden case — the roadmap §8 worked example                         *
 * ------------------------------------------------------------------ */

describe('golden case: roadmap §8 worked example', () => {
  const goldenBill = bill({
    people: [person('aarav', 'Aarav'), person('priya', 'Priya'), person('zoya', 'Zoya')],
    items: [
      item('paneer', 'Paneer Tikka', 34000),
      item('dal', 'Dal Makhani', 28000),
      item('coffee', 'Cold Coffee', 15000),
      item('naan', 'Naan', 16000, 4),
    ],
    assignments: {
      paneer: ['aarav', 'priya'],
      dal: ['aarav', 'priya', 'zoya'],
      coffee: ['zoya'],
      naan: ['aarav', 'priya', 'zoya'],
    },
    adjustments: [
      {
        id: 'service',
        label: 'Service Charge',
        kind: 'service',
        mode: 'percent',
        value: 500,
        order: 1,
        base: 'itemsSubtotal',
        isNegative: false,
      },
      {
        id: 'gst',
        label: 'GST',
        kind: 'tax',
        mode: 'percent',
        value: 500,
        order: 2,
        base: 'runningTotal',
        isNegative: false,
      },
    ],
  });

  const settlement = computeSettlement(goldenBill);
  const people = byId(settlement);

  it('items subtotal is ₹930.00', () => {
    expect(settlement.itemsSubtotal).toBe(93000);
  });

  it('per-person subtotals match the worked example', () => {
    expect(people.aarav.subtotal).toBe(31668);
    expect(people.priya.subtotal).toBe(31666);
    expect(people.zoya.subtotal).toBe(29666);
  });

  it('subtotals sum to the items subtotal exactly', () => {
    const sum = settlement.perPerson.reduce((a, x) => a + x.subtotal, 0);
    expect(sum).toBe(93000);
  });

  it('service charge is 5% of items = ₹46.50, split 1584/1583/1483', () => {
    const service = settlement.adjustmentTotals.find((a) => a.adjustmentId === 'service');
    expect(service?.amount).toBe(4650);
    expect(people.aarav.adjustmentShares[0].share).toBe(1584);
    expect(people.priya.adjustmentShares[0].share).toBe(1583);
    expect(people.zoya.adjustmentShares[0].share).toBe(1483);
  });

  it('GST is 5% of (items + service) = 4882.5 rounded to ₹48.83', () => {
    const gst = settlement.adjustmentTotals.find((a) => a.adjustmentId === 'gst');
    expect(gst?.amount).toBe(4883);
    expect(people.aarav.adjustmentShares[1].share).toBe(1663);
    expect(people.priya.adjustmentShares[1].share).toBe(1663);
    expect(people.zoya.adjustmentShares[1].share).toBe(1557);
  });

  it('final per-person totals are ₹349.15 / ₹349.12 / ₹327.06', () => {
    expect(people.aarav.total).toBe(34915);
    expect(people.priya.total).toBe(34912);
    expect(people.zoya.total).toBe(32706);
  });

  it('grand total is ₹1,025.33 and everyone sums to it exactly', () => {
    expect(settlement.grandTotal).toBe(102533);
    expect(totalOf(settlement)).toBe(102533);
    expect(settlement.reconciles).toBe(true);
  });

  it('nothing is unassigned', () => {
    expect(settlement.unassignedItemIds).toEqual([]);
    expect(settlement.unassignedAmount).toBe(0);
  });
});

/* ------------------------------------------------------------------ *
 * Adjustment ordering and semantics                                   *
 * ------------------------------------------------------------------ */

describe('adjustment ordering', () => {
  const base = {
    people: [person('a'), person('b')],
    items: [item('i1', 'Item', 100000)],
    assignments: { i1: ['a', 'b'] },
  };

  const service = (order: number): Adjustment => ({
    id: 'service',
    label: 'Service',
    kind: 'service',
    mode: 'percent',
    value: 1000, // 10%
    order,
    base: 'itemsSubtotal',
    isNegative: false,
  });

  const gst = (order: number): Adjustment => ({
    id: 'gst',
    label: 'GST',
    kind: 'tax',
    mode: 'percent',
    value: 500, // 5%
    order,
    base: 'runningTotal',
    isNegative: false,
  });

  it('service-then-GST differs from GST-then-service, and both reconcile', () => {
    const serviceFirst = computeSettlement(bill({ ...base, adjustments: [service(1), gst(2)] }));
    const gstFirst = computeSettlement(bill({ ...base, adjustments: [gst(1), service(2)] }));

    // Service first: GST is charged on 110000 -> 5500. Grand 115500.
    expect(serviceFirst.grandTotal).toBe(115500);
    // GST first: GST charged on 100000 -> 5000. Grand 115000.
    expect(gstFirst.grandTotal).toBe(115000);

    expect(serviceFirst.grandTotal).not.toBe(gstFirst.grandTotal);
    expect(serviceFirst.reconciles).toBe(true);
    expect(gstFirst.reconciles).toBe(true);
  });

  it('percent mode and amount mode agree when the amounts match', () => {
    const asPercent = computeSettlement(bill({ ...base, adjustments: [service(1)] }));
    const asAmount = computeSettlement(
      bill({
        ...base,
        adjustments: [{ ...service(1), mode: 'amount', value: 10000 }],
      }),
    );
    expect(asAmount.grandTotal).toBe(asPercent.grandTotal);
    expect(byId(asAmount).a.total).toBe(byId(asPercent).a.total);
  });

  it('applies adjustments in `order`, not array position', () => {
    const shuffled = computeSettlement(bill({ ...base, adjustments: [gst(2), service(1)] }));
    expect(shuffled.grandTotal).toBe(115500);
  });

  it('a zero-rate adjustment changes nothing', () => {
    const zero = computeSettlement(bill({ ...base, adjustments: [{ ...service(1), value: 0 }] }));
    expect(zero.grandTotal).toBe(100000);
    expect(zero.reconciles).toBe(true);
  });
});

/* ------------------------------------------------------------------ *
 * Discounts                                                           *
 * ------------------------------------------------------------------ */

describe('discounts', () => {
  const discountBill = (value: number, mode: 'percent' | 'amount' = 'percent') =>
    bill({
      people: [person('a'), person('b'), person('c')],
      items: [item('i1', 'Item', 30000)],
      assignments: { i1: ['a', 'b', 'c'] },
      adjustments: [
        {
          id: 'disc',
          label: 'Discount',
          kind: 'discount',
          mode,
          value,
          order: 1,
          base: 'itemsSubtotal',
          isNegative: true,
        },
      ],
    });

  it('reduces the grand total and still reconciles', () => {
    const s = computeSettlement(discountBill(1000)); // 10%
    expect(s.adjustmentTotals[0].amount).toBe(-3000);
    expect(s.grandTotal).toBe(27000);
    expect(totalOf(s)).toBe(27000);
    expect(s.reconciles).toBe(true);
  });

  it('reduces every person share', () => {
    const s = computeSettlement(discountBill(1000));
    for (const person of s.perPerson) {
      expect(person.adjustmentShares[0].share).toBeLessThan(0);
      expect(person.total).toBeLessThan(person.subtotal);
    }
  });

  it('handles a 100% discount down to zero', () => {
    const s = computeSettlement(discountBill(10000));
    expect(s.grandTotal).toBe(0);
    expect(totalOf(s)).toBe(0);
    expect(s.reconciles).toBe(true);
  });

  it('handles a 0% discount', () => {
    const s = computeSettlement(discountBill(0));
    expect(s.grandTotal).toBe(30000);
    expect(s.reconciles).toBe(true);
  });

  it('reconciles a fixed-amount discount that does not divide evenly', () => {
    const s = computeSettlement(discountBill(1000, 'amount'));
    expect(s.adjustmentTotals[0].amount).toBe(-1000);
    expect(totalOf(s)).toBe(29000);
    expect(s.reconciles).toBe(true);
  });

  it('regression: a discount that drives a running base negative does not throw', () => {
    // Found by the property test at seed 110. A discount larger than a person's
    // subtotal pushes their running base below zero; the next proportional
    // adjustment then received a negative weight and threw. Weights are now
    // clamped at zero, so that person simply receives none of the later charge.
    const s = computeSettlement(
      bill({
        people: [person('rich'), person('poor')],
        items: [item('big', 'Big', 100000), item('tiny', 'Tiny', 100)],
        assignments: { big: ['rich'], tiny: ['poor'] },
        adjustments: [
          {
            id: 'disc',
            label: 'Flat discount',
            kind: 'discount',
            mode: 'amount',
            value: 50000,
            order: 1,
            base: 'itemsSubtotal',
            isNegative: true,
          },
          {
            id: 'gst',
            label: 'GST',
            kind: 'tax',
            mode: 'percent',
            value: 1800,
            order: 2,
            base: 'runningTotal',
            isNegative: false,
          },
        ],
      }),
    );
    expect(s.reconciles).toBe(true);
    expect(totalOf(s)).toBe(s.grandTotal - s.unassignedAmount);
  });

  it('combines a discount with a tax and still reconciles', () => {
    const s = computeSettlement(
      bill({
        people: [person('a'), person('b')],
        items: [item('i1', 'Item', 99999)],
        assignments: { i1: ['a', 'b'] },
        adjustments: [
          {
            id: 'disc',
            label: 'Discount',
            kind: 'discount',
            mode: 'percent',
            value: 1234,
            order: 1,
            base: 'itemsSubtotal',
            isNegative: true,
          },
          {
            id: 'gst',
            label: 'GST',
            kind: 'tax',
            mode: 'percent',
            value: 1800,
            order: 2,
            base: 'runningTotal',
            isNegative: false,
          },
        ],
      }),
    );
    expect(s.reconciles).toBe(true);
    expect(totalOf(s)).toBe(s.grandTotal);
  });
});

/* ------------------------------------------------------------------ *
 * Unassigned items                                                    *
 * ------------------------------------------------------------------ */

describe('unassigned items', () => {
  const s = computeSettlement(
    bill({
      people: [person('a'), person('b')],
      items: [item('assigned', 'Assigned', 20000), item('orphan', 'Orphan', 5000)],
      assignments: { assigned: ['a', 'b'], orphan: [] },
    }),
  );

  it('counts unassigned items in itemsSubtotal but not in anyone subtotal', () => {
    expect(s.itemsSubtotal).toBe(25000);
    expect(s.perPerson.reduce((a, x) => a + x.subtotal, 0)).toBe(20000);
  });

  it('reports the unassigned amount and ids', () => {
    expect(s.unassignedAmount).toBe(5000);
    expect(s.unassignedItemIds).toEqual(['orphan']);
  });

  it('reconciles against grandTotal minus the unassigned amount', () => {
    expect(totalOf(s)).toBe(s.grandTotal - s.unassignedAmount);
    expect(s.reconciles).toBe(true);
  });

  it('an item missing from the assignments map counts as unassigned', () => {
    const missing = computeSettlement(
      bill({
        people: [person('a')],
        items: [item('i1', 'Item', 1000)],
        assignments: {},
      }),
    );
    expect(missing.unassignedAmount).toBe(1000);
    expect(missing.reconciles).toBe(true);
  });

  it('charges still apportion when every item is unassigned', () => {
    const allOrphaned = computeSettlement(
      bill({
        people: [person('a'), person('b')],
        items: [item('i1', 'Item', 10000)],
        assignments: { i1: [] },
        adjustments: [
          {
            id: 'gst',
            label: 'GST',
            kind: 'tax',
            mode: 'percent',
            value: 500,
            order: 1,
            base: 'itemsSubtotal',
            isNegative: false,
          },
        ],
      }),
    );
    // Nobody has a subtotal, so the charge splits equally rather than vanishing.
    expect(allOrphaned.adjustmentTotals[0].amount).toBe(500);
    expect(totalOf(allOrphaned)).toBe(500);
    expect(allOrphaned.reconciles).toBe(true);
  });
});

/* ------------------------------------------------------------------ *
 * Shape and edge cases                                                *
 * ------------------------------------------------------------------ */

describe('edge cases', () => {
  it('handles a single person with a single item', () => {
    const s = computeSettlement(
      bill({
        people: [person('solo')],
        items: [item('i1', 'Item', 12345)],
        assignments: { i1: ['solo'] },
      }),
    );
    expect(s.perPerson[0].total).toBe(12345);
    expect(s.reconciles).toBe(true);
  });

  it('handles a person with no items assigned', () => {
    const s = computeSettlement(
      bill({
        people: [person('a'), person('idle')],
        items: [item('i1', 'Item', 10000)],
        assignments: { i1: ['a'] },
      }),
    );
    expect(byId(s).idle.subtotal).toBe(0);
    expect(byId(s).idle.total).toBe(0);
    expect(s.reconciles).toBe(true);
  });

  it('handles a bill with no items', () => {
    const s = computeSettlement(bill({ people: [person('a')] }));
    expect(s.itemsSubtotal).toBe(0);
    expect(s.grandTotal).toBe(0);
    expect(s.reconciles).toBe(true);
  });

  it('handles a zero-priced item', () => {
    const s = computeSettlement(
      bill({
        people: [person('a'), person('b')],
        items: [item('free', 'Complimentary', 0)],
        assignments: { free: ['a', 'b'] },
      }),
    );
    expect(s.grandTotal).toBe(0);
    expect(s.reconciles).toBe(true);
  });

  it('handles eight people sharing one item', () => {
    const ids = Array.from({ length: 8 }, (_, i) => `p${i}`);
    const s = computeSettlement(
      bill({
        people: ids.map((id) => person(id)),
        items: [item('i1', 'Item', 10000)],
        assignments: { i1: ids },
      }),
    );
    expect(totalOf(s)).toBe(10000);
    expect(s.reconciles).toBe(true);
  });

  it('is deterministic across repeated runs', () => {
    const b = bill({
      people: [person('c'), person('a'), person('b')],
      items: [item('i1', 'Item', 10001)],
      assignments: { i1: ['c', 'a', 'b'] },
    });
    const first = JSON.stringify(computeSettlement(b));
    for (let i = 0; i < 50; i++) {
      expect(JSON.stringify(computeSettlement(b))).toBe(first);
    }
  });
});

/* ------------------------------------------------------------------ *
 * Validation                                                          *
 * ------------------------------------------------------------------ */

describe('validation', () => {
  it.each([
    ['no people', () => bill({ items: [item('i1', 'x', 100)] }), 'NO_PEOPLE'],
    ['duplicate person ids', () => bill({ people: [person('a'), person('a')] }), 'DUPLICATE_ID'],
    [
      'duplicate item ids',
      () =>
        bill({
          people: [person('a')],
          items: [item('dup', 'x', 100), item('dup', 'y', 200)],
        }),
      'DUPLICATE_ID',
    ],
    [
      'unknown person in an assignment',
      () =>
        bill({
          people: [person('a')],
          items: [item('i1', 'x', 100)],
          assignments: { i1: ['ghost'] },
        }),
      'UNKNOWN_PERSON',
    ],
    [
      'unknown item in an assignment',
      () =>
        bill({
          people: [person('a')],
          items: [item('i1', 'x', 100)],
          assignments: { nonexistent: ['a'] },
        }),
      'UNKNOWN_ITEM',
    ],
    [
      'negative line total',
      () =>
        bill({
          people: [person('a')],
          items: [item('i1', 'x', -100)],
        }),
      'NEGATIVE_AMOUNT',
    ],
    [
      'zero quantity',
      () =>
        bill({
          people: [person('a')],
          items: [{ ...item('i1', 'x', 100), quantity: 0 }],
        }),
      'INVALID_QUANTITY',
    ],
    [
      'fractional line total',
      () =>
        bill({
          people: [person('a')],
          items: [{ ...item('i1', 'x', 100), lineTotal: 10.5 as Paise }],
        }),
      'NOT_AN_INTEGER',
    ],
  ])('rejects %s', (_label, make, code) => {
    expect(() => computeSettlement(make())).toThrow(DomainError);
    try {
      computeSettlement(make());
    } catch (e) {
      expect((e as DomainError).code).toBe(code);
    }
  });

  it('rejects an item assigned to the same person twice', () => {
    expect(() =>
      computeSettlement(
        bill({
          people: [person('a')],
          items: [item('i1', 'x', 100)],
          assignments: { i1: ['a', 'a'] },
        }),
      ),
    ).toThrow(DomainError);
  });
});
