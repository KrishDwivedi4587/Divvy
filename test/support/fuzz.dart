import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Runs a randomised test body with a seeded [Random] and, on failure, reports
/// the seed so the failing inputs can be reproduced exactly:
///
///     flutter test --dart-define=FUZZ_SEED=12345
///
/// Unseeded randomness in a test is how a 2.5%-of-runs flake went unnoticed in
/// the original suite; a failure that cannot be replayed is nearly useless.
void fuzz(void Function(Random rnd) body) {
  const fromEnv = String.fromEnvironment('FUZZ_SEED');
  final seed = fromEnv.isNotEmpty
      ? int.parse(fromEnv)
      : Random().nextInt(1 << 31);
  try {
    body(Random(seed));
  } on TestFailure catch (e) {
    throw TestFailure('${e.message}\n(reproduce with FUZZ_SEED=$seed)');
  } catch (e) {
    throw TestFailure('$e\n(reproduce with FUZZ_SEED=$seed)');
  }
}
