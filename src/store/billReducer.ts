/**
 * State for the bill being built.
 *
 * A pure reducer with no React import, so it is unit-tested in plain Node like
 * the rest of the logic. `BillProvider` is the thin React wrapper around it.
 *
 * Only *inputs* live here — the photo, the raw form text, the participants. The
 * settlement is always derived from them by the calculation engine and never
 * stored (roadmap D9: a stored total can go stale, a derived one cannot).
 *
 * `recent` is in-memory only. It lasts for the app session; persisting bills to
 * the device is a later phase and is deliberately not faked here.
 */

import {
  EMPTY_DRAFT,
  type BillDraft,
  type ChargeDraft,
  type PersonInput,
  type ValueInput,
} from '@/core/buildBill';
import { sanitizeDecimalInput } from '@/core/inputText';
import { checkPersonName, MAX_PEOPLE } from '@/core/people';
import type { BillPhoto } from '@/domain/photo';

export const MAX_CHARGES = 5;
export const MAX_RECENT = 20;
const DEFAULT_PERSON_NAME = 'You';

export interface SavedBill {
  id: string;
  title: string;
  /** ISO 8601. */
  createdAt: string;
  /** Grand total in integer paise. */
  total: number;
  peopleCount: number;
  photoUri?: string;
}

export interface BillState {
  photo: BillPhoto | null;
  draft: BillDraft;
  people: PersonInput[];
  nextPersonSeq: number;
  nextChargeSeq: number;
  recent: SavedBill[];
}

export type BillAction =
  | { type: 'reset' }
  | { type: 'setPhoto'; photo: BillPhoto | null }
  | { type: 'setName'; text: string }
  | { type: 'setAmount'; text: string }
  | { type: 'setValue'; target: 'tax' | 'tip'; patch: Partial<ValueInput> }
  | { type: 'addCharge' }
  | { type: 'updateCharge'; id: string; patch: Partial<Omit<ChargeDraft, 'id'>> }
  | { type: 'removeCharge'; id: string }
  | { type: 'addPerson'; name: string }
  | { type: 'removePerson'; id: string }
  | { type: 'saveBill'; bill: SavedBill };

/**
 * Zero-padded so that lexicographic order equals insertion order. The engine
 * breaks ties by id, so this makes "who absorbs the odd paisa" follow the order
 * people were added in, rather than something arbitrary.
 */
const personId = (seq: number) => `person-${String(seq).padStart(4, '0')}`;
const chargeId = (seq: number) => `charge-${String(seq).padStart(4, '0')}`;

/** Lowest palette index not already in use, so removed colours get reused. */
function nextColorIndex(people: readonly PersonInput[]): number {
  const used = new Set(people.map((p) => p.colorIndex));
  for (let i = 0; i < MAX_PEOPLE; i++) if (!used.has(i)) return i;
  return people.length % MAX_PEOPLE;
}

export function createInitialState(recent: SavedBill[] = []): BillState {
  return {
    photo: null,
    draft: EMPTY_DRAFT,
    people: [{ id: personId(1), name: DEFAULT_PERSON_NAME, colorIndex: 0 }],
    nextPersonSeq: 2,
    nextChargeSeq: 1,
    recent,
  };
}

function patchValue(current: ValueInput, patch: Partial<ValueInput>): ValueInput {
  return {
    mode: patch.mode ?? current.mode,
    text: patch.text === undefined ? current.text : sanitizeDecimalInput(patch.text),
  };
}

export function billReducer(state: BillState, action: BillAction): BillState {
  switch (action.type) {
    case 'reset':
      // A new bill starts clean but keeps the session's saved bills.
      return createInitialState(state.recent);

    case 'setPhoto':
      return { ...state, photo: action.photo };

    case 'setName':
      return { ...state, draft: { ...state.draft, name: action.text.slice(0, 60) } };

    case 'setAmount':
      return { ...state, draft: { ...state.draft, amountText: sanitizeDecimalInput(action.text) } };

    case 'setValue':
      return {
        ...state,
        draft: {
          ...state.draft,
          [action.target]: patchValue(state.draft[action.target], action.patch),
        },
      };

    case 'addCharge': {
      if (state.draft.charges.length >= MAX_CHARGES) return state;
      const charge: ChargeDraft = {
        id: chargeId(state.nextChargeSeq),
        label: '',
        text: '',
        mode: 'percent',
      };
      return {
        ...state,
        nextChargeSeq: state.nextChargeSeq + 1,
        draft: { ...state.draft, charges: [...state.draft.charges, charge] },
      };
    }

    case 'updateCharge':
      return {
        ...state,
        draft: {
          ...state.draft,
          charges: state.draft.charges.map((c) =>
            c.id === action.id
              ? {
                  ...c,
                  ...(action.patch.label !== undefined
                    ? { label: action.patch.label.slice(0, 40) }
                    : {}),
                  ...(action.patch.mode !== undefined ? { mode: action.patch.mode } : {}),
                  ...(action.patch.text !== undefined
                    ? { text: sanitizeDecimalInput(action.patch.text) }
                    : {}),
                }
              : c,
          ),
        },
      };

    case 'removeCharge':
      return {
        ...state,
        draft: {
          ...state.draft,
          charges: state.draft.charges.filter((c) => c.id !== action.id),
        },
      };

    case 'addPerson': {
      const check = checkPersonName(
        action.name,
        state.people.map((p) => p.name),
      );
      if (!check.ok) return state;
      const person: PersonInput = {
        id: personId(state.nextPersonSeq),
        name: check.name,
        colorIndex: nextColorIndex(state.people),
      };
      return {
        ...state,
        nextPersonSeq: state.nextPersonSeq + 1,
        people: [...state.people, person],
      };
    }

    case 'removePerson':
      return { ...state, people: state.people.filter((p) => p.id !== action.id) };

    case 'saveBill':
      return { ...state, recent: [action.bill, ...state.recent].slice(0, MAX_RECENT) };

    default:
      return state;
  }
}
