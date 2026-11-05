/// Finding the date on a receipt.
///
/// Receipts print dates every way there is: 14/11/2026, 14-11-26, 2026-11-14,
/// 14 Nov 2026, Nov 14, 2026. Numeric dates are read day-first, which is how
/// Indian receipts print them, and flagged as ambiguous when they could equally
/// be month-first.
library;

class DateReading {
  const DateReading(this.date, {required this.ambiguous});

  final DateTime date;

  /// Both day-first and month-first are valid dates and they differ.
  final bool ambiguous;
}

const Map<String, int> _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

final RegExp _iso = RegExp(r'(?<!\d)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)');
final RegExp _numeric = RegExp(
  r'(?<!\d)(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})(?!\d)',
);
final RegExp _dayMonthName = RegExp(
  r'(?<!\d)(\d{1,2})(?:st|nd|rd|th)?[\s.,/-]+'
  r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?[\s.,/-]+'
  r'(\d{4}|\d{2})(?!\d)',
  caseSensitive: false,
);
final RegExp _monthNameDay = RegExp(
  r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+'
  r'(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})(?!\d)',
  caseSensitive: false,
);

int _fullYear(String y) => y.length == 2 ? 2000 + int.parse(y) : int.parse(y);

DateTime? _valid(int year, int month, int day, int maxYear) {
  if (year < 2000 || year > maxYear) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final d = DateTime(year, month, day);
  // DateTime rolls 31 Feb over into March; reject that.
  return d.month == month && d.day == day ? d : null;
}

/// Finds the first plausible date in [text], or null. Years before 2000 or
/// after [maxYear] are rejected as misreads (a phone number, a bill number).
DateReading? findDate(String text, {required int maxYear}) {
  final iso = _iso.firstMatch(text);
  if (iso != null) {
    final d = _valid(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
      maxYear,
    );
    if (d != null) return DateReading(d, ambiguous: false);
  }

  final named = _dayMonthName.firstMatch(text);
  if (named != null) {
    final d = _valid(
      _fullYear(named.group(3)!),
      _months[named.group(2)!.toLowerCase()]!,
      int.parse(named.group(1)!),
      maxYear,
    );
    if (d != null) return DateReading(d, ambiguous: false);
  }

  final reversed = _monthNameDay.firstMatch(text);
  if (reversed != null) {
    final d = _valid(
      int.parse(reversed.group(3)!),
      _months[reversed.group(1)!.toLowerCase()]!,
      int.parse(reversed.group(2)!),
      maxYear,
    );
    if (d != null) return DateReading(d, ambiguous: false);
  }

  for (final m in _numeric.allMatches(text)) {
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    final year = _fullYear(m.group(3)!);

    final dayFirst = _valid(year, b, a, maxYear);
    final monthFirst = _valid(year, a, b, maxYear);
    if (dayFirst != null && monthFirst != null && a != b) {
      return DateReading(dayFirst, ambiguous: true);
    }
    if (dayFirst != null) return DateReading(dayFirst, ambiguous: false);
    if (monthFirst != null) return DateReading(monthFirst, ambiguous: false);
  }
  return null;
}
