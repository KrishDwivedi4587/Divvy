import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real fonts for every test.
///
/// Without this, widget tests draw all text in the "Ahem" test font (solid
/// blocks) and every icon as a square, so screenshots are unreadable and text
/// widths are wrong, which hides real overflow bugs. Inter is the app's own
/// font; the icon font comes from the Flutter SDK in use.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final path in files) {
      final bytes = await File(path).readAsBytes();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);

  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk != null) {
    final icons =
        '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(icons).existsSync()) await load('MaterialIcons', [icons]);
  }

  await testMain();
}
