import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/data/repositories/sqlite_settings_repository.dart';
import 'package:divvy/features/account/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

void main() {
  test('defaults to rupees and following the system theme', () async {
    final app = await openTestDatabase();
    final settings = await SqliteSettingsRepository(app.db).load();
    expect(settings.currency, Currency.inr);
    expect(settings.themeMode, AppThemeMode.system);
    await app.close();
  });

  test('saves and reloads each preference independently', () async {
    final app = await openTestDatabase();
    final repo = SqliteSettingsRepository(app.db);

    await repo.setCurrency(Currency.usd);
    var s = await repo.load();
    expect(s.currency, Currency.usd);
    expect(s.themeMode, AppThemeMode.system);

    await repo.setThemeMode(AppThemeMode.dark);
    await repo.setCurrency(Currency.gbp);
    s = await repo.load();
    expect(s.currency, Currency.gbp);
    expect(s.themeMode, AppThemeMode.dark);
    await app.close();
  });

  test('ignores an unrecognised stored value instead of crashing', () async {
    final app = await openTestDatabase();
    await app.db.insert('settings', {'key': 'theme_mode', 'value': 'neon'});
    expect(
      (await SqliteSettingsRepository(app.db).load()).themeMode,
      AppThemeMode.system,
    );
    await app.close();
  });
}
