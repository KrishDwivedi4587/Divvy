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
§6's architectural *intent* is that the route layer is thin and contains only
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

| Directory | Responsibility | Introduced |
|---|---|---|
| `src/app/` | Expo Router routes only | exists |
| `src/core/` | Pure business/calculation logic | Phase 1 |
| `src/domain/` | Domain models and TypeScript types (roadmap §7) | Phase 1 |
| `src/store/` | Application state (active bill) | Phase 3 |
| `src/data/` | Persistence / data access (SQLite) | Phase 3 |
| `src/ocr/` | OCR integration and receipt parsing | Phase 5 |
| `src/gestures/` | Gesture / drag infrastructure | Phase 2 |
| `src/features/` | Feature-specific UI | Phase 2–4 |
| `src/ui/` | Reusable UI primitives and design system | Unit D onward |

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

Android-only. The development machine is Windows, so no iOS build is possible
and iOS is out of scope as a deliberate boundary rather than an oversight.
iOS-specific template configuration and assets were removed in Unit C.
