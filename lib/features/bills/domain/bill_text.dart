/// Words for bills: labels, counts and the plain-text summary people can copy
/// into a group chat. Pure functions of a bill and its settlement.
library;

import '../../../core/utils/currency.dart';
import 'engine/money.dart';
import 'engine/percent.dart';
import 'models/bill.dart';
import 'models/bill_record.dart';
import 'models/settlement.dart';

/// "3 Nov 2026". Built by hand rather than with a locale library so it is the
/// same on every device and in every test.
String formatShortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// "Tax · 5%" for a percentage, just the label for a flat amount.
String adjustmentLabel(Adjustment a) {
  if (a.mode == AdjustmentMode.percent) {
    return '${a.label} · ${formatPercent(a.value.abs())}';
  }
  return a.label;
}

/// "1 person", "2 people".
String peopleCount(int n) => n == 1 ? '1 person' : '$n people';

String _splitDescription(SplitMode mode, int people) => switch (mode) {
  SplitMode.equal => 'split equally between ${peopleCount(people)}',
  SplitMode.byItem => 'split by item between ${peopleCount(people)}',
  SplitMode.custom => 'split by amounts between ${peopleCount(people)}',
};

/// A plain-text summary of a saved bill, for the clipboard or a share sheet.
///
/// Text is the share path that cannot fail: it needs no image rendering and no
/// extra plugin, and in a group chat it can be copied and searched.
String buildShareText(BillRecord record, Settlement settlement) {
  final currency = record.currency;
  String money(Paise amount) => formatMoney(amount, currency);

  final names = {for (final p in record.participants) p.id: p.name};
  final labels = {for (final a in record.adjustments) a.id: adjustmentLabel(a)};

  final lines = <String>[
    'Divvy · ${record.title}',
    formatShortDate(record.billDate),
    '',
    'Total ${money(settlement.grandTotal)}, '
        '${_splitDescription(record.splitMode, record.participants.length)}',
  ];

  final payer = record.payer;
  if (payer != null) lines.add('Paid by ${payer.name}');
  lines.add('');

  for (final person in settlement.perPerson) {
    lines.add('${names[person.personId] ?? 'Unknown'}: ${money(person.total)}');
  }

  lines
    ..add('')
    ..add('Subtotal: ${money(settlement.itemsSubtotal)}');
  for (final adjustment in settlement.adjustmentTotals) {
    lines.add(
      '${labels[adjustment.adjustmentId] ?? 'Charge'}: '
      '${money(adjustment.amount)}',
    );
  }
  return lines.join('\n');
}
