import 'package:sqflite/sqflite.dart';

import '../../core/utils/currency.dart';
import '../../features/account/domain/app_settings.dart';

class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._db);

  final Database _db;

  static const _currencyKey = 'currency';
  static const _themeKey = 'theme_mode';
  static const _autoReadKey = 'auto_read_receipts';

  @override
  Future<AppSettings> load() async {
    final rows = await _db.query('settings');
    final values = {
      for (final r in rows) r['key']! as String: r['value']! as String,
    };
    return AppSettings(
      currency: Currency.fromCode(values[_currencyKey]),
      themeMode: AppThemeMode.fromWire(values[_themeKey]),
      // On unless the user turned it off.
      autoReadReceipts: values[_autoReadKey] != 'false',
    );
  }

  Future<void> _put(String key, String value) {
    return _db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> setCurrency(Currency currency) =>
      _put(_currencyKey, currency.code);

  @override
  Future<void> setThemeMode(AppThemeMode mode) =>
      _put(_themeKey, mode.wireName);

  @override
  Future<void> setAutoReadReceipts(bool value) =>
      _put(_autoReadKey, value.toString());
}
