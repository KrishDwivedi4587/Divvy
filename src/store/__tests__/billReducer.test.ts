import type { BillPhoto } from '@/domain/photo';
import { MAX_PEOPLE } from '@/core/people';
import {
  billReducer,
  createInitialState,
  MAX_CHARGES,
  MAX_RECENT,
  type BillAction,
  type BillState,
  type SavedBill,
} from '../billReducer';

const run = (actions: BillAction[], from: BillState = createInitialState()): BillState =>
  actions.reduce(billReducer, from);

const photo: BillPhoto = {
  uri: 'file:///bill.jpg',
  width: 3024,
  height: 4032,
  source: 'camera',
};

const saved = (id: string): SavedBill => ({
  id,
  title: `Bill ${id}`,
  createdAt: '2026-11-03T12:00:00.000Z',
  total: 12345,
  peopleCount: 3,
});

describe('initial state', () => {
  it('starts with a single participant, "You"', () => {
    const s = createInitialState();
    expect(s.people).toHaveLength(1);
    expect(s.people[0]).toMatchObject({ name: 'You', colorIndex: 0 });
  });

  it('starts with no photo and an empty draft', () => {
    const s = createInitialState();
    expect(s.photo).toBeNull();
    expect(s.draft.amountText).toBe('');
    expect(s.draft.charges).toEqual([]);
  });
});

describe('photo', () => {
  it('stores and clears the photo', () => {
    const withPhoto = run([{ type: 'setPhoto', photo }]);
    expect(withPhoto.photo).toEqual(photo);
    expect(billReducer(withPhoto, { type: 'setPhoto', photo: null }).photo).toBeNull();
  });
});

describe('draft fields', () => {
  it('sanitises the amount as it is typed', () => {
    expect(run([{ type: 'setAmount', text: '12abc.345' }]).draft.amountText).toBe('12.34');
  });

  it('sets tax value and mode independently', () => {
    const s = run([
      { type: 'setValue', target: 'tax', patch: { text: '5' } },
      { type: 'setValue', target: 'tax', patch: { mode: 'amount' } },
    ]);
    expect(s.draft.tax).toEqual({ text: '5', mode: 'amount' });
  });

  it('does not let a mode change disturb the text', () => {
    const s = run([
      { type: 'setValue', target: 'tip', patch: { text: '10' } },
      { type: 'setValue', target: 'tip', patch: { mode: 'amount' } },
    ]);
    expect(s.draft.tip.text).toBe('10');
  });

  it('caps the bill name length', () => {
    expect(run([{ type: 'setName', text: 'x'.repeat(200) }]).draft.name).toHaveLength(60);
  });
});

describe('extra charges', () => {
  it('adds charges with unique, ordered ids', () => {
    const s = run([{ type: 'addCharge' }, { type: 'addCharge' }]);
    expect(s.draft.charges).toHaveLength(2);
    expect(s.draft.charges[0].id).not.toBe(s.draft.charges[1].id);
    expect(s.draft.charges[0].id < s.draft.charges[1].id).toBe(true);
  });

  it('never reuses an id after a removal', () => {
    const s = run([{ type: 'addCharge' }, { type: 'addCharge' }]);
    const firstId = s.draft.charges[0].id;
    const after = run([{ type: 'removeCharge', id: firstId }, { type: 'addCharge' }], s);
    expect(after.draft.charges.map((c) => c.id)).not.toContain(firstId);
  });

  it('updates only the targeted charge', () => {
    const s = run([{ type: 'addCharge' }, { type: 'addCharge' }]);
    const [a, b] = s.draft.charges;
    const updated = run(
      [
        {
          type: 'updateCharge',
          id: a.id,
          patch: { label: 'Service', text: '10', mode: 'percent' },
        },
      ],
      s,
    );
    expect(updated.draft.charges[0]).toMatchObject({ label: 'Service', text: '10' });
    expect(updated.draft.charges[1]).toEqual(b);
  });

  it('sanitises a charge value', () => {
    const s = run([{ type: 'addCharge' }]);
    const next = billReducer(s, {
      type: 'updateCharge',
      id: s.draft.charges[0].id,
      patch: { text: '1a2.999' },
    });
    expect(next.draft.charges[0].text).toBe('12.99');
  });

  it('removes a charge', () => {
    const s = run([{ type: 'addCharge' }]);
    expect(run([{ type: 'removeCharge', id: s.draft.charges[0].id }], s).draft.charges).toEqual([]);
  });

  it('stops at the charge limit', () => {
    const s = run(Array.from({ length: MAX_CHARGES + 3 }, () => ({ type: 'addCharge' as const })));
    expect(s.draft.charges).toHaveLength(MAX_CHARGES);
  });
});

