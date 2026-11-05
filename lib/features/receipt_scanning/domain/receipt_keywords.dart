/// What a receipt row is, judged from its label.
///
/// This is deliberately a short list of plain patterns rather than anything
/// clever: it has to be predictable and testable, and when it is wrong the
/// review screen is where the user corrects it.
library;

enum RowKind {
  subtotal,
  total,
  tax,
  service,
  discount,
  tip,
  roundOff,
  otherCharge,
  header,
  skip,
  item,
}

/// Lower-cases and replaces punctuation with spaces so "S.GST @2.5%" and
/// "s gst 2 5" are both matchable; keeps % because a rate marks a charge.
String normaliseLabel(String label) => label
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9%]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final RegExp _subtotal = RegExp(
  r'\bsub ?total\b|\bgross (amount|total)\b|\bitems? total\b|'
  r'\btotal before tax\b|\btaxable (value|amount)\b|\bnet sales\b',
);
final RegExp _tip = RegExp(r'\b(tip|gratuity)\b');
final RegExp _roundOff = RegExp(
  r'\bround(ed|ing)? ?off\b|\brounding\b|\badjustment\b',
);
final RegExp _discount = RegExp(
  r'\b(discount|disc|coupon|promo|promotion|cashback|loyalty|savings?)\b',
);
final RegExp _serviceTax = RegExp(r'\bservice tax\b');
final RegExp _service = RegExp(
  r'\b(service|svc)( ?(charge|charges|chg|chrg|fee))?\b|\bs ?c\b',
);
final RegExp _tax = RegExp(
  r'\b(c ?gst|s ?gst|i ?gst|u ?gst|gst|vat|tax|cess|sales tax)\b',
);
final RegExp _notATotal = RegExp(
  r'\btotal (qty|quantity|items?|tax|gst|cgst|sgst|discount|savings?|pax|covers|amount saved)\b',
);
final RegExp _total = RegExp(
  r'\b(grand total|total amount|net payable|net amount|net total|amount payable|'
  r'amount due|total payable|total due|bill total|balance due|total|payable)\b',
);
final RegExp _otherCharge = RegExp(
  r'\b(packing|packaging|container|delivery|convenience|platform|handling|'
  r'parcel|surcharge|charges?|fee)\b',
);
final RegExp _header = RegExp(
  r'^(item|items|description|particulars?|qty|quantity|rate|price|amount|amt|sl no|s no)( |$)',
);
final RegExp _tableNumber = RegExp(r'\b(table|tbl)( ?(no|number))? ?\d+\b');
final RegExp _skip = RegExp(
  r'\b(gstin|gst no|fssai|invoice|inv no|bill no|bill number|receipt|order|'
  r'pax|covers|kot|token|cashier|waiter|server|captain|steward|date|time|'
  r'phone|tel|mob|mobile|email|www|thank|thanks|visit|welcome|paid|cash|card|upi|'
  r'change|tender|customer|cust|address|road|street|floor|opp|near)\b',
);

/// Classifies a row from the words before its amount.
///
/// Summary kinds win over [RowKind.skip], and [RowKind.item] is the default: it
/// is the parser, not this function, that decides whether a row is really an
/// item (it needs a plausible amount).
RowKind _classifyExact(String label) {
  final n = normaliseLabel(label);
  if (n.isEmpty) return RowKind.item;

  if (_subtotal.hasMatch(n)) return RowKind.subtotal;
  if (_tip.hasMatch(n)) return RowKind.tip;
  if (_roundOff.hasMatch(n)) return RowKind.roundOff;
  if (_serviceTax.hasMatch(n)) return RowKind.tax;
  if (_discount.hasMatch(n)) return RowKind.discount;
  if (_service.hasMatch(n)) return RowKind.service;
  if (_tax.hasMatch(n)) return RowKind.tax;
  if (_total.hasMatch(n) && !_notATotal.hasMatch(n)) return RowKind.total;
  if (_otherCharge.hasMatch(n)) return RowKind.otherCharge;
  if (_header.hasMatch(n)) return RowKind.header;
  if (_skip.hasMatch(n) || _tableNumber.hasMatch(n)) return RowKind.skip;
  return RowKind.item;
}

/// True for the labels that name the final payable amount outright, as opposed
/// to a bare "Total" that might be a column total.
bool isStrongTotalLabel(String label) => RegExp(
  r'\b(grand total|net payable|amount payable|amount due|total payable|'
  r'bill total|balance due|total due)\b',
).hasMatch(normaliseLabel(label));

/// Fixes digits a recogniser commonly writes in place of letters, but only
/// inside words that also contain letters, so a price or "300ml" is untouched:
/// "T0TAL" becomes "TOTAL" and "CG5T" becomes "CGST".
String _repairLookalikes(String label) {
  return label
      .split(' ')
      .map((word) {
        final letters = RegExp(r'[A-Za-z]').allMatches(word).length;
        final digits = RegExp(r'[015]').allMatches(word).length;
        if (letters < 2 || digits == 0) return word;
        return word
            .replaceAll('0', 'o')
            .replaceAll('1', 'l')
            .replaceAll('5', 's');
      })
      .join(' ');
}

const Set<RowKind> _repairable = {
  RowKind.subtotal,
  RowKind.total,
  RowKind.tax,
  RowKind.service,
  RowKind.discount,
  RowKind.tip,
  RowKind.roundOff,
};

/// Classifies a row from the words before its amount.
///
/// Summary kinds win over [RowKind.skip], and [RowKind.item] is the default: it
/// is the parser, not this function, that decides whether a row is really an
/// item (it needs a plausible amount). A label that looks like an item is tried
/// once more with digit/letter lookalikes repaired, so a misread "T0TAL" is
/// still a total and not a purchase.
RowKind classifyLabel(String label) {
  final exact = _classifyExact(label);
  if (exact != RowKind.item) return exact;
  final repaired = _classifyExact(_repairLookalikes(label));
  return _repairable.contains(repaired) ? repaired : exact;
}
