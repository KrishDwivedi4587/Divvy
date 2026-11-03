/**
 * Turns what the user typed into the calculation engine's `Bill`.
 *
 * The form holds raw strings (so "12." and "" are valid while typing). This is
 * the single place those strings become money, and it never uses a float: every
 * amount goes through `parseAmount` and every rate through `parsePercent`.
 *
 * ── How the entered values map onto the engine ─────────────────────────────
 *
 * The bill amount is the **subtotal** — the food and drink, before tax, tip or
 * extra charges. It becomes one item shared equally by every participant, which
 * the engine splits exactly (remainder to the lowest ids).
 *
 * Adjustments are applied in a fixed order, following roadmap D6 (an Indian
 * bill charges GST on items *plus* service charge, not on items alone):
 *
 *   1. extra charges   — percentages are of the subtotal
 *   2. tax             — percentages are of the subtotal + extra charges
 *   3. tip             — percentages are of the subtotal
 *
 * Per-item assignment is a later phase; the engine already supports it, and the
 * `Bill` produced here is the same shape that phase will populate.
 *
 * Pure TypeScript. No framework imports.
 */

import type { Adjustment, Bill, BillItem, ID, Paise, Person } from '@/domain/types';
import { normalizeDecimalText } from './inputText';
import { parseAmount, type ParseFailure } from './money';
import { parsePercent, type PercentFailure } from './percent';
import { initialsFor } from './people';

/* ------------------------------------------------------------------ *
 * Draft model — what the form holds                                   *
 * ------------------------------------------------------------------ */

export type ValueMode = 'percent' | 'amount';

export interface ValueInput {
  text: string;
  mode: ValueMode;
}

export interface ChargeDraft extends ValueInput {
  id: ID;
  label: string;
}

export interface BillDraft {
  name: string;
  /** The subtotal, before tax, tip and extra charges. */
  amountText: string;
  tax: ValueInput;
  tip: ValueInput;
  charges: ChargeDraft[];
}

export interface PersonInput {
  id: ID;
  name: string;
  colorIndex: number;
}

export const EMPTY_DRAFT: BillDraft = {
  name: '',
  amountText: '',
  tax: { text: '', mode: 'percent' },
  tip: { text: '', mode: 'percent' },
  charges: [],
};

/**
 * Upper bound on any single entered amount: ₹10,00,000.
 *
 * Not arbitrary. The engine multiplies an adjustment amount by a person's
 * running total, and those products must stay below 2^53 to remain exact. This
 * ceiling keeps realistic bills comfortably inside that, and anything beyond it
 * is almost certainly a typo.
 */
export const MAX_AMOUNT_PAISE = 100_000_000 as Paise;

export const DEFAULT_TITLE = 'Untitled bill';
const ITEM_ID = 'item-bill';

/* ------------------------------------------------------------------ *
 * Validation output                                                   *
 * ------------------------------------------------------------------ */

export interface DraftErrors {
  amount?: string;
  tax?: string;
  tip?: string;
  people?: string;
  /** Keyed by charge id. */
  charges: Record<ID, string>;
}

export type BuildResult = { ok: true; bill: Bill } | { ok: false; errors: DraftErrors };

export function hasErrors(errors: DraftErrors): boolean {
  return (
    errors.amount !== undefined ||
    errors.tax !== undefined ||
    errors.tip !== undefined ||
    errors.people !== undefined ||
    Object.keys(errors.charges).length > 0
  );
}

/* ------------------------------------------------------------------ *
 * Parsing a single field                                              *
 * ------------------------------------------------------------------ */

type Field =
  | { kind: 'none' }
  | { kind: 'ok'; mode: ValueMode; value: number }
  | { kind: 'error'; message: string };

const MONEY_MESSAGES: Record<ParseFailure, string> = {
  empty: 'Enter an amount',
  'not-a-number': 'Enter a valid amount',
  negative: 'Amount cannot be negative',
  'too-many-decimals': 'Use at most 2 decimal places',
  'too-large': 'That amount is too large',
};

const PERCENT_MESSAGES: Record<PercentFailure, string> = {
  empty: 'Enter a percentage',
  'not-a-number': 'Enter a valid percentage',
  negative: 'Percentage cannot be negative',
  'too-many-decimals': 'Use at most 2 decimal places',
  'too-large': 'Percentage cannot be more than 100',
};

/**
 * Parses an optional value. Empty input and zero both mean "not applied" and
 * yield `none`, so a blank tax field is simply no tax rather than an error.
 */
