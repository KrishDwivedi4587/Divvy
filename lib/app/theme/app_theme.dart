import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/spacing.dart';
import 'app_colors.dart';

/// Builds the light and dark [ThemeData]. Material 3 is the foundation; every
/// component is restyled here, once, so no screen styles itself.
abstract final class AppTheme {
  static const String fontFamily = 'Inter';

  static ThemeData get light => _build(DivvyColors.light, Brightness.light);
  static ThemeData get dark => _build(DivvyColors.dark, Brightness.dark);

  static TextTheme _textTheme(DivvyColors c) {
    TextStyle s(
      double size,
      double height,
      FontWeight weight, {
      double ls = 0,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: ls,
        color: c.textPrimary,
      );
    }

    return TextTheme(
      displayLarge: s(40, 44, FontWeight.w700, ls: -1.0),
      displayMedium: s(32, 38, FontWeight.w700, ls: -0.7),
      headlineLarge: s(28, 34, FontWeight.w700, ls: -0.5),
      headlineMedium: s(24, 30, FontWeight.w700, ls: -0.4),
      titleLarge: s(20, 26, FontWeight.w600, ls: -0.2),
      titleMedium: s(16, 22, FontWeight.w600),
      titleSmall: s(14, 20, FontWeight.w600),
      bodyLarge: s(16, 24, FontWeight.w400),
      bodyMedium: s(14, 20, FontWeight.w400),
      bodySmall: s(12, 16, FontWeight.w400),
      labelLarge: s(15, 20, FontWeight.w600),
      labelMedium: s(13, 18, FontWeight.w600),
      labelSmall: s(11, 14, FontWeight.w600, ls: 0.6),
    );
  }

  static ThemeData _build(DivvyColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.onInk,
      secondary: c.textSecondary,
      onSecondary: c.background,
      error: c.danger,
      onError: c.onInk,
      surface: c.surface,
      onSurface: c.textPrimary,
      outline: c.borderStrong,
      outlineVariant: c.border,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceMuted,
      surfaceContainerHighest: c.surfaceMuted,
    );

    final text = _textTheme(c);
    final shape = RoundedRectangleBorder(borderRadius: Corners.control);
    // Width 0: a button is only as wide as it needs to be unless it is told to
    // expand (see AppButton). `Size.fromHeight` would mean an infinite minimum
    // width, which crashes layout for any button inside a Row.
    const minimumSize = Size(0, 52);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      fontFamily: fontFamily,
      textTheme: text,
      primaryTextTheme: text,
      extensions: [c],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: c.textPrimary,
        titleTextStyle: text.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.onInk,
          disabledBackgroundColor: c.surfaceMuted,
          disabledForegroundColor: c.textTertiary,
          minimumSize: minimumSize,
          shape: shape,
          elevation: 0,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          disabledForegroundColor: c.textTertiary,
          minimumSize: minimumSize,
          shape: shape,
          side: BorderSide(color: c.borderStrong),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(Space.minTap, Space.minTap),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(Space.minTap, Space.minTap),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: 15,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: c.textTertiary),
        labelStyle: text.bodyMedium?.copyWith(color: c.textSecondary),
        floatingLabelStyle: text.labelMedium?.copyWith(color: c.textSecondary),
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
        border: _inputBorder(c.border),
        enabledBorder: _inputBorder(c.border),
        focusedBorder: _inputBorder(c.ink, width: 1.5),
        errorBorder: _inputBorder(c.danger),
        focusedErrorBorder: _inputBorder(c.danger, width: 1.5),
        disabledBorder: _inputBorder(c.border),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Corners.card),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onInk),
        shape: shape,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.ink,
        linearTrackColor: c.border,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(c.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.ink : c.borderStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: Corners.control,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Digits that keep a fixed width, so totals do not jitter as they change and
/// columns of money line up.
extension MoneyStyle on TextStyle {
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
