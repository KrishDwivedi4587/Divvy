import {
  divRoundHalfAwayFromZero,
  DomainError,
  formatPaise,
  parseAmount,
  percentOf,
  sumPaise,
  toPaise,
} from '../money';
import type { Paise } from '@/domain/types';

const p = (n: number) => n as Paise;

describe('parseAmount', () => {
  it.each([
    ['340', 34000],
    ['340.5', 34050],
    ['340.50', 34050],
    ['₹1,234.50', 123450],
    ['1,00,000', 10000000],
    ['0', 0],
    ['0.01', 1],
    ['Rs 500', 50000],
    ['Rs.500', 50000],
    ['  340  ', 34000],
  ])('parses %s to %i paise', (input, expected) => {
    const result = parseAmount(input);
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value).toBe(expected);
  });

  it.each([
    ['', 'empty'],
    ['abc', 'not-a-number'],
    ['-5', 'negative'],
    ['3.999', 'too-many-decimals'],
    ['12.345', 'too-many-decimals'],
    ['1.2.3', 'not-a-number'],
    ['12abc', 'not-a-number'],
  ])('rejects %s with reason %s', (input, reason) => {
    const result = parseAmount(input);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.reason).toBe(reason);
  });

  it('never produces a fractional paise value', () => {
    for (let i = 0; i < 1000; i++) {
      const rupees = Math.floor(Math.random() * 100000);
      const paise = Math.floor(Math.random() * 100);
      const text = `${rupees}.${String(paise).padStart(2, '0')}`;
      const result = parseAmount(text);
      expect(result.ok).toBe(true);
      if (result.ok) expect(Number.isInteger(result.value)).toBe(true);
    }
  });
});

describe('formatPaise', () => {
  it.each([
    [0, '₹0.00'],
    [1, '₹0.01'],
    [99, '₹0.99'],
    [100, '₹1.00'],
    [123450, '₹1,234.50'],
    [10000000, '₹1,00,000.00'],
    [1234567890, '₹1,23,45,678.90'],
    [-34000, '-₹340.00'],
  ])('formats %i as %s', (input, expected) => {
    expect(formatPaise(p(input))).toBe(expected);
  });

  it('uses Indian digit grouping, not Western', () => {
    expect(formatPaise(p(10000000))).toBe('₹1,00,000.00');
    expect(formatPaise(p(10000000))).not.toBe('₹100,000.00');
  });

  it('round-trips through parseAmount for 10,000 random values', () => {
    for (let i = 0; i < 10000; i++) {
      const value = p(Math.floor(Math.random() * 100_000_000));
      const formatted = formatPaise(value);
      const reparsed = parseAmount(formatted);
      expect(reparsed.ok).toBe(true);
      if (reparsed.ok) expect(reparsed.value).toBe(value);
    }
  });
});

describe('divRoundHalfAwayFromZero', () => {
  it.each([
    [10, 4, 3], // 2.5 -> 3
    [-10, 4, -3], // -2.5 -> -3, away from zero
    [14, 4, 4], // 3.5 -> 4
    [11, 4, 3], // 2.75 -> 3
    [9, 4, 2], // 2.25 -> 2
    [0, 4, 0],
    [7, 1, 7],
  ])('%i / %i rounds to %i', (num, den, expected) => {
    expect(divRoundHalfAwayFromZero(num, den)).toBe(expected);
  });

  it('is symmetric: f(-x) === -f(x)', () => {
    // Negating a 0 result yields -0, which Object.is (and so `toBe`) treats as
    // distinct from 0. The function itself never returns -0; normalise the
    // expected side so the assertion tests symmetry rather than signed zero.
    const noNegZero = (x: number) => x || 0;

    for (let n = 1; n <= 500; n++) {
      expect(divRoundHalfAwayFromZero(-n, 7)).toBe(noNegZero(-divRoundHalfAwayFromZero(n, 7)));
      expect(divRoundHalfAwayFromZero(n, -7)).toBe(noNegZero(-divRoundHalfAwayFromZero(n, 7)));
    }
  });

  it('never returns negative zero', () => {
    // Regression: -0 leaked out for zero numerators, failing Object.is equality.
    // There is no negative zero rupees.
    expect(Object.is(divRoundHalfAwayFromZero(0, 7), 0)).toBe(true);
    expect(Object.is(divRoundHalfAwayFromZero(-0, 7), 0)).toBe(true);
    expect(Object.is(divRoundHalfAwayFromZero(0, -7), 0)).toBe(true);
  });

  it('throws on division by zero', () => {
    expect(() => divRoundHalfAwayFromZero(1, 0)).toThrow(DomainError);
  });
});

describe('percentOf', () => {
  it('applies basis points: 5% of ₹930.00 is ₹46.50', () => {
    expect(percentOf(p(93000), 500)).toBe(4650);
  });

  it('rounds half away from zero: 5% of 97650 is 4882.5 -> 4883', () => {
    expect(percentOf(p(97650), 500)).toBe(4883);
  });

  it('handles 0%', () => {
    expect(percentOf(p(93000), 0)).toBe(0);
  });

  it('handles 100%', () => {
    expect(percentOf(p(93000), 10000)).toBe(93000);
  });

  it('handles 18% GST', () => {
    expect(percentOf(p(100000), 1800)).toBe(18000);
  });

  it('rejects fractional basis points', () => {
    expect(() => percentOf(p(1000), 12.5)).toThrow(DomainError);
  });

  it('always returns a whole number of paise', () => {
    for (let i = 0; i < 2000; i++) {
      const amount = p(Math.floor(Math.random() * 10_000_000));
      const bp = Math.floor(Math.random() * 3000);
      expect(Number.isInteger(percentOf(amount, bp))).toBe(true);
    }
  });
});

describe('toPaise', () => {
  it('accepts safe integers', () => {
    expect(toPaise(0)).toBe(0);
    expect(toPaise(-500)).toBe(-500);
  });

  it.each([
    [1.5, 'NOT_AN_INTEGER'],
    [NaN, 'NOT_FINITE'],
    [Infinity, 'NOT_FINITE'],
  ])('rejects %p with code %s', (value, code) => {
    expect(() => toPaise(value)).toThrow(DomainError);
    try {
      toPaise(value);
    } catch (e) {
      expect((e as DomainError).code).toBe(code);
    }
  });
});

describe('sumPaise', () => {
  it('sums exactly', () => {
    expect(sumPaise([p(3333), p(3333), p(3334)])).toBe(10000);
  });

  it('returns zero for an empty list', () => {
    expect(sumPaise([])).toBe(0);
  });
});
