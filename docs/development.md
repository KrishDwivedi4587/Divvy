# Development

How to run Divvy's quality gates. Setup and toolchain details are in
`docs/environment.md`; project structure is in `docs/architecture.md`.

Established in Phase 0 / Unit E.

---

## The quality gate

```bash
npm run check
```

Runs, in order, stopping at the first failure:

1. **`npm run typecheck`** — `tsc --noEmit`, strict mode, zero errors
2. **`npm run lint`** — ESLint with `--max-warnings=0`
3. **`npm run format:check`** — Prettier, check only, never writes
4. **`npm test`** — Jest

It exits non-zero if any stage fails. No stage is suppressed, and nothing uses
`|| true`. It is safe to run in CI: no stage modifies a file.

Roadmap §21 asks for this after every unit of work, with real output. Roadmap
§13.5 puts the first three lines at the top of the pre-milestone regression
checklist.

Each stage was verified to fail when it should — see the Unit E report.

---

## Individual commands

| Command                | Does                      | Modifies files |
| ---------------------- | ------------------------- | -------------- |
| `npm run typecheck`    | TypeScript, no emit       | no             |
| `npm run lint`         | ESLint; any warning fails | no             |
| `npm run lint:fix`     | ESLint with autofix       | **yes**        |
| `npm run format`       | Prettier, writes          | **yes**        |
| `npm run format:check` | Prettier, verifies only   | no             |
| `npm test`             | Jest, one pass            | no             |
| `npm run test:watch`   | Jest, watch mode          | no             |
| `npm run check`        | all four gates            | no             |

Only `format` and `lint:fix` ever write. Use them freely while working; `check`
is what must be green before a commit.

---

## Where tests belong

Tests live beside the code they cover:

```
src/core/__tests__/*.test.ts
src/ocr/__tests__/*.test.ts
```

Jest matches `**/__tests__/**/*.test.ts` and `**/*.test.ts` under `src/`.

### These tests run without a device

Jest uses the plain `node` environment with `ts-jest` — **not** the `jest-expo`
preset. That is deliberate, and it is why `src/core/` is a pure TypeScript layer
with no React, Expo, or React Native imports: the calculation engine has to be
provable on a laptop with no emulator, no Android, and no native module, and the
suite has to stay fast enough to run on every save (roadmap targets under two
seconds).

The `@/*` alias works in tests via Jest's `moduleNameMapper`, mirroring
`tsconfig.json`.

`passWithNoTests` is on, so `npm test` succeeds while the suite is still empty
(the calculation engine arrives in Phase 1).

**Consequence to know about:** a test that imports React Native — anything under
`src/ui/` or `src/app/` — will not run under this configuration. That is
intentional. If component tests are ever genuinely needed, add `jest-expo` as a
second entry under Jest's `projects` key rather than slowing the core suite
down. Component testing is not currently planned; roadmap §13 puts that
confidence in the manual device checklist instead.

---

## Linting and formatting

The two tools have separate jobs and are configured not to overlap:

- **Prettier owns formatting.** Config in `.prettierrc.json`: single quotes,
  semicolons, trailing commas, 100-column width, LF endings.
- **ESLint owns code quality.** Flat config in `eslint.config.js`, extending
  `eslint-config-expo` (the Expo SDK 57 ruleset).

`eslint-config-prettier` is applied last, switching off every ESLint rule that
would argue with Prettier. Expo's documented snippet also adds
`eslint-plugin-prettier`, which runs Prettier _as_ a lint rule; that is
deliberately not used, because it reports each formatting problem twice — once
through `lint`, once through `format:check` — and makes linting slower.

Two rule decisions worth knowing:

- **`--max-warnings=0`.** Expo's config reports unused variables as warnings.
  Treating warnings as failures is what actually keeps them out of the
  repository.
- **`no-console` is a warning** (so, a failure), with `console.warn` and
  `console.error` still allowed. Roadmap Phase 7 requires no stray debug logging
  at submission. `spikes/**` is exempt — a spike's whole output is often a log.

`DIVVY_ROADMAP.md` is in `.prettierignore`: it is a planning artefact and must
stay byte-identical.

---

## Line endings

`.gitattributes` pins `* text=auto eol=lf`.

This machine has `core.autocrlf=true`, which would give a fresh clone CRLF
working-tree files. Prettier is pinned to `endOfLine: "lf"`, so without this,
`npm run format:check` would fail immediately after cloning. Pinning `eol=lf`
keeps the working tree, the repository, and Prettier in agreement.

Adding it caused no churn — the index and working tree were already LF
(verified with `git ls-files --eol`).
