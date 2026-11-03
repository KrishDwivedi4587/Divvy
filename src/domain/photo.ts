/**
 * The photograph attached to a bill.
 *
 * Kept separate from `types.ts` (the roadmap §7 money model) because a photo is
 * a capture-time concern, not part of the calculation. It never enters the
 * engine: `Bill.receiptImageUri` carries only the URI.
 *
 * Everything stays on the device. Nothing here is uploaded anywhere.
 */

export type PhotoSource = 'camera' | 'library';

export interface BillPhoto {
  /** Local file URI (or a blob/data URI on web). */
  uri: string;
  /** Pixel dimensions; 0 when the platform does not report them. */
  width: number;
  height: number;
  source: PhotoSource;
  fileName?: string;
  mimeType?: string;
}
