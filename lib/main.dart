import 'dart:async';

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'shared/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Divvy is designed for a phone held upright.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  // The font's licence is shown on the About screen's licences page.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Inter',
    ], await rootBundle.loadString('assets/fonts/Inter-LICENSE.txt'));
  });

  try {
    final database = await AppDatabase.open(
      path: await AppDatabase.defaultPath(),
    );
    final documents = await getApplicationDocumentsDirectory();

    runApp(
      ProviderScope(
        // A failed database read should show an error, not retry forever.
        retry: (count, error) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          receiptRootProvider.overrideWithValue(documents),
        ],
        child: const DivvyApp(),
      ),
    );
  } on Object catch (error) {
    runApp(_StartupFailure(error: error));
  }
}

/// Shown if the database cannot be opened, instead of a blank screen.
class _StartupFailure extends StatelessWidget {
  const _StartupFailure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Divvy couldn't start",
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  "The app's storage could not be opened. Close Divvy and "
                  'open it again. If this keeps happening, restart your '
                  'phone.',
                ),
                const SizedBox(height: 16),
                Text('$error', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
