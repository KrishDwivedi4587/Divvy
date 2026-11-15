import 'dart:io';
import 'dart:ui' as ui;

import 'package:divvy/app/app.dart';
import 'package:divvy/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_container.dart';

/// iPhone 17 logical size (402 x 874 pt); close enough that layouts are judged
/// at a real phone width.
const Size phoneSize = Size(402, 874);

final GlobalKey _captureKey = GlobalKey();

/// All the text currently on screen, as one string. Used to tell when the UI
/// has stopped changing.
String _screenText(WidgetTester tester) {
  final out = StringBuffer();
  for (final element in find.byType(Text).evaluate()) {
    final text = element.widget as Text;
    out
      ..write(text.data ?? text.textSpan?.toPlainText() ?? '')
      ..write('|');
  }
  out.write(find.byType(CircularProgressIndicator).evaluate().length);
  return out.toString();
}

/// Lets real time pass so work on other isolates (SQLite) can finish, then
/// pumps the frames that result.
///
/// Widget tests run on a fake clock, which never advances a database isolate by
/// itself. A fixed wait is a guess that fails when the machine is busy, so this
/// keeps going until the screen has stopped changing for several rounds in a
/// row (or [timeout] passes).
Future<void> settle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  const roundsStable = 3;
  final watch = Stopwatch()..start();
  var last = '';
  var stable = 0;
  while (watch.elapsed < timeout) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final now = _screenText(tester);
    if (now == last) {
      if (++stable >= roundsStable) break;
    } else {
      stable = 0;
      last = now;
    }
  }
  await tester.pump(const Duration(milliseconds: 400));
}

/// Pumps the whole app over [app]'s providers at [location].
Future<void> pumpApp(
  WidgetTester tester,
  TestApp app, {
  String location = '/',
  Size size = phoneSize,
  Brightness? brightness,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: UncontrolledProviderScope(
        container: app.container,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            devicePixelRatio: 3,
            padding: const EdgeInsets.only(top: 59, bottom: 34),
            platformBrightness: brightness ?? Brightness.light,
            textScaler: TextScaler.linear(textScale),
          ),
          child: DivvyApp(router: buildRouter(initialLocation: location)),
        ),
      ),
    ),
  );
  await settle(tester);
}

/// Saves what is on screen as a PNG under build/screens, for looking at. These
/// are not committed and not compared: they are for reviewing the design.
Future<void> screenshot(WidgetTester tester, String name) async {
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/screens')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Keeps letting real time pass, pumping frames, until [done] is true or
/// [timeout] elapses. For things that finish on another isolate (decoding a
/// photo, a database write) where a fixed number of pumps would be a guess.
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final watch = Stopwatch()..start();
  while (!done() && watch.elapsed < timeout) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Waits (in real time) until some text is on screen. For steps whose outcome
/// is known, this is sturdier than waiting for the screen to go quiet, because
/// a screen can look quiet while work is still in flight (a spinner that has
/// not changed yet).
Future<void> waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  await waitUntil(
    tester,
    () => find.text(text).evaluate().isNotEmpty,
    timeout: timeout,
  );
  await settle(tester);
}
