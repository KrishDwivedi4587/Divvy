# Divvy Architecture

Authoritative description of how this project is laid out and why. Established
in Phase 0 / Unit C. Companion to `DIVVY_ROADMAP.md` (planning) and
`docs/environment.md` (machine setup).

This document is the **map**. Directories listed here are created when the
implementation that fills them begins — not in advance. Git does not track empty
directories, and placeholder files would add noise without adding information.

---

## Routing

Routes live in **`src/app/`**.

`src/app/` is **exclusively** for Expo Router route and layout files.

> **Non-route application code must not be placed in `src/app/`, because Expo
> Router will attempt to interpret it as a route.**

Only `_layout.tsx` and other `_`-prefixed files are exempt from becoming routes.
Components, hooks, calculation functions, stores, database access, OCR parsing
and utilities all belong in a sibling directory under `src/`, never in
`src/app/`.

### Intentional deviation from roadmap §6

- Roadmap §6 depicts `app/` at the **repository root**.
- Expo SDK 57 officially supports — and the default template uses — **`src/app/`**.
- **Divvy uses `src/app/`.**
- `DIVVY_ROADMAP.md` remains **unchanged**.

This is an implementation-level interpretation, not a correction of the roadmap.
§6's architectural _intent_ is that the route layer is thin and contains only
routes; that intent is fully preserved. The roadmap's `app/` notation describes
the **route layer conceptually**, and `src/app/` is where SDK 57 puts it.

Reasons for the decision:

1. Officially supported on SDK 55+ with **no extra configuration**.
2. `src/app/` **takes precedence** over a root `app/` if both exist — keeping
   only one avoids a silent-precedence bug class.
3. Expo's own SDK 57 documentation uses `src/app/` as the canonical path, so
   documentation examples map directly onto this repository.
4. Moving to root `app/` would be a self-inflicted migration with no benefit.
5. Requires no Metro or Babel customisation.

Expo's Router config plugin can relocate the route root, but the documentation
states this is "highly discouraged" and unsupported for bug reports. Divvy does
not use it.

---

## Source structure

| Directory       | Responsibility                                                  | Status                      |
| --------------- | --------------------------------------------------------------- | --------------------------- |
| `src/app/`      | Expo Router routes only                                         | exists                      |
| `src/core/`     | Pure business/calculation logic. **No framework imports**       | exists (Phase 1)            |
| `src/domain/`   | Domain models and TypeScript types                              | exists                      |
| `src/store/`    | The bill being built: a pure reducer plus a thin React provider | exists (check-in)           |
| `src/platform/` | Native integrations (camera, gallery), isolated from `core`     | exists (check-in)           |
| `src/features/` | Feature-specific UI and hooks (`photo`, `bill`, `navigation`)   | exists (check-in)           |
| `src/ui/`       | Reusable UI primitives and the design tokens                    | exists                      |
| `src/data/`     | Persistence / data access (SQLite)                              | not yet (later phase)       |
| `src/ocr/`      | OCR integration and receipt parsing                             | not yet (needs a dev build) |
| `src/gestures/` | Gesture / drag infrastructure                                   | not yet (needs a device)    |

`src/platform/` was added for the check-in. The roadmap's tree had no home for
native integrations other than OCR; camera and gallery access import a native
module, so they cannot live in `src/core/`, which must run in plain Node.

**State management.** The original plan listed Zustand for `src/store/`. The
check-in uses a plain `useReducer` + Context instead: the app is one small tree of
screens, and the logic sits in a pure, unit-tested reducer (`billReducer`). No
state library was added. Zustand remains an option if the state grows.

Path alias: **`@/*` → `./src/*`** (plus `@/assets/*` → `./assets/*`), declared in
`tsconfig.json`. Expo CLI and Metro resolve `tsconfig.json` path aliases
automatically; no `baseUrl` is required under `moduleResolution: "bundler"`, and
no additional alias system is used. Restart Expo CLI after changing the alias.

---

## Separation of concerns

1. **Calculation logic must not depend on React Native UI.**
2. **Core calculation code must be executable and testable without Android** —
   no emulator, no device, no native module.