describe('participants', () => {
  it('adds a trimmed participant after "You"', () => {
    const s = run([{ type: 'addPerson', name: '  Priya   Shah ' }]);
    expect(s.people.map((p) => p.name)).toEqual(['You', 'Priya Shah']);
  });

  it('gives ids whose sort order matches insertion order', () => {
    const s = run(
      Array.from({ length: 7 }, (_, i) => ({ type: 'addPerson' as const, name: `P${i}` })),
    );
    const ids = s.people.map((p) => p.id);
    expect([...ids].sort()).toEqual(ids);
  });

  it('keeps id order stable even after many adds and removes', () => {
    let s = createInitialState();
    for (let i = 0; i < 150; i++) {
      s = billReducer(s, { type: 'addPerson', name: `P${i}` });
      s = billReducer(s, { type: 'removePerson', id: s.people[s.people.length - 1].id });
    }
    s = run(
      [
        { type: 'addPerson', name: 'A' },
        { type: 'addPerson', name: 'B' },
      ],
      s,
    );
    const ids = s.people.map((p) => p.id);
    expect([...ids].sort()).toEqual(ids);
  });

  it('assigns distinct colours', () => {
    const s = run(
      Array.from({ length: 7 }, (_, i) => ({ type: 'addPerson' as const, name: `P${i}` })),
    );
    const colours = s.people.map((p) => p.colorIndex);
    expect(new Set(colours).size).toBe(colours.length);
  });

  it('reuses a freed colour', () => {
    const s = run([
      { type: 'addPerson', name: 'A' },
      { type: 'addPerson', name: 'B' },
    ]);
    const freed = s.people[1];
    const next = run(
      [
        { type: 'removePerson', id: freed.id },
        { type: 'addPerson', name: 'C' },
      ],
      s,
    );
    expect(next.people.find((p) => p.name === 'C')?.colorIndex).toBe(freed.colorIndex);
  });

  it('ignores a blank name', () => {
    expect(run([{ type: 'addPerson', name: '   ' }]).people).toHaveLength(1);
  });

  it('ignores a case-insensitive duplicate', () => {
    expect(run([{ type: 'addPerson', name: 'you' }]).people).toHaveLength(1);
  });

  it('stops at the people limit', () => {
    const s = run(
      Array.from({ length: 20 }, (_, i) => ({ type: 'addPerson' as const, name: `P${i}` })),
    );
    expect(s.people).toHaveLength(MAX_PEOPLE);
  });

  it('removes a participant', () => {
    const s = run([{ type: 'addPerson', name: 'Priya' }]);
    const next = run([{ type: 'removePerson', id: s.people[1].id }], s);
    expect(next.people.map((p) => p.name)).toEqual(['You']);
  });
});

describe('recent bills and reset', () => {
  it('prepends saved bills, newest first', () => {
    const s = run([
      { type: 'saveBill', bill: saved('1') },
      { type: 'saveBill', bill: saved('2') },
    ]);
    expect(s.recent.map((b) => b.id)).toEqual(['2', '1']);
  });

  it('caps the recent list', () => {
    const s = run(
      Array.from({ length: MAX_RECENT + 5 }, (_, i) => ({
        type: 'saveBill' as const,
        bill: saved(String(i)),
      })),
    );
    expect(s.recent).toHaveLength(MAX_RECENT);
  });

  it('reset clears the working bill but keeps the saved ones', () => {
    const dirty = run([
      { type: 'setPhoto', photo },
      { type: 'setAmount', text: '500' },
      { type: 'addPerson', name: 'Priya' },
      { type: 'addCharge' },
      { type: 'saveBill', bill: saved('1') },
    ]);
    const fresh = billReducer(dirty, { type: 'reset' });

    expect(fresh.photo).toBeNull();
    expect(fresh.draft.amountText).toBe('');
    expect(fresh.draft.charges).toEqual([]);
    expect(fresh.people.map((p) => p.name)).toEqual(['You']);
    expect(fresh.recent).toHaveLength(1);
  });

  it('does not mutate the previous state', () => {
    const before = createInitialState();
    const snapshot = JSON.stringify(before);
    billReducer(before, { type: 'addPerson', name: 'Priya' });
    billReducer(before, { type: 'setAmount', text: '99' });
    billReducer(before, { type: 'addCharge' });
    expect(JSON.stringify(before)).toBe(snapshot);
  });
});
