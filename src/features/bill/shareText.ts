/**
 * A plain-text summary of a settled bill, for the system share sheet.
 *
 * Roadmap §10 layer C: text is the share path that cannot fail. It needs no
 * image rendering and no extra native module, and in a group chat it is
 * arguably better than a picture because it can be copied and searched.
 *
 * Pure: it only formats a `Bill` and its `Settlement`.
 */

import { formatPaise } from '@/core/money';
import { adjustmentLabel, formatDate, peopleCount } from '@/features/bill/format';
import type { Bill, Settlement } from '@/domain/types';

export function buildShareText(bill: Bill, settlement: Settlement): string {
  const names = new Map(bill.people.map((p) => [p.id, p.name]));
  const labels = new Map(bill.adjustments.map((a) => [a.id, adjustmentLabel(a)]));

  const lines: string[] = [`Divvy · ${bill.title}`];

  const date = formatDate(bill.createdAt);
  if (date) lines.push(date);

  lines.push(
    '',
    `Total ${formatPaise(settlement.grandTotal)}, split equally between ${peopleCount(bill.people.length)}`,
    '',
  );

  for (const person of settlement.perPerson) {
    lines.push(`${names.get(person.personId) ?? 'Unknown'}: ${formatPaise(person.total)}`);
  }

  lines.push('', `Subtotal: ${formatPaise(settlement.itemsSubtotal)}`);
  for (const adjustment of settlement.adjustmentTotals) {
    lines.push(
      `${labels.get(adjustment.adjustmentId) ?? 'Charge'}: ${formatPaise(adjustment.amount)}`,
    );
  }

  return lines.join('\n');
}
