import '../../../core/utils/currency.dart';

/// Light, dark, or follow the phone.
enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemeMode(this.wireName);
  final String wireName;

  static AppThemeMode fromWire(String? value) =>
      values.firstWhere((m) => m.wireName == value, orElse: () => system);
}

/// The preferences that change how the app behaves.
class AppSettings {
  const AppSettings({
    this.currency = Currency.inr,
    this.themeMode = AppThemeMode.system,
  });

  /// The currency new bills start in.
  final Currency currency;
  final AppThemeMode themeMode;

  AppSettings copyWith({Currency? currency, AppThemeMode? themeMode}) {
    return AppSettings(
      currency: currency ?? this.currency,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> setCurrency(Currency currency);
  Future<void> setThemeMode(AppThemeMode mode);
}
