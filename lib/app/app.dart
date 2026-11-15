import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_info.dart';
import '../features/account/domain/app_settings.dart';
import '../shared/providers/data_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

ThemeMode _themeModeFor(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};

/// The root widget: theme, router, and the status bar style that matches it.
class DivvyApp extends ConsumerStatefulWidget {
  const DivvyApp({this.router, super.key});

  /// Supplied by tests to start somewhere other than Home.
  final GoRouter? router;

  @override
  ConsumerState<DivvyApp> createState() => _DivvyAppState();
}

class _DivvyAppState extends ConsumerState<DivvyApp> {
  late final GoRouter _router = widget.router ?? buildRouter();

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(settingsProvider).value?.themeMode;

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeModeFor(mode ?? AppThemeMode.system),
      routerConfig: _router,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            // Android: the icon colour. iOS: the brightness of the *content
            // behind* the bar, so it is the opposite way round.
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
