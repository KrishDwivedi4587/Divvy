/// Every route in the app, in one place. Screens navigate with these constants
/// and helpers rather than writing path strings, so a path can change in one
/// place and a typo is a compile error.
abstract final class AppRoutes {
  // The four tabs.
  static const String home = '/';
  static const String history = '/history';
  static const String people = '/people';
  static const String account = '/account';

  // The Create Bill flow, one route per step.
  static const String create = '/create';
  static const String createPreview = '/create/preview';
  static const String createReview = '/create/review';
  static const String createPeople = '/create/people';
  static const String createSplit = '/create/split';
  static const String createSummary = '/create/summary';

  // Secondary account pages.
  static const String privacy = '/account/privacy';
  static const String about = '/account/about';

  // Detail pages, with their path parameters.
  static const String billPattern = '/bills/:billId';
  static const String personPattern = '/people/:personId';

  static String bill(String id) => '/bills/$id';
  static String person(String id) => '/people/$id';
}