3. **Route files stay thin.** They compose features; they do not contain logic.
4. **Native integrations are isolated from pure business logic.**
5. **OCR parsing is separable from native OCR recognition.** Recognition (native,
   impure) produces a plain serialisable structure; parsing (pure) consumes it.
6. **Database access stays isolated from the calculation engine.** The engine
   receives plain data as parameters and returns plain data.
7. **Spikes must never become production dependencies.**

The load-bearing rule is (1)+(2): `src/core/` imports nothing from `react`,
`react-native`, `expo`, or `src/store/`. Anything it needs arrives as a
parameter. This is what keeps the money logic verifiable on a laptop.

---

## Tests

Pure calculation tests are colocated with the code they cover:

```
src/core/__tests__/
```

These must run **without** Android, the Expo runtime, a physical device, native
OCR, or the database. That is a direct consequence of the separation rules
above, and it is the reason the calculation engine can be developed and proven
independently of device availability.

OCR **parsing** is likewise testable in isolation, against saved fixtures of
recognition output, with no camera and no native module involved.

The test runner is configured in a later unit; this section fixes the
convention, not the tooling.

**Update (check-in).** Tests now also live beside `src/store`, `src/platform` and
`src/features/bill`. `src/platform/__tests__/photo.test.ts` replaces the native
`expo-image-picker` module with a mock, so it tests the decision logic around the camera (permission
granted, declined, permanently blocked, cancelled, error) without a camera. It
does **not** prove the iPhone camera works; only a device can.

React components are not unit-tested: Jest runs in the plain `node` environment
(roadmap line 1311). They are verified by running the app.

---

## Spikes

```
spikes/
```

Disposable technical experiments. See `spikes/README.md` for the rules.

**Production code under `src/` must never import from `spikes/`.** A spike
proves or disproves an approach; the production implementation is then written
fresh in `src/`, informed by the finding.

---

## Platform scope

**iOS is the primary demonstration platform, with Android and web kept working.**

This reverses the earlier decision. Unit C recorded the project as Android-only
(a Galaxy Note 9 was the demo device) and removed the `ios` block from
`app.json`. The demo device is now an iPhone 17, so the block is back, with
`bundleIdentifier` and the camera / photo permission strings.

The development machine is still Windows, which cannot build iOS locally. The
project therefore runs in **Expo Go**, loading over the network, and every
dependency the app imports is bundled in Expo Go. See
[`checkin-plan.md`](checkin-plan.md) for the reasoning and sources, and
[`ios-demo.md`](ios-demo.md) for how to run it.

Consequences kept visible:

- **ML Kit is not imported by anything under `src/`.** It is a native module Expo
  Go cannot load. The Android spike evidence remains in `spikes/`.
- **Web is a fallback, not a target.** `react-native-web` was already installed;
  the whole flow runs in a browser, which is also the safety net if Expo Go and
  the SDK ever disagree.
- `web.output` is `"single"` (client-only). The template default `"static"` renders
  pages on the server, which this in-memory app does not need.

---

## Navigation

A linear flow with no tab bar (roadmap §11: it is a workflow, not parallel
sections). Routes live in `src/app/`:

```
/            Home            New bill · Upload a bill photo · recent bills
/capture     Capture         Take photo · Upload from gallery · enter manually
/preview     Preview         Retake / Choose another · Remove · Use this photo
/details     Bill details    name · amount · tax · tip · extra charges
/people      People          add and remove participants
/summary     Summary         totals · per person · breakdown · share · save
```

Both capture paths and the Home shortcut end at `/preview`. "Enter details
manually" skips the photo and goes straight to `/details`: the photo is a
convenience, never a requirement (roadmap §1 D1).

Every screen that depends on earlier input handles arriving without it (a reload,
or a deep link on web) with an explanatory empty state rather than a blank page or
zeros.

## Data flow

```
 form text ──▶ billReducer ──▶ BillState
                                  │
                       buildBill(draft, people)        src/core, pure
                                  │
                              Bill (engine type)
                                  │
                       computeSettlement(bill)         src/core, pure, M1
                                  │
                       Settlement ──▶ screens display it
```

Inputs are stored; the settlement is derived on every change and never stored
(roadmap D9). No screen does any money arithmetic of its own.
