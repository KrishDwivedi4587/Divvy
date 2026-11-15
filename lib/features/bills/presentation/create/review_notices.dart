import 'package:flutter/material.dart';

import '../../../../core/constants/spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/notice.dart';
import '../../../receipt_scanning/application/scan_notifier.dart';
import '../../../receipt_scanning/domain/parsed_receipt.dart';
import '../../domain/engine/money.dart';

/// What the user can do about a total that does not add up, supplied by the
/// screen so these notices stay plain widgets.
class TotalActions {
  const TotalActions({
    required this.choose,
    required this.edit,
    required this.addDifference,
  });

  /// Use this amount as the receipt's total.
  final ValueChanged<Paise> choose;

  /// Type the receipt's total in.
  final VoidCallback edit;

  /// Add the gap between the receipt's total and Divvy's as a charge or
  /// discount, so the bill matches the receipt.
  final VoidCallback addDifference;
}

/// The messages shown at the top of the review, from how the scan went and how
/// the totals compare. Each is something the user can act on.
///
/// [totalConfirmed] is true once the user has picked or typed the receipt
/// total themselves, which settles the "which total?" question.
List<Widget> reviewNotices({
  required ScanState scan,
  required Paise? stated,
  required Paise computed,
  required Currency currency,
  required TotalActions actions,
  bool totalConfirmed = false,
}) {
  final out = <Widget>[];
  // While the user is being asked which total is the payable one, a separate
  // "does not match" warning would only repeat the same problem.
  var askingWhichTotal = false;
  void add(Notice n) {
    out
      ..add(n)
      ..add(const SizedBox(height: Space.md));
  }

  switch (scan) {
    case ScanFailed(:final message):
      add(Notice(tone: NoticeTone.error, message: message));
    case ScanDone(:final receipt):
      final w = receipt.warnings;
      askingWhichTotal =
          w.contains(ParseWarning.multipleTotals) && !totalConfirmed;
      if (w.contains(ParseWarning.noTextFound)) {
        add(
          const Notice(
            tone: NoticeTone.warning,
            title: 'No text found',
            message:
                "Divvy couldn't find any text in the photo. Check it is "
                'clear and well lit, or enter the bill by hand below.',
          ),
        );
      } else if (w.contains(ParseWarning.noItemsFound)) {
        add(
          const Notice(
            tone: NoticeTone.warning,
            title: 'No items found',
            message:
                'The text was read but no items could be picked out. Add '
                'them below.',
          ),
        );
      } else if (!receipt.isEmpty) {
        final missing = [
          if (w.contains(ParseWarning.merchantNotFound)) 'the merchant',
          if (w.contains(ParseWarning.dateNotFound)) 'the date',
        ];
        final it = missing.length == 1 ? 'it' : 'them';
        final gaps = missing.isEmpty
            ? ''
            : " It couldn't find ${missing.join(' or ')}: fill $it in below "
                  'if you want $it on the bill.';
        add(
          Notice(
            message:
                'Divvy read this from your photo. Check it against the '
                'receipt and correct anything that is wrong.$gaps',
          ),
        );
      }
      if (w.contains(ParseWarning.itemsDoNotMatchSubtotal)) {
        add(
          const Notice(
            tone: NoticeTone.warning,
            message:
                "The items don't add up to the subtotal printed on the "
                'receipt. Check the prices.',
          ),
        );
      }
      if (w.contains(ParseWarning.amountsTreatedAsUnitPrices)) {
        add(
          const Notice(
            tone: NoticeTone.warning,
            message:
                'The receipt listed a price per item, so prices were '
                'multiplied by the quantity to match its subtotal. Check '
                'the quantities.',
          ),
        );
      }
      if (w.contains(ParseWarning.dateAmbiguous)) {
        add(
          const Notice(
            tone: NoticeTone.warning,
            message:
                'The date could be read as day/month or month/day. Check '
                'it is right.',
          ),
        );
      }
      if (askingWhichTotal) {
        add(
          Notice(
            tone: NoticeTone.warning,
            title: 'More than one total found',
            message:
                'None of them matches the items and charges. Tap the one '
                'that is the amount payable.',
            actions: [
              for (final amount in receipt.totalCandidates)
                NoticeAction(
                  formatMoney(amount, currency),
                  () => actions.choose(amount),
                ),
            ],
          ),
        );
      }
      if (w.contains(ParseWarning.totalNotFound) &&
          stated == null &&
          receipt.items.isNotEmpty) {
        add(
          Notice(
            message:
                'No total was found on the receipt, so Divvy is adding up '
                'the items and charges. If you know the printed total, '
                'enter it to check them.',
            actions: [NoticeAction('Enter receipt total', actions.edit)],
          ),
        );
      }
    case ScanIdle() || Scanning():
      break;
  }

  if (stated != null && stated != computed && !askingWhichTotal) {
    final gap = stated - computed;
    final surplus = !gap.isNegative;
    final size = surplus ? gap : -gap;
    add(
      Notice(
        tone: NoticeTone.warning,
        title: 'Total does not match',
        message:
            'The receipt says ${formatMoney(stated, currency)}, but the '
            'items and charges add up to ${formatMoney(computed, currency)}. '
            'Look for a missing or misread line.',
        actions: [
          NoticeAction('Correct receipt total', actions.edit),
          NoticeAction(
            surplus
                ? 'Add ${formatMoney(size, currency)} as a charge'
                : 'Add ${formatMoney(size, currency)} as a discount',
            actions.addDifference,
          ),
        ],
      ),
    );
  }
  return out;
}
