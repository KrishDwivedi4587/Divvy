import type { Paise } from '@/domain/types';
import { DomainError } from '../money';
import { splitItem } from '../splitItem';

const p = (n: number) => n as Paise;
const sum = (m: Map<string, Paise>) => [...m.values()].reduce((a, b) => a + b, 0);

describe('splitItem', () => {
  it('gives one person the whole amount', () => {
    const shares = splitItem(p(10000), ['a']);
    expect(shares.get('a')).toBe(10000);
    expect(sum(shares)).toBe(10000);
  });

  it('splits ₹100.00 between two people evenly', () => {
    const shares = splitItem(p(10000), ['a', 'b']);
    expect(shares.get('a')).toBe(5000);
    expect(shares.get('b')).toBe(5000);
    expect(sum(shares)).toBe(10000);
  });

  it('splits ₹100.00 across three people as 3334/3333/3333 and sums exactly', () => {
    const shares = splitItem(p(10000), ['a', 'b', 'c']);
    expect(shares.get('a')).toBe(3334); // lowest id absorbs the remainder
    expect(shares.get('b')).toBe(3333);
    expect(shares.get('c')).toBe(3333);
    expect(sum(shares)).toBe(10000);
  });

  it('splits a single paisa across three people without losing it', () => {
    const shares = splitItem(p(1), ['a', 'b', 'c']);
    expect(sum(shares)).toBe(1);
    expect([...shares.values()].sort()).toEqual([0, 0, 1]);
  });

  it('splits ₹100.00 across seven people and sums exactly', () => {
    const ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
    const shares = splitItem(p(10000), ids);
    expect(sum(shares)).toBe(10000);
    // 10000/7 = 1428.57 -> six get 1428, one gets 1429... actually 10000 - 7*1428 = 4
    expect([...shares.values()].filter((v) => v === 1429)).toHaveLength(4);
    expect([...shares.values()].filter((v) => v === 1428)).toHaveLength(3);
  });

  it('returns an empty map for an unassigned item', () => {
    const shares = splitItem(p(10000), []);
    expect(shares.size).toBe(0);
  });

  it('handles a zero-value item', () => {
    const shares = splitItem(p(0), ['a', 'b']);
    expect(sum(shares)).toBe(0);
  });

  it('is order-independent: assignee order does not change anyone share', () => {
    const forward = splitItem(p(10000), ['a', 'b', 'c']);
    const reversed = splitItem(p(10000), ['c', 'b', 'a']);
    expect([...forward.entries()].sort()).toEqual([...reversed.entries()].sort());
  });

  it('is deterministic across 100 identical runs', () => {
    const first = JSON.stringify([...splitItem(p(10001), ['x', 'y', 'z'])].sort());
    for (let i = 0; i < 100; i++) {
      expect(JSON.stringify([...splitItem(p(10001), ['x', 'y', 'z'])].sort())).toBe(first);
    }
  });

  it('rejects a negative line total', () => {
    expect(() => splitItem(p(-1), ['a'])).toThrow(DomainError);
  });

  it('rejects duplicate assignees', () => {
    expect(() => splitItem(p(10000), ['a', 'a'])).toThrow(DomainError);
  });

  describe('fuzz: shares always sum to the line total exactly', () => {
    it('holds for 1..12 people across 500 random amounts each', () => {
      for (let k = 1; k <= 12; k++) {
        const ids = Array.from({ length: k }, (_, i) => `person-${i}`);
        for (let n = 0; n < 500; n++) {
          const amount = p(Math.floor(Math.random() * 5_000_00));
          const shares = splitItem(amount, ids);
          expect(sum(shares)).toBe(amount);
          expect(shares.size).toBe(k);
          for (const v of shares.values()) {
            expect(Number.isInteger(v)).toBe(true);
            expect(v).toBeGreaterThanOrEqual(0);
          }
        }
      }
    });
  });
});
