/// Participant rules: pure, so the people screens stay thin views.
///
/// Pure Dart. Imports nothing from Flutter, the database or the UI.
library;

/// The most people one bill can be split between.
///
/// The prototype capped bills at 8 because its avatar palette had 8 colours.
/// The redesigned avatars no longer depend on colour, so the cap is now 12,
/// which the engine's split fuzz test already covers (1..12 people).
const int maxPeople = 12;

/// The longest a person's name may be, in characters.
const int maxNameLength = 24;

final RegExp _notLetterOrDigit = RegExp(r'[^\p{L}\p{N}]', unicode: true);
final RegExp _whitespaceRuns = RegExp(r'\s+');

/// One or two characters for an avatar: the first letter of the first two words
/// ("Raj Patel" -> "RP"), or the first two letters of a single word
/// ("Priya" -> "PR"). An empty or symbol-only name gives "?".
String initialsFor(String name) {
  final words = name
      .trim()
      .split(_whitespaceRuns)
      .map((w) => w.replaceAll(_notLetterOrDigit, '').runes.toList())
      .where((chars) => chars.isNotEmpty)
      .toList();

  if (words.isEmpty) return '?';

  final picked = words.length == 1
      ? words.first.take(2).toList()
      : [words[0].first, words[1].first];

  return String.fromCharCodes(picked).toUpperCase();
}

/// Why a name was not accepted.
enum NameCheckFailure { empty, duplicate, tooLong, limit }

sealed class NameCheck {
  const NameCheck();
}

final class NameOk extends NameCheck {
  const NameOk(this.name);
  final String name;
}

final class NameRejected extends NameCheck {
  const NameRejected(this.reason);
  final NameCheckFailure reason;
}

/// Tidies a typed name: trims it and collapses runs of whitespace.
String tidyName(String raw) => raw.trim().replaceAll(_whitespaceRuns, ' ');

/// Validates a name before it is added. Names are compared case-insensitively:
/// two rows called "raj" and "Raj" would make a summary ambiguous.
NameCheck checkPersonName(
  String raw,
  List<String> existingNames, {
  int max = maxPeople,
}) {
  final name = tidyName(raw);

  if (existingNames.length >= max) {
    return const NameRejected(NameCheckFailure.limit);
  }
  if (name.isEmpty) return const NameRejected(NameCheckFailure.empty);
  if (name.runes.length > maxNameLength) {
    return const NameRejected(NameCheckFailure.tooLong);
  }

  final key = name.toLowerCase();
  if (existingNames.any((n) => n.toLowerCase() == key)) {
    return const NameRejected(NameCheckFailure.duplicate);
  }

  return NameOk(name);
}
