/**
 * Jest configuration.
 *
 * Roadmap Phase 0: "Configure Jest so src/core/** tests run in plain Node with
 * no RN transform (fast)". That is the whole point of the src/core boundary —
 * the calculation engine must be provable on a laptop with no emulator, no
 * device and no native module, and the suite must stay under ~2 seconds.
 *
 * So this uses the plain `node` test environment with ts-jest, NOT the
 * `jest-expo` preset. jest-expo exists to render React Native components; it
 * pulls in the full RN transform and is far slower. If component tests are ever
 * genuinely needed, add jest-expo as a second entry under `projects` rather
 * than slowing this one down.
 */

/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',

  // Pure, non-UI layers only. Deliberately excludes src/app and src/ui.
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.test.ts', '**/*.test.ts'],

  // Mirrors the "@/*" -> "./src/*" alias from tsconfig.json.
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },

  clearMocks: true,

  // The roadmap requires `npm test` to pass on an empty suite while the
  // calculation engine does not yet exist (Phase 1).
  passWithNoTests: true,
};
