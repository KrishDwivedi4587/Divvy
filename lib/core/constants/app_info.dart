/// Facts about the app shown on the About screen.
///
/// [appVersion] must match `version:` in pubspec.yaml; a test enforces it, so
/// the version shown to the user cannot drift from the one that was built.
abstract final class AppInfo {
  static const String name = 'Divvy';
  static const String appVersion = '1.0.0';
  static const String tagline = 'Split a restaurant bill fairly, to the paisa.';
}
