import 'package:divvy/features/receipt_scanning/domain/parsed_receipt.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_parser.dart';
import 'package:divvy/features/receipt_scanning/domain/recognized_text.dart';

import 'receipt_fixtures.dart';

final DateTime parserNow = DateTime(2026, 11, 20);

ParsedReceipt parseRows(List<RowSpec> rows, {double tilt = 0}) =>
    const ReceiptParser().parse(
      layout(rows, tiltDegrees: tilt),
      now: parserNow,
    );

ParsedReceipt parseText(String text) => const ReceiptParser().parse(
  RecognizedText.fromPlainText(text),
  now: parserNow,
);

/// Parses receipt text given as a list of rows.
ParsedReceipt parseLines(List<String> rows) => parseText(rows.join('\n'));

/// The items as (name, quantity, line total in paise), for compact assertions.
List<(String, int, int)> itemSummary(ParsedReceipt r) => [
  for (final i in r.items) (i.name, i.quantity, i.lineTotal.value),
];

/// The charges as (kind, signed amount in paise).
List<(String, int)> chargeSummary(ParsedReceipt r) => [
  for (final c in r.charges) (c.kind.wireName, c.signed.value),
];
