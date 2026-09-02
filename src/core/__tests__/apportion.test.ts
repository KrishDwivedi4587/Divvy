import type { Paise } from '@/domain/types';
import { apportion, apportionSigned, type Weighted } from '../apportion';
import { DomainError } from '../money';

const p = (n: number) => n as Paise;
const total = (shares: { share: Paise }[]) => shares.reduce((a, s) => a + s.share, 0);

const w = (...weights: number[]): Weighted[] =>
  weights.map((weight, i) => ({ id: `p${i}`, weight }));

describe('apportion', () => {
  it('splits equally when weights are equal', () => {
    const shares = apportion(p(300), w(100, 100, 100));
    expect(shares.map((s) => s.share)).toEqual([100, 100, 100]);
  });

  it('gives equal weights shares within one paisa of each other', () => {
    const shares = apportion(p(100), w(50, 50, 50));
    const values = shares.map((s) => s.share).sort();
    expect(values[values.length - 1] - values[0]).toBeLessThanOrEqual(1);
    expect(total(shares)).toBe(100);
  });

  it('distributes proportionally to weight', () => {
    const shares = apportion(p(1000), w(750, 250));
    expect(shares.map((s) => s.share)).toEqual([750, 250]);
  });

  it('gives a zero-weight person nothing', () => {
    const shares = apportion(p(1000), w(1000, 0));
    expect(shares[1].share).toBe(0);
    expect(total(shares)).toBe(1000);
  });

  it('falls back to an equal split when every weight is zero', () => {
    const shares = apportion(p(100), w(0, 0, 0, 0));
    expect(total(shares)).toBe(100);
    expect(shares.map((s) => s.share)).toEqual([25, 25, 25, 25]);
  });

  it('still reconciles when a zero-weight fallback does not divide evenly', () => {
    const shares = apportion(p(10), w(0, 0, 0));
    expect(total(shares)).toBe(10);
  });

  it('returns an empty array when there are no entries', () => {
    expect(apportion(p(100), [])).toEqual([]);
  });

  it('handles a zero amount', () => {
    const shares = apportion(p(0), w(100, 200));
    expect(total(shares)).toBe(0);
  });

  it('preserves the caller ordering, not the ranked ordering', () => {
    const shares = apportion(p(100), [
      { id: 'zoya', weight: 10 },
      { id: 'aarav', weight: 90 },
    ]);
    expect(shares.map((s) => s.id)).toEqual(['zoya', 'aarav']);
  });

  it('breaks remainder ties by id ascending, deterministically', () => {
    // Three equal weights, one leftover paisa: the lowest id must take it.
    const shares = apportion(p(10), [
      { id: 'c', weight: 1 },
      { id: 'a', weight: 1 },
      { id: 'b', weight: 1 },
    ]);
    const byId = Object.fromEntries(shares.map((s) => [s.id, s.share]));
    expect(byId.a).toBe(4);
    expect(byId.b).toBe(3);
    expect(byId.c).toBe(3);
    expect(total(shares)).toBe(10);
  });

  it('is stable across 100 identical runs', () => {
    const entries = w(31668, 31666, 29666);
    const first = JSON.stringify(apportion(p(4650), entries));
    for (let i = 0; i < 100; i++) {
      expect(JSON.stringify(apportion(p(4650), entries))).toBe(first);
    }
  });

  it('reproduces the roadmap worked example, service charge step', () => {
    const shares = apportion(p(4650), [
      { id: 'aarav', weight: 31668 },
      { id: 'priya', weight: 31666 },
      { id: 'zoya', weight: 29666 },
    ]);
    expect(shares.map((s) => s.share)).toEqual([1584, 1583, 1483]);
    expect(total(shares)).toBe(4650);
  });

  it('reproduces the roadmap worked example, GST step', () => {
    const shares = apportion(p(4883), [
      { id: 'aarav', weight: 33252 },
      { id: 'priya', weight: 33249 },
      { id: 'zoya', weight: 31149 },
    ]);
    expect(shares.map((s) => s.share)).toEqual([1663, 1663, 1557]);
    expect(total(shares)).toBe(4883);
  });

  it('rejects a negative amount', () => {
    expect(() => apportion(p(-100), w(1, 1))).toThrow(DomainError);
  });

  it('rejects a negative weight', () => {
    expect(() => apportion(p(100), w(1, -1))).toThrow(DomainError);
  });

  describe('fuzz: shares always sum to the amount exactly', () => {
    it('holds for 10,000 random (amount, weights) pairs', () => {
      for (let i = 0; i < 10000; i++) {
        const n = 1 + Math.floor(Math.random() * 8);
        const entries = Array.from({ length: n }, (_, j) => ({
          id: `p${j}`,
          weight: Math.floor(Math.random() * 100000),
        }));
        const amount = p(Math.floor(Math.random() * 1_000_000));
        const shares = apportion(amount, entries);
        expect(total(shares)).toBe(amount);
        for (const s of shares) expect(Number.isInteger(s.share)).toBe(true);
      }
    });
  });
});

describe('apportionSigned — the D7 negative-amount trap', () => {
  it('apportions a NEGATIVE amount to exactly the negative total', () => {
    // The trap: Math.floor(-7/3) is -3, not -2. Apportioning a negative amount
    // directly would overshoot and break reconciliation. The magnitude must be
    // apportioned and then negated.
    const shares = apportionSigned(p(4650), w(31668, 31666, 29666), true);
    expect(total(shares)).toBe(-4650);
    expect(shares.every((s) => s.share <= 0)).toBe(true);
  });

  it('is the exact mirror of the positive case', () => {
    const entries = w(1000, 3000, 7);
    const positive = apportion(p(12345), entries);
    const negative = apportionSigned(p(12345), entries, true);
    expect(negative.map((s) => s.share)).toEqual(positive.map((s) => -s.share));
  });

  it('leaves a non-negative adjustment untouched', () => {
    const entries = w(100, 200);
    expect(apportionSigned(p(300), entries, false)).toEqual(apportion(p(300), entries));
  });

  it('sums to exactly -A across 5,000 random discounts', () => {
    for (let i = 0; i < 5000; i++) {
      const n = 1 + Math.floor(Math.random() * 6);
      const entries = Array.from({ length: n }, (_, j) => ({
        id: `p${j}`,
        weight: Math.floor(Math.random() * 50000),
      }));
      const amount = p(Math.floor(Math.random() * 200000));
      const shares = apportionSigned(amount, entries, true);
      expect(total(shares)).toBe(-amount);
    }
  });
});
