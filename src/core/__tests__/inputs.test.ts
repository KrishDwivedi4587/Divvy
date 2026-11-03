import { normalizeDecimalText, sanitizeDecimalInput } from '../inputText';
import { formatPercent, MAX_BASIS_POINTS, parsePercent } from '../percent';
import { checkPersonName, initialsFor, MAX_PEOPLE } from '../people';

describe('sanitizeDecimalInput', () => {
  it.each([
    ['', ''],
    ['340', '340'],
    ['340.5', '340.5'],
    ['340.50', '340.50'],
    ['340.', '340.'],
    ['.5', '.5'],
    ['abc', ''],
    ['12abc34', '1234'],
    ['1.2.3', '1.23'],
    ['12.345', '12.34'],
    ['-5', '5'],
    ['₹1,234.50', '1234.50'],
  ])('sanitises %j to %j', (raw, expected) => {
    expect(sanitizeDecimalInput(raw)).toBe(expected);
  });

  it('caps integer digits so an absurd paste cannot overflow downstream', () => {
    expect(sanitizeDecimalInput('123456789012')).toBe('12345678');
  });

  it('honours a custom decimal limit, including none', () => {
    expect(sanitizeDecimalInput('12.345', 3)).toBe('12.345');
    expect(sanitizeDecimalInput('12.5', 0)).toBe('125');
  });

  it('drops a comma rather than guessing it was a decimal separator', () => {
    // Guessing wrong would turn 1,234 into 1.234 — a thousand-fold money error.
    expect(sanitizeDecimalInput('1,234')).toBe('1234');
  });
});

describe('normalizeDecimalText', () => {
  it.each([
    ['', ''],
    ['   ', ''],
    ['.', ''],
    ['340.', '340'],
    ['.5', '0.5'],
    [' 12.50 ', '12.50'],
    ['7', '7'],
  ])('normalises %j to %j', (input, expected) => {
    expect(normalizeDecimalText(input)).toBe(expected);
  });
});

describe('parsePercent', () => {
  it.each([
    ['5', 500],
    ['5%', 500],
    ['5.5', 550],
    ['12.25', 1225],
    ['0', 0],
    ['100', 10000],
    [' 18 % ', 1800],
    ['0.01', 1],
  ])('parses %j as %i basis points', (input, expected) => {
    const result = parsePercent(input);
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.basisPoints).toBe(expected);
  });

  it.each([
    ['', 'empty'],
    ['abc', 'not-a-number'],
    ['-5', 'negative'],
    ['5.123', 'too-many-decimals'],
    ['100.01', 'too-large'],
    ['101', 'too-large'],
    ['1.2.3', 'not-a-number'],
  ])('rejects %j as %s', (input, reason) => {
    const result = parsePercent(input);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.reason).toBe(reason);
  });

  it('produces only whole basis points, never a float', () => {
    for (let i = 0; i < 1000; i++) {
      const text = `${Math.floor(Math.random() * 100)}.${String(Math.floor(Math.random() * 100)).padStart(2, '0')}`;
      const result = parsePercent(text);
      expect(result.ok).toBe(true);
      if (result.ok) expect(Number.isInteger(result.basisPoints)).toBe(true);
    }
  });

  it('treats exactly 100% as the ceiling', () => {
    expect(MAX_BASIS_POINTS).toBe(10000);
  });
});

describe('formatPercent', () => {
  it.each([
    [500, '5%'],
    [550, '5.5%'],
    [1225, '12.25%'],
    [1, '0.01%'],
    [0, '0%'],
    [10000, '100%'],
  ])('formats %i as %s', (bp, expected) => {
    expect(formatPercent(bp)).toBe(expected);
  });

  it('round-trips through parsePercent', () => {
    for (let bp = 0; bp <= 10000; bp += 7) {
      const parsed = parsePercent(formatPercent(bp));
      expect(parsed.ok).toBe(true);
      if (parsed.ok) expect(parsed.basisPoints).toBe(bp);
    }
  });
});

describe('initialsFor', () => {
  it.each([
    ['Priya', 'PR'],
    ['Raj Patel', 'RP'],
    ['  raj   patel  ', 'RP'],
    ['Mary Jane Watson', 'MJ'],
    ['You', 'YO'],
    ['A', 'A'],
    ['aarav', 'AA'],
    ['', '?'],
    ['   ', '?'],
    ['!!!', '?'],
    ['Zoë', 'ZO'],
  ])('derives %j → %j', (name, expected) => {
    expect(initialsFor(name)).toBe(expected);
  });
});

describe('checkPersonName', () => {
  it('accepts and tidies a valid name', () => {
    expect(checkPersonName('  Priya   Shah ', [])).toEqual({ ok: true, name: 'Priya Shah' });
  });

  it('rejects an empty name', () => {
    expect(checkPersonName('   ', [])).toEqual({ ok: false, reason: 'empty' });
  });

  it('rejects a duplicate regardless of case', () => {
    expect(checkPersonName('RAJ', ['Raj'])).toEqual({ ok: false, reason: 'duplicate' });
  });

  it('rejects a name that is too long', () => {
    expect(checkPersonName('x'.repeat(25), [])).toEqual({ ok: false, reason: 'too-long' });
  });

  it('accepts a name exactly at the length limit', () => {
    expect(checkPersonName('x'.repeat(24), []).ok).toBe(true);
  });

  it('enforces the people limit before anything else', () => {
    const full = Array.from({ length: MAX_PEOPLE }, (_, i) => `P${i}`);
    expect(checkPersonName('New', full)).toEqual({ ok: false, reason: 'limit' });
  });
});
