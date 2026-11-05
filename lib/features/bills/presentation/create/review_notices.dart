import 'package:flutter/material.dart';

import '../../../../core/constants/spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/notice.dart';
import '../../../receipt_scanning/application/scan_notifier.dart';
import '../../../receipt_scanning/domain/parsed_receipt.dart';
import '../../domain/engine/money.dart';

/// The messages shown at the top of the review, from how the scan went and how
/// the totals compare. Each is something the user can act on.
List<Widget> reviewNotices({
  required ScanState scan,
  required Paise? stated,
  required Paise computed,
  required Currency currency,
}) {
  final out = <Widget>[];
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
        add(
          const Notice(
            message:
                'Divvy read this from your photo. Check it against the '
                'receipt and correct anything that is wrong.',
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
    case ScanIdle() || Scanning():
      break;
  }

  if (stated != null && stated != computed) {
    add(
      Notice(
        tone: NoticeTone.warning,
        title: 'Total does not match',
        message:
            'The receipt says ${formatMoney(stated, currency)}, but the '
            'items and charges add up to ${formatMoney(computed, currency)}. '
            'Look for a missing or misread line.',
      ),
    );
  }
  return out;
}
