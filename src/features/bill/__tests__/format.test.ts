import { buildBill, EMPTY_DRAFT } from '@/core/buildBill';
import { computeSettlement } from '@/core/settle';
import { adjustmentLabel, formatDate, peopleCount } from '../format';
import { buildShareText } from '../shareText';

// Built from local components so the expected date does not depend on the
// time zone the tests happen to run in.
const LOCAL_NOON = new Date(2026, 10, 3, 12, 0, 0).toISOString();

describe('formatDate', () => {
  it('formats as "3 Nov 2026"', () => {
    expect(formatDate(LOCAL_NOON)).toBe('3 Nov 2026');
  });

  it('does not pad single-digit days', () => {
    expect(formatDate(new Date(2026, 0, 5, 12).toISOString())).toBe('5 Jan 2026');
  });

  it('returns an empty string for an unparseable date rather than "NaN"', () => {
    expect(formatDate('not a date')).toBe('');
    expect(formatDate('')).toBe('');
  });
});

describe('adjustmentLabel', () => {
  it('shows the rate for a percentage', () => {
    expect(adjustmentLabel({ label: 'Tax', mode: 'percent', value: 500 })).toBe('Tax · 5%');
    expect(adjustmentLabel({ label: 'Tax', mode: 'percent', value: 1825 })).toBe('Tax · 18.25%');
  });

  it('shows just the label for a flat amount', () => {
    expect(adjustmentLabel({ label: 'Tip', mode: 'amount', value: 5000 })).toBe('Tip');
  });
});

describe('peopleCount', () => {
  it('pluralises', () => {
    expect(peopleCount(1)).toBe('1 person');
    expect(peopleCount(2)).toBe('2 people');
    expect(peopleCount(8)).toBe('8 people');
  });
});

describe('buildShareText', () => {
  it('produces the full summary for a bill with a charge, tax and tip', () => {
    const built = buildBill({
      draft: {
        ...EMPTY_DRAFT,
        name: 'Dinner',
        amountText: '1000',
        tax: { text: '5', mode: 'percent' },
        tip: { text: '50', mode: 'amount' },
        charges: [{ id: 'charge-1', label: 'Service charge', text: '10', mode: 'percent' }],
      },
      people: [
        { id: 'person-0001', name: 'You', colorIndex: 0 },
        { id: 'person-0002', name: 'Priya', colorIndex: 1 },
      ],
      now: LOCAL_NOON,
    });
    if (!built.ok) throw new Error('expected a valid bill');

    const text = buildShareText(built.bill, computeSettlement(built.bill));

    expect(text).toBe(
      [
        'Divvy · Dinner',
        '3 Nov 2026',
        '',
        'Total ₹1,205.00, split equally between 2 people',
        '',
        'You: ₹602.50',
        'Priya: ₹602.50',
        '',
        'Subtotal: ₹1,000.00',
        'Service charge · 10%: ₹100.00',
        'Tax · 5%: ₹55.00',
        'Tip: ₹50.00',
      ].join('\n'),
    );
  });

  it('lists the per-person amounts so that they add up to the stated total', () => {
    const built = buildBill({
      draft: { ...EMPTY_DRAFT, amountText: '100' },
      people: ['A', 'B', 'C'].map((name, i) => ({
        id: `person-000${i + 1}`,
        name,
        colorIndex: i,
      })),
      now: LOCAL_NOON,
    });
    if (!built.ok) throw new Error('expected a valid bill');

    const text = buildShareText(built.bill, computeSettlement(built.bill));

    // ₹100.00 across three people: the odd paisa goes to the first.
    expect(text).toContain('A: ₹33.34');
    expect(text).toContain('B: ₹33.33');
    expect(text).toContain('C: ₹33.33');
    expect(text).toContain('Total ₹100.00');
  });

  it('omits the date line rather than printing a blank one when the date is invalid', () => {
    const built = buildBill({
      draft: { ...EMPTY_DRAFT, amountText: '10' },
      people: [{ id: 'person-0001', name: 'You', colorIndex: 0 }],
      now: 'garbage',
    });
    if (!built.ok) throw new Error('expected a valid bill');

    const lines = buildShareText(built.bill, computeSettlement(built.bill)).split('\n');

    expect(lines[0]).toBe('Divvy · Untitled bill');
    expect(lines[1]).toBe('');
  });
});
