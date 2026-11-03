import {
  buildBill,
  DEFAULT_TITLE,
  EMPTY_DRAFT,
  hasErrors,
  MAX_AMOUNT_PAISE,
  type BillDraft,
  type PersonInput,
} from '../buildBill';
import { computeSettlement } from '../settle';

const NOW = '2026-11-03T12:00:00.000Z';

const people = (...names: string[]): PersonInput[] =>
  names.map((name, i) => ({
    id: `person-${String(i + 1).padStart(2, '0')}`,
    name,
    colorIndex: i,
  }));

const draft = (patch: Partial<BillDraft> = {}): BillDraft => ({ ...EMPTY_DRAFT, ...patch });

/** Builds and settles, failing loudly if either step does not succeed. */
function settle(d: BillDraft, p: PersonInput[]) {
  const built = buildBill({ draft: d, people: p, now: NOW });
  if (!built.ok) throw new Error(`buildBill failed: ${JSON.stringify(built.errors)}`);
  return { bill: built.bill, settlement: computeSettlement(built.bill) };
}

describe('buildBill → computeSettlement (engine integration)', () => {
  it('splits a bare amount equally and exactly: ₹100.00 across 3 → 3334/3333/3333', () => {
    const { settlement } = settle(draft({ amountText: '100' }), people('A', 'B', 'C'));

    expect(settlement.itemsSubtotal).toBe(10000);
    expect(settlement.grandTotal).toBe(10000);
    expect(settlement.perPerson.map((p) => p.total)).toEqual([3334, 3333, 3333]);
    expect(settlement.reconciles).toBe(true);
  });

  it('applies tax, tip and a service charge in the documented order', () => {
    // ₹1,000 subtotal; service 10% of subtotal = 10,000; tax 5% of
    // (subtotal + service) = 5,500; tip flat ₹50 = 5,000. Total 120,500.
    const { settlement } = settle(
      draft({
        amountText: '1000',
        tax: { text: '5', mode: 'percent' },
        tip: { text: '50', mode: 'amount' },
        charges: [{ id: 'charge-1', label: 'Service charge', text: '10', mode: 'percent' }],
      }),
      people('You', 'Priya'),
    );

    const totals = Object.fromEntries(
      settlement.adjustmentTotals.map((a) => [a.adjustmentId, a.amount]),
    );
    expect(totals['charge-1']).toBe(10000);
    expect(totals.tax).toBe(5500); // on 110,000, not on 100,000
    expect(totals.tip).toBe(5000);
    expect(settlement.grandTotal).toBe(120500);
    expect(settlement.perPerson.map((p) => p.total)).toEqual([60250, 60250]);
    expect(settlement.reconciles).toBe(true);
  });

  it('puts tax on subtotal + charges, not on the subtotal alone', () => {
    const withCharge = settle(
      draft({
        amountText: '1000',
        tax: { text: '10', mode: 'percent' },
        charges: [{ id: 'charge-1', label: 'Packaging', text: '100', mode: 'amount' }],
      }),
      people('A', 'B'),
    );
    const totals = Object.fromEntries(
      withCharge.settlement.adjustmentTotals.map((a) => [a.adjustmentId, a.amount]),
    );
    // 10% of (1000 + 100) = 110, not 10% of 1000 = 100.
    expect(totals.tax).toBe(11000);
  });

  it('allocates a rounding remainder deterministically: ₹100 with 5% tax across 3', () => {
    // Worked by hand. Subtotals 3334/3333/3333; tax 500 apportioned:
    //   floors 166/166/166 (Σ 498), leftover 2 → largest remainders:
    //   person-01 (7000), then a 6500 tie broken by id → person-02.
    //   shares 167/167/166.
    const { settlement } = settle(
      draft({ amountText: '100', tax: { text: '5', mode: 'percent' } }),
      people('A', 'B', 'C'),
    );
    expect(settlement.perPerson.map((p) => p.total)).toEqual([3501, 3500, 3499]);
    expect(settlement.grandTotal).toBe(10500);
    expect(settlement.reconciles).toBe(true);
  });

  it('handles a tax that does not land on a whole paisa', () => {
    // 18% of ₹333.33 = 5999.94 paise → rounds half-away to 6000.
    const { settlement } = settle(
      draft({ amountText: '333.33', tax: { text: '18', mode: 'percent' } }),
      people('A', 'B', 'C'),
    );
    expect(settlement.adjustmentTotals[0].amount).toBe(6000);
    expect(settlement.grandTotal).toBe(39333);
    expect(settlement.perPerson.map((p) => p.total)).toEqual([13111, 13111, 13111]);
  });

  it('works with a single person', () => {
    const { settlement } = settle(draft({ amountText: '250.75' }), people('Solo'));
    expect(settlement.perPerson[0].total).toBe(25075);
  });

  it('reconciles for every group size from 1 to 8', () => {
    const names = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    for (let n = 1; n <= 8; n++) {
      const { settlement } = settle(
        draft({
          amountText: '1234.57',
          tax: { text: '5', mode: 'percent' },
          tip: { text: '7.5', mode: 'percent' },
          charges: [{ id: 'charge-1', label: 'Service', text: '12.5', mode: 'percent' }],
        }),
        people(...names.slice(0, n)),
      );
      const sum = settlement.perPerson.reduce((a, p) => a + p.total, 0);
      expect(sum).toBe(settlement.grandTotal);
      expect(settlement.reconciles).toBe(true);
    }
  });

  it('reconciles across many random drafts', () => {
    const rnd = (max: number) => Math.floor(Math.random() * max);
    for (let i = 0; i < 500; i++) {
      const n = 1 + rnd(8);
      const names = Array.from({ length: n }, (_, k) => `P${k}`);
      const { settlement } = settle(
        draft({
          amountText: `${1 + rnd(99999)}.${String(rnd(100)).padStart(2, '0')}`,
          tax: { text: `${rnd(30)}.${rnd(100)}`, mode: 'percent' },
          tip: rnd(2)
            ? { text: `${rnd(500)}`, mode: 'amount' }
            : { text: `${rnd(25)}`, mode: 'percent' },
          charges: Array.from({ length: rnd(4) }, (_, k) => ({
            id: `charge-${k + 1}`,
            label: `Charge ${k + 1}`,
            text: `${1 + rnd(20)}`,
            mode: 'percent' as const,
          })),
        }),
        people(...names),
      );
      expect(settlement.perPerson.reduce((a, p) => a + p.total, 0)).toBe(settlement.grandTotal);
      expect(settlement.reconciles).toBe(true);
    }
  });
});

