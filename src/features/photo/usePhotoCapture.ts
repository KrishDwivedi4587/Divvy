import { useCallback, useState } from 'react';

import type { PhotoSource } from '@/domain/photo';
import { pickPhoto, takePhoto } from '@/platform/photo';
import { useBill } from '@/store/BillProvider';

/** What the UI should tell the user when a capture did not produce a photo. */
export type CaptureProblem =
  { kind: 'denied'; canAskAgain: boolean } | { kind: 'error'; message: string };

/**
 * The shared bill-photo workflow. The camera and the gallery both go through
 * `capture`, so whichever the user picks they end in the same place: the chosen
 * photo is stored on the bill and the caller decides where to navigate.
 *
 * Resolves `true` only when a photo was stored. Cancelling is not a problem to
 * report — the user chose to back out — so it resolves `false` with no notice,
 * and any photo already on the bill is left alone.
 */
export function usePhotoCapture() {
  const { state, dispatch } = useBill();
  const [busy, setBusy] = useState<PhotoSource | null>(null);
  const [problem, setProblem] = useState<CaptureProblem | null>(null);

  const capture = useCallback(
    async (source: PhotoSource): Promise<boolean> => {
      if (busy) return false;

      setBusy(source);
      setProblem(null);

      const result = source === 'camera' ? await takePhoto() : await pickPhoto();

      setBusy(null);

      switch (result.status) {
        case 'success':
          dispatch({ type: 'setPhoto', photo: result.photo });
          return true;
        case 'denied':
          setProblem({ kind: 'denied', canAskAgain: result.canAskAgain });
          return false;
        case 'error':
          setProblem({ kind: 'error', message: result.message });
          return false;
        case 'cancelled':
          return false;
      }
    },
    [busy, dispatch],
  );

  const clearProblem = useCallback(() => setProblem(null), []);

  return { photo: state.photo, busy, problem, capture, clearProblem };
}
