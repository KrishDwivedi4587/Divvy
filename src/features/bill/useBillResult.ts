import { useMemo } from 'react';

import { buildBill, type BuildResult } from '@/core/buildBill';
import { DomainError } from '@/core/money';
import { computeSettlement } from '@/core/settle';
import type { Settlement } from '@/domain/types';
import { useBill } from '@/store/BillProvider';

export type BillOutcome =
  /** The form is not valid yet; `build.errors` says why. */
  | { kind: 'invalid'; build: Extract<BuildResult, { ok: false }> }
  /** The engine refused the bill (e.g. numbers too large to compute exactly). */
  | { kind: 'failed'; message: string }
  | { kind: 'ready'; build: Extract<BuildResult, { ok: true }>; settlement: Settlement };

/**
 * Runs the current form state through the calculation engine.
 *
 * All arithmetic happens in `buildBill` and `computeSettlement`; this hook only
 * wires them to the store. The result is derived on every change and never
 * stored (roadmap D9).
 *
 * `now` is only used for the bill's `createdAt`, so the live preview on the
 * details screen can pass a fixed value and stay free of the clock.
 */
export function useBillResult(now: string): BillOutcome {
  const { state } = useBill();
  const { draft, people, photo } = state;
  const photoUri = photo?.uri;

  return useMemo<BillOutcome>(() => {
    const build = buildBill({ draft, people, photoUri, now });
    if (!build.ok) return { kind: 'invalid', build };

    try {
      return { kind: 'ready', build, settlement: computeSettlement(build.bill) };
    } catch (error) {
      // The engine rejects, rather than guesses at, bills it cannot compute
      // exactly. Surface that as a state the screen can show.
      const message =
        error instanceof DomainError
          ? error.message
          : 'Something went wrong calculating this bill.';
      return { kind: 'failed', message };
    }
  }, [draft, people, photoUri, now]);
}
