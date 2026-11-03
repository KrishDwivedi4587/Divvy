import { createContext, useContext, useReducer, type Dispatch, type ReactNode } from 'react';

import {
  billReducer,
  createInitialState,
  type BillAction,
  type BillState,
} from '@/store/billReducer';

interface BillContextValue {
  state: BillState;
  dispatch: Dispatch<BillAction>;
}

const BillContext = createContext<BillContextValue | null>(null);

/**
 * Holds the bill being built for the lifetime of the app. A plain
 * `useReducer` is enough: this is one small tree of screens, and the logic
 * lives in the pure, tested `billReducer` rather than here.
 */
export function BillProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(billReducer, undefined, () => createInitialState());

  return <BillContext.Provider value={{ state, dispatch }}>{children}</BillContext.Provider>;
}

export function useBill(): BillContextValue {
  const value = useContext(BillContext);
  if (!value) throw new Error('useBill must be used inside <BillProvider>');
  return value;
}
