import 'package:flutter/widgets.dart';

/// The spacing scale. Every gap and padding in the app comes from here.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// The horizontal gutter of every screen.
  static const double gutter = 20;

  /// The minimum tappable size, per Apple's guidelines.
  static const double minTap = 44;
}

/// Corner radii. Surfaces are only gently rounded.
abstract final class Corners {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get control => BorderRadius.circular(md);
}

/// Vertical gaps as widgets, so layouts read as intent rather than numbers.
abstract final class Gap {
  static const Widget xs = SizedBox(height: Space.xs, width: Space.xs);
  static const Widget sm = SizedBox(height: Space.sm, width: Space.sm);
  static const Widget md = SizedBox(height: Space.md, width: Space.md);
  static const Widget lg = SizedBox(height: Space.lg, width: Space.lg);
  static const Widget xl = SizedBox(height: Space.xl, width: Space.xl);
  static const Widget xxl = SizedBox(height: Space.xxl, width: Space.xxl);
}
