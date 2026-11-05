// ESLint flat config. Expo SDK 53+ uses the flat format.
// https://docs.expo.dev/guides/using-eslint/
//
// Division of labour:
//   Prettier -> formatting        (npm run format:check)
//   ESLint   -> code quality      (npm run lint)
//
// `eslint-config-prettier` is included last to switch OFF every ESLint rule
// that overlaps with Prettier, so the two never disagree. Expo's documented
// snippet also adds `eslint-plugin-prettier`, which runs Prettier *as* a lint
// rule; that is deliberately not used here, because it would report the same
// formatting problem twice (once via lint, once via format:check) and slows
// linting down.

const { defineConfig } = require('eslint/config');
const expoConfig = require('eslint-config-expo/flat');
const prettierConfig = require('eslint-config-prettier/flat');

module.exports = defineConfig([
  expoConfig,

  {
    ignores: ['dist/*', 'node_modules/*', '.expo/*', 'expo-env.d.ts', 'submission/*'],
  },

  {
    rules: {
      // Roadmap Phase 7 requires no stray debug logging at submission.
      // `warn`/`error` remain available for genuine diagnostics.
      'no-console': ['warn', { allow: ['warn', 'error'] }],
    },
  },

  // Note: unused variables are already caught by eslint-config-expo, which
  // enables @typescript-eslint/no-unused-vars at "warn" for TS files. Because
  // `npm run lint` runs with --max-warnings=0, that warning fails the build.
  // No override is added here: redefining the rule would mean depending on
  // @typescript-eslint/eslint-plugin transitively, and Expo's defaults are
  // already correct.

  // Must stay last: turns off formatting rules that would fight Prettier.
  prettierConfig,
]);
