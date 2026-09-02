/**
 * Divvy domain model — roadmap §7.
 *
 * Pure type declarations. No runtime code, no imports.
 */

/* ------------------------------------------------------------------ *
 * Money                                                               *
 * ------------------------------------------------------------------ */

declare const paiseBrand: unique symbol;

/**
 * Integer paise. NEVER a float. NEVER rupees. ₹123.45 is 12345.
 *
 * Branded so that a raw `number` cannot be passed where money is expected —
 * mixing rupees and paise becomes a compile error rather than a silent
 * hundred-fold bug.
 *
 * (Roadmap §7 writes the brand as `{ readonly __brand: unique symbol }`, which
 * TypeScript rejects: `unique symbol` is only legal on a `const` declaration.
 * The `declare const` form below is the equivalent that compiles.)
 */
export type Paise = number & { readonly [paiseBrand]: true };

export type ID = string;

/* ------------------------------------------------------------------ *
 * Inputs                                                              *
 * ------------------------------------------------------------------ */

export interface Person {
  id: ID;
  name: string;
  /** Index into the fixed 8-colour palette in ui/theme/tokens.ts. */
  colorIndex: number;
  /** 1–2 chars, derived from name at creation, editable. */
  initials: string;
}

export interface BillItem {
  id: ID;
  name: string;
  /** >= 1. Display only in the MVP — splitting is always by value (D4). */
  quantity: number;
  unitPrice: Paise;
  /** AUTHORITATIVE for all splitting. Equals unitPrice × quantity unless overridden. */
  lineTotal: Paise;
  source: 'manual' | 'ocr';
  /** 0..1 from ML Kit; drives the "check this" highlight on the review screen. */
  ocrConfidence?: number;
  /** Original OCR text, kept for debugging and the report's limitations section. */
  rawText?: string;
}

export type AdjustmentKind = 'service' | 'tax' | 'discount' | 'tip' | 'other';

export interface Adjustment {
  id: ID;
  /** "GST", "Service Charge", "Loyalty discount". */
  label: string;
  kind: AdjustmentKind;
  mode: 'percent' | 'amount';
  /**
   * percent → BASIS POINTS (500 = 5.00%). amount → Paise.
   * Integer either way. Never a float.
   */
  value: number;
  /** Ascending; defines application order. Service charge before GST (D6). */
  order: number;
  /**
   * 'itemsSubtotal' — percentage of the items only.
   * 'runningTotal'  — percentage of items plus all preceding adjustments.
   */
  base: 'itemsSubtotal' | 'runningTotal';
  /** True for discounts. The engine apportions |amount| then negates (D7). */
  isNegative: boolean;
}

export interface Bill {
  id: ID;
  title: string;
  /** ISO 8601. */
  createdAt: string;
  settledAt?: string;
  people: Person[];
  items: BillItem[];
  /** itemId → personIds. Empty array = unassigned. */
  assignments: Record<ID, ID[]>;
  adjustments: Adjustment[];
  receiptImageUri?: string;
  /** Who physically paid; receives any residue in round-to-rupee mode (T3.5). */
  payerId?: ID;
}

/* ------------------------------------------------------------------ *
 * Outputs — always derived, never persisted (D9)                      *
 * ------------------------------------------------------------------ */

export interface ItemShare {
  itemId: ID;
  share: Paise;
  assigneeCount: number;
}

/** Negative for discounts. */
export interface AdjustmentShare {
  adjustmentId: ID;
  share: Paise;
}

export interface PersonSettlement {
  personId: ID;
  itemShares: ItemShare[];
  /** Σ itemShares. */
  subtotal: Paise;
  adjustmentShares: AdjustmentShare[];
  /** subtotal + Σ adjustmentShares. */
  total: Paise;
}

export interface Settlement {
  perPerson: PersonSettlement[];
  /** Σ every item lineTotal, assigned or not. */
  itemsSubtotal: Paise;
  adjustmentTotals: { adjustmentId: ID; amount: Paise }[];
  /** itemsSubtotal + Σ adjustmentTotals. */
  grandTotal: Paise;
  unassignedItemIds: ID[];
  unassignedAmount: Paise;
  /** MUST be true. Asserted in dev, surfaced as an error state in prod. */
  reconciles: boolean;
}

/* ------------------------------------------------------------------ *
 * OCR — declarations only                                             *
 * ------------------------------------------------------------------ *
 * Included because roadmap Phase 1 task 1 says "every interface from §7".
 * There is no OCR implementation and none is planned before Phase 5; these
 * exist so the recognise → parse → domain boundary is already typed.
 */

export interface RecognizedLine {
  text: string;
  /** ML Kit frame coordinates. */
  bbox: { x: number; y: number; width: number; height: number };
  confidence?: number;
}

export interface ParsedItem {
  name: string;
  amount: Paise;
  quantity: number;
  /** The parser's own confidence, not ML Kit's. */
  confidence: number;
  sourceLineIndex: number;
}
