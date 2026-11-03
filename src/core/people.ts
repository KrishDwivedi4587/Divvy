/**
 * Participant rules — pure, so the people screen can stay a thin view.
 *
 * Roadmap D3: avatars are initials plus a colour from a fixed 8-colour palette,
 * with no photos and no contacts. The palette has eight entries, so a bill is
 * capped at eight people (roadmap §11 S2).
 */

export const MAX_PEOPLE = 8;
export const MAX_NAME_LENGTH = 24;

/**
 * One or two characters for an avatar: the first letter of the first two words
 * ("Raj Patel" → "RP"), or the first two letters of a single word
 * ("Priya" → "PR").
 */
export function initialsFor(name: string): string {
  const words = name
    .trim()
    .split(/\s+/)
    .map((w) => Array.from(w.replace(/[^\p{L}\p{N}]/gu, '')))
    .filter((chars) => chars.length > 0);

  if (words.length === 0) return '?';

  const picked = words.length === 1 ? words[0].slice(0, 2) : [words[0][0], words[1][0]];

  return picked.join('').toLocaleUpperCase();
}

export type NameCheckFailure = 'empty' | 'duplicate' | 'too-long' | 'limit';

export type NameCheck = { ok: true; name: string } | { ok: false; reason: NameCheckFailure };

/**
 * Validates a name before it is added. Names are compared case-insensitively:
 * two rows both called "raj" and "Raj" would make the summary ambiguous.
 */
export function checkPersonName(
  raw: string,
  existingNames: readonly string[],
  max: number = MAX_PEOPLE,
): NameCheck {
  const name = raw.trim().replace(/\s+/g, ' ');

  if (existingNames.length >= max) return { ok: false, reason: 'limit' };
  if (name === '') return { ok: false, reason: 'empty' };
  if (Array.from(name).length > MAX_NAME_LENGTH) return { ok: false, reason: 'too-long' };

  const key = name.toLocaleLowerCase();
  if (existingNames.some((n) => n.toLocaleLowerCase() === key)) {
    return { ok: false, reason: 'duplicate' };
  }

  return { ok: true, name };
}
