# Design Tokens

Rationale for `src/ui/theme/tokens.ts`. The code is the source of truth for
values; this file records _why_ and gives usage guidance that does not belong in
comments.

Established in Phase 0 / Unit D.

---

## Direction

Divvy handles other people's money in a social setting, so the visual language
is built for **fast scanning and unambiguous numbers**, not decoration:

- **Dark, deep-navy base.** Restful in a restaurant at night, and it makes the
  eight avatar colours read as identity rather than noise.
- **Exactly one saturated accent** (indigo `#6B4EEA`) reserved for actions. If
  everything is coloured, nothing is.
- **Colour carries meaning, never decoration.** Avatar colours mean _person_;
  status colours mean _state_. Nothing is tinted for looks.
- **Depth by surface, not shadow** (see below).
- **Restraint.** No gradients, no glassmorphism, one elevation system, two font
  weights.

Constraints taken from the roadmap rather than invented: T1.12 (one typeface,
two weights, one spacing scale, dark theme), Phase 0 task 8 (8-colour avatar
palette, background/surface/text ramp, one accent, 4/8/12/16/24/32 spacing, type
ramp, three springs), and §12 (motion and interaction thresholds).

---

## Why depth is a surface step, not a shadow

Android renders elevation shadows in black. On a `#0B1220` background a black
shadow is invisible, so a shadow-based elevation system would simply not work.

Divvy expresses depth as a **lighter surface**:

```
background  #0B1220   screens
raised      #131C2E   cards, list rows
elevated    #1B2740   the avatar dock, prominent cards
overlay     #24324F   bottom sheets, modals
```

`elevation` values still exist, but only for content genuinely floating above
other content — principally the chip lifted during a drag, where a shadow does
read because it falls on lighter content beneath.

React Native 0.86 also offers the cross-platform `boxShadow`. `elevation` is
used instead because this is an Android-only project and `elevation` maps to the
platform's own shadow API.

---

## Money hierarchy

Divvy is judged on whether the numbers are instantly legible. Use this ladder,
and apply `numeric` (tabular figures) to **every** money value:

| Value                                | Style                  | Colour           |
| ------------------------------------ | ---------------------- | ---------------- |
| Grand total                          | `typography.display`   | `text.primary`   |
| Per-person settlement amount         | `typography.h2`        | `text.primary`   |
| Running avatar total (assign screen) | `typography.label`     | `text.primary`   |
| Item price                           | `typography.body`      | `text.secondary` |
| Subtotal, tax, service charge        | `typography.bodySmall` | `text.muted`     |
| Discount                             | `typography.bodySmall` | `status.success` |

`numeric` matters more than it looks: tabular figures hold each digit column at
a fixed width, which is what allows a total to roll digit-by-digit (§12 A9, A16)
without the surrounding layout shifting.

Formatting money is **not** the token layer's job. Rendering is presentation;
`formatPaise` lives in `src/core/money.ts` and arrives in Phase 1.

---

## Accessibility

Contrast ratios were computed against `surface.background` and are recorded in
`tokens.ts`:

| Token                           | Ratio  | Verdict                     |
| ------------------------------- | ------ | --------------------------- |
| `text.primary`                  | 17.5:1 | passes AA and AAA           |
| `text.secondary`                | 9.0:1  | passes AA and AAA           |
| `text.muted`                    | 5.2:1  | passes AA for body text     |
| `action.primary` + white text   | 5.4:1  | passes AA                   |
| `action.primary` on background  | 3.5:1  | passes AA for UI components |
| Avatar colours + `text.inverse` | ≥ 6:1  | passes AA                   |

These are **calculated**, not measured on a device, and no formal WCAG audit has
been performed. Do not claim compliance in the report beyond that.

Other commitments the tokens support:

- **`layout.minTouchTarget` is 44px.** Every interactive element meets it,
  including avatars in the dock (`avatarSize.lg` is 56).
- **State is never communicated by colour alone.** Avatars always show initials
  alongside their colour; assigned chips dim _and_ carry an owner dot; status
  messages carry text, not just a tint. This matters directly here — the avatar
  palette's red/orange/amber are close under common colour-vision deficiencies.
- **`borderWidth.thick` (2px) with `action.primary`** is the standard visible
  focus/selected treatment.
- Type sizes bottom out at 12px (`caption`), used only for non-essential text.

---

## Dark mode

**Implemented: dark only. Light theme deferred** to Tier 3 (roadmap T3.6), and
likely to be cut.

`app.json` sets `userInterfaceStyle: "dark"` so the OS theme cannot pull native
surfaces out of step with the app. This needs `expo-system-ui` on Android, which
is already a template dependency — nothing was installed.

**The structure supports a light theme without touching component code.** Every
component consumes semantic names (`colors.text.primary`, not `palette.navy900`),
so adding light means:

1. Extract the current `colors` object as `themes.dark`.
2. Add `themes.light` with the same shape.
3. Provide the active theme through a context hook.

Only `tokens.ts` and that hook change; call sites do not. No theme-management
library is needed, and none was added.

---

## Deferred decisions

- **Custom typeface.** The system default (Roboto on Android) is used, with no
  font package installed. Shipping Inter or a similar face would sharpen the
  numerals but costs a dependency, a load step, and a flash-of-unstyled-text
  risk. Revisit during Phase 6 polish, if at all.
- **App icon and splash artwork** are still Expo's defaults. Branding is a
  separate task, not a token concern.
- **Icon library.** None installed. Icon _sizes_ are defined
  (`iconSize`); the icon source is chosen when a screen first needs one.
- **Spring tuning.** The three springs carry starting values only. Roadmap §4
  and Phase 2 budget device time to tune them by feel, and emulator feel is
  explicitly not evidence.
