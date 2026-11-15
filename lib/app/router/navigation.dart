import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation helpers so screens say what they mean, and so a pushed route
/// whose result nobody needs does not leave a dangling future.
extension AppNavigation on BuildContext {
  /// Pushes [location] on top of the current screen.
  void open(String location) => unawaited(push<void>(location));

  /// Replaces the whole stack with [location], for switching tabs or leaving a
  /// flow.
  void switchTo(String location) => go(location);
}