describe('buildBill — output shape', () => {
  it('assigns the single bill item to every participant', () => {
    const built = buildBill({
      draft: draft({ amountText: '10' }),
      people: people('A', 'B'),
      now: NOW,
    });
    expect(built.ok).toBe(true);
    if (!built.ok) return;
    expect(built.bill.items).toHaveLength(1);
    expect(built.bill.assignments['item-bill']).toEqual(['person-01', 'person-02']);
  });

  it('derives initials and carries the colour index', () => {
    const built = buildBill({
      draft: draft({ amountText: '10' }),
      people: people('Raj Patel'),
      now: NOW,
    });
    expect(built.ok && built.bill.people[0]).toMatchObject({ initials: 'RP', colorIndex: 0 });
  });

  it('falls back to a default title', () => {
    const built = buildBill({ draft: draft({ amountText: '10' }), people: people('A'), now: NOW });
    expect(built.ok && built.bill.title).toBe(DEFAULT_TITLE);
  });

  it('uses and trims the entered name', () => {
    const built = buildBill({
      draft: draft({ name: '  Dinner at Toscana ', amountText: '10' }),
      people: people('A'),
      now: NOW,
    });
    expect(built.ok && built.bill.title).toBe('Dinner at Toscana');
  });

  it('omits adjustments for blank or zero tax and tip', () => {
    const built = buildBill({
      draft: draft({
        amountText: '10',
        tax: { text: '', mode: 'percent' },
        tip: { text: '0', mode: 'amount' },
      }),
      people: people('A'),
      now: NOW,
    });
    expect(built.ok && built.bill.adjustments).toEqual([]);
  });

  it('carries the photo uri through, and omits it when absent', () => {
    const withPhoto = buildBill({
      draft: draft({ amountText: '10' }),
      people: people('A'),
      photoUri: 'file:///x.jpg',
      now: NOW,
    });
    const without = buildBill({
      draft: draft({ amountText: '10' }),
      people: people('A'),
      now: NOW,
    });
    expect(withPhoto.ok && withPhoto.bill.receiptImageUri).toBe('file:///x.jpg');
    expect(without.ok && 'receiptImageUri' in without.bill).toBe(false);
  });

  it('tolerates a trailing decimal point while typing', () => {
    const { settlement } = settle(draft({ amountText: '340.' }), people('A'));
    expect(settlement.grandTotal).toBe(34000);
  });

  it('labels a charge containing "service" as a service charge', () => {
    const built = buildBill({
      draft: draft({
        amountText: '10',
        charges: [{ id: 'charge-1', label: 'Service Charge', text: '5', mode: 'percent' }],
      }),
      people: people('A'),
      now: NOW,
    });
    expect(built.ok && built.bill.adjustments[0].kind).toBe('service');
  });

  it('gives an unnamed charge a readable label', () => {
    const built = buildBill({
      draft: draft({
        amountText: '10',
        charges: [{ id: 'charge-1', label: '  ', text: '5', mode: 'amount' }],
      }),
      people: people('A'),
      now: NOW,
    });
    expect(built.ok && built.bill.adjustments[0].label).toBe('Extra charge');
  });
});

