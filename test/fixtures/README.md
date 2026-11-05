# Test fixtures

## `ts_engine_golden.json`

200 randomly generated bills and the settlement the original TypeScript
calculation engine computed for each: every person's item shares, adjustment
shares, subtotal and total, plus the bill totals. `test/unit/engine/ts_golden_test.dart`
rebuilds each bill in Dart and requires an exact match, so the Dart port is
checked against the engine that shipped, not only against its invariants.

**Provenance.** Produced from the TypeScript engine at the `v0.1-m1-engine`
milestone, read from the `pre-flutter-migration` tag (the last commit that still
contains the React Native app). The generator is `ts_golden_generator.ts.txt`
(a Jest test, stored as text so it is not compiled). To regenerate:

```bash
git worktree add ../divvy-ts pre-flutter-migration
cd ../divvy-ts && npm install
# copy ts_golden_generator.ts.txt to src/core/__tests__/zz_dump.test.ts
npx jest src/core/__tests__/zz_dump.test.ts   # writes test/fixtures/ts_engine_golden.json
```

The fixture is static: the engine is deterministic, so it only needs
regenerating if the TypeScript original were ever changed (it should not be).

## `receipts/`

`spice_table_photo.jpg` is a sample bill ("The Spice Table"), the same one used
in the project's presentation. It is a synthetic receipt created for the
project, not a real customer's bill. The OCR parser tests use hand-written text
and layout fixtures describing it (see `test/unit/receipt/`); the image itself
is for manual testing of the scanning flow on a device.
