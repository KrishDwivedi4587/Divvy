import '../../../core/utils/currency.dart';
import '../domain/saved_person.dart';

/// Describes what a person owes, or is owed, in words, from the account
/// holder's point of view. One line per currency; empty when settled up.
List<String> describeBalance(PersonBalance? balance) {
  if (balance == null) return const [];
  final lines = <String>[];
  for (final entry in balance.net.entries) {
    final amount = entry.value;
    if (amount.isZero) continue;
    final text = formatMoney(amount.isNegative ? -amount : amount, entry.key);
    lines.add(amount.isNegative ? 'You owe $text' : 'Owes you $text');
  }
  return lines;
}
