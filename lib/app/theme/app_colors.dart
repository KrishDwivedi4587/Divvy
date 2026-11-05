import 'package:flutter/material.dart';

/// Divvy's colour roles.
///
/// The palette is deliberately monochrome: ink on near-white in light mode and
/// the inverse in dark mode, separated by hairline borders rather than shadows.
/// The only hues are functional: a muted red for errors and destructive
/// actions and an amber for things to double-check. Meaning is never carried by
/// colour alone: warnings and errors also have an icon and words.
@immutable
class DivvyColors extends ThemeExtension<DivvyColors> {
  const DivvyColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.ink,
    required this.onInk,
    required this.danger,
    required this.warning,
    required this.scrim,
    required this.avatarTones,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// The one strong colour: primary buttons, selected states.
  final Color ink;
  final Color onInk;
  final Color danger;
  final Color warning;
  final Color scrim;

  /// Eight neutral background tones for avatars, darkest to lightest.
  final List<Color> avatarTones;

  static const DivvyColors light = DivvyColors(
    background: Color(0xFFFAFAF9),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2F2F0),
    border: Color(0xFFE7E7E4),
    borderStrong: Color(0xFFD1D1CD),
    textPrimary: Color(0xFF0B0B0B),
    textSecondary: Color(0xFF55554F),
    textTertiary: Color(0xFF85857E),
    ink: Color(0xFF0B0B0B),
    onInk: Color(0xFFFFFFFF),
    danger: Color(0xFFB42318),
    warning: Color(0xFF9A5B00),
    scrim: Color(0x99000000),
    avatarTones: [
      Color(0xFF1F1F1D),
      Color(0xFF3B3B38),
      Color(0xFF57574F),
      Color(0xFF75756D),
      Color(0xFF979790),
      Color(0xFFB4B4AE),
      Color(0xFFCCCCC7),
      Color(0xFFE0E0DC),
    ],
  );

  static const DivvyColors dark = DivvyColors(
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF141414),
    surfaceMuted: Color(0xFF1D1D1C),
    border: Color(0xFF282826),
    borderStrong: Color(0xFF3D3D3A),
    textPrimary: Color(0xFFF5F5F3),
    textSecondary: Color(0xFFA8A8A2),
    textTertiary: Color(0xFF75756F),
    ink: Color(0xFFF5F5F3),
    onInk: Color(0xFF0A0A0A),
    danger: Color(0xFFFF7A6E),
    warning: Color(0xFFE2A23B),
    scrim: Color(0xCC000000),
    avatarTones: [
      Color(0xFFE6E6E2),
      Color(0xFFC9C9C4),
      Color(0xFFAAAAA4),
      Color(0xFF8B8B85),
      Color(0xFF6E6E69),
      Color(0xFF55554F),
      Color(0xFF41413D),
      Color(0xFF32322F),
    ],
  );

  /// The avatar background and the text colour that reads on it.
  (Color background, Color foreground) avatar(int index) {
    final background = avatarTones[index.abs() % avatarTones.length];
    final foreground = background.computeLuminance() > 0.4
        ? const Color(0xFF0B0B0B)
        : const Color(0xFFFFFFFF);
    return (background, foreground);
  }

  @override
  DivvyColors copyWith() => this;

  @override
  DivvyColors lerp(ThemeExtension<DivvyColors>? other, double t) {
    if (other is! DivvyColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension DivvyColorsContext on BuildContext {
  DivvyColors get colors => Theme.of(this).extension<DivvyColors>()!;
}