function parseOptional(input: ValueInput): Field {
  const text = normalizeDecimalText(input.text);
  if (text === '') return { kind: 'none' };

  if (input.mode === 'percent') {
    const result = parsePercent(text);
    if (!result.ok) return { kind: 'error', message: PERCENT_MESSAGES[result.reason] };
    return result.basisPoints === 0
      ? { kind: 'none' }
      : { kind: 'ok', mode: 'percent', value: result.basisPoints };
  }

  const result = parseAmount(text);
  if (!result.ok) return { kind: 'error', message: MONEY_MESSAGES[result.reason] };
  if (result.value > MAX_AMOUNT_PAISE)
    return { kind: 'error', message: 'That amount is too large' };
  return result.value === 0
    ? { kind: 'none' }
    : { kind: 'ok', mode: 'amount', value: result.value };
}

/* ------------------------------------------------------------------ *
 * buildBill                                                           *
 * ------------------------------------------------------------------ */

export interface BuildInput {
  draft: BillDraft;
  people: readonly PersonInput[];
  photoUri?: string;
  /** ISO 8601. Passed in so this function stays pure and testable. */
  now: string;
  billId?: ID;
}

export function buildBill({
  draft,
  people,
  photoUri,
  now,
  billId = 'bill-draft',
}: BuildInput): BuildResult {
  const errors: DraftErrors = { charges: {} };

  /* Subtotal */
  const amountText = normalizeDecimalText(draft.amountText);
  let amount = 0 as Paise;
  if (amountText === '') {
    errors.amount = 'Enter the bill amount';
  } else {
    const parsed = parseAmount(amountText);
    if (!parsed.ok) {
      errors.amount = MONEY_MESSAGES[parsed.reason];
    } else if (parsed.value === 0) {
      errors.amount = 'Amount must be more than zero';
    } else if (parsed.value > MAX_AMOUNT_PAISE) {
      errors.amount = 'That amount is too large';
    } else {
      amount = parsed.value;
    }
  }

  /* Tax, tip */
  const tax = parseOptional(draft.tax);
  if (tax.kind === 'error') errors.tax = tax.message;
  const tip = parseOptional(draft.tip);
  if (tip.kind === 'error') errors.tip = tip.message;

  /* Extra charges. A row that exists must be valid: silently dropping one
   * would make the total differ from what the user thinks they entered. */
  const chargeFields: { draft: ChargeDraft; field: Extract<Field, { kind: 'ok' }> }[] = [];
  for (const charge of draft.charges) {
    const field = parseOptional(charge);
    if (field.kind === 'error') {
      errors.charges[charge.id] = field.message;
    } else if (field.kind === 'none') {
      errors.charges[charge.id] = 'Enter a value or remove this charge';
    } else {
      chargeFields.push({ draft: charge, field });
    }
  }

  if (people.length === 0) errors.people = 'Add at least one person';

  if (hasErrors(errors)) return { ok: false, errors };

  /* Adjustments, in the order documented above. */
  const adjustments: Adjustment[] = [];
  let order = 1;

  for (const { draft: charge, field } of chargeFields) {
    const label = charge.label.trim() || 'Extra charge';
    adjustments.push({
      id: charge.id,
      label,
      kind: /service/i.test(label) ? 'service' : 'other',
      mode: field.mode,
      value: field.value,
      order: order++,
      base: 'itemsSubtotal',
      isNegative: false,
    });
  }

  if (tax.kind === 'ok') {
    adjustments.push({
      id: 'tax',
      label: 'Tax',
      kind: 'tax',
      mode: tax.mode,
      value: tax.value,
      order: order++,
      base: 'runningTotal',
      isNegative: false,
    });
  }

  if (tip.kind === 'ok') {
    adjustments.push({
      id: 'tip',
      label: 'Tip',
      kind: 'tip',
      mode: tip.mode,
      value: tip.value,
      order: order++,
      base: 'itemsSubtotal',
      isNegative: false,
    });
  }

  const title = draft.name.trim() || DEFAULT_TITLE;

  const item: BillItem = {
    id: ITEM_ID,
    name: title,
    quantity: 1,
    unitPrice: amount,
    lineTotal: amount,
    source: 'manual',
  };

  const bill: Bill = {
    id: billId,
    title,
    createdAt: now,
    people: people.map((p): Person => ({
      id: p.id,
      name: p.name,
      colorIndex: p.colorIndex,
      initials: initialsFor(p.name),
    })),
    items: [item],
    assignments: { [ITEM_ID]: people.map((p) => p.id) },
    adjustments,
    ...(photoUri ? { receiptImageUri: photoUri } : {}),
  };

  return { ok: true, bill };
}
