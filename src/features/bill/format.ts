/**
 * Presentation helpers for bill values. Pure, so they are tested in plain Node.
 *
 * Money itself is formatted by `formatPaise` in the core. These cover the
 * words and dates around it.
 */

import { formatPercent } from '@/core/percent';
import type { Adjustment } from '@/domain/types';

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/**
 * "3 Nov 2026". Built by hand rather than with `Intl`/`toLocaleDateString`:
 * Hermes' Intl support differs between platforms, and a date that reads
 * differently on the iPhone and in a test is a bug waiting to happen.
 */
export function formatDate(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '';
  return `${date.getDate()} ${MONTHS[date.getMonth()]} ${date.getFullYear()}`;
}

/** "Tax · 5%" for a percentage adjustment, plain "Tip" for a flat amount. */
export function adjustmentLabel(adjustment: Pick<Adjustment, 'label' | 'mode' | 'value'>): string {
  return adjustment.mode === 'percent'
    ? `${adjustment.label} · ${formatPercent(adjustment.value)}`
    : adjustment.label;
}

export function peopleCount(n: number): string {
  return n === 1 ? '1 person' : `${n} people`;
}