describe('buildBill — validation', () => {
  const fails = (d: BillDraft, p = people('A', 'B')) => {
    const r = buildBill({ draft: d, people: p, now: NOW });
    if (r.ok) throw new Error('expected validation to fail');
    return r.errors;
  };

  it('requires an amount', () => {
    expect(fails(draft()).amount).toBe('Enter the bill amount');
  });

  it.each([
    ['abc', 'Enter a valid amount'],
    ['12.345', 'Use at most 2 decimal places'],
    ['0', 'Amount must be more than zero'],
    ['0.00', 'Amount must be more than zero'],
  ])('rejects amount %j', (text, message) => {
    expect(fails(draft({ amountText: text })).amount).toBe(message);
  });

  it('rejects an amount above the ceiling', () => {
    const tooMuch = String(MAX_AMOUNT_PAISE / 100 + 1);
    expect(fails(draft({ amountText: tooMuch })).amount).toBe('That amount is too large');
  });

  it('accepts an amount exactly at the ceiling', () => {
    const atCeiling = buildBill({
      draft: draft({ amountText: String(MAX_AMOUNT_PAISE / 100) }),
      people: people('A'),
      now: NOW,
    });
    expect(atCeiling.ok).toBe(true);
  });

  it('rejects a tax above 100%', () => {
    const errors = fails(draft({ amountText: '10', tax: { text: '101', mode: 'percent' } }));
    expect(errors.tax).toBe('Percentage cannot be more than 100');
  });

  it('rejects a malformed tip', () => {
    const errors = fails(draft({ amountText: '10', tip: { text: 'lots', mode: 'amount' } }));
    expect(errors.tip).toBe('Enter a valid amount');
  });

  it('rejects an extra charge with no value instead of dropping it', () => {
    const errors = fails(
      draft({
        amountText: '10',
        charges: [{ id: 'charge-1', label: 'Packaging', text: '', mode: 'amount' }],
      }),
    );
    expect(errors.charges['charge-1']).toBe('Enter a value or remove this charge');
  });

  it('reports several errors at once', () => {
    const errors = fails(
      draft({
        amountText: '',
        tax: { text: 'x', mode: 'percent' },
        charges: [{ id: 'charge-1', label: '', text: '200', mode: 'percent' }],
      }),
    );
    expect(errors.amount).toBeDefined();
    expect(errors.tax).toBeDefined();
    expect(errors.charges['charge-1']).toBeDefined();
    expect(hasErrors(errors)).toBe(true);
  });

  it('requires at least one person', () => {
    expect(fails(draft({ amountText: '10' }), []).people).toBe('Add at least one person');
  });

  it('reports no errors for a valid draft', () => {
    expect(hasErrors({ charges: {} })).toBe(false);
  });
});
