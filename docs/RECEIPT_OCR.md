# Receipt reading

How a photo of a receipt becomes a bill the user only has to check. The
calculation rules are in [CALCULATION_ENGINE.md](CALCULATION_ENGINE.md); the
app as a whole is in [ARCHITECTURE.md](ARCHITECTURE.md).

```
photo ──► text recogniser ──► RecognizedText ──► ReceiptParser ──► ParsedReceipt ──► BillDraft ──► Review
(image_    (ML Kit, on         (lines + where     (pure Dart,      (items, charges,   (applyParsed:  (the user
 picker)    the device)         they sit)          no plugins)      totals, warnings)  only what was   corrects)
                                                                                       found)
```

Nothing leaves the phone. The photo is kept (copied into app storage when the
bill is saved) so the original can always be opened from the bill.

## The steps

| Step | Where | Notes |
| ---- | ----- | ----- |
| Capture | `receipt_scanning/data/image_picker_photo_source.dart` | Camera or gallery. JPEG at 85%, **scaled to at most 2000 px wide** (width only, so a tall receipt keeps its legibility). No crop step: a square crop would cut the bottom off a long receipt. |
| Recognise | `receipt_scanning/data/mlkit_text_recognizer.dart` | Google ML Kit, Latin script. Runs on the platform's own thread, so the UI does not freeze. Only lines and their rotated corners are passed on. |
| Parse | `receipt_scanning/domain/receipt_parser.dart` | A pure function of `RecognizedText`, tested with fixtures instead of a camera. |
| Apply | `BillDraftNotifier.applyParsed` | Fills the draft with what the parser found. Anything it did not find is left as it was, never invented. |
| Review | `bills/presentation/create/review_screen.dart` | Every value is editable; uncertain ones are marked. |

### When reading starts

A photo is read **as soon as it is chosen** (`PreviewScreen`): the screen shows
the photo with a scanning sweep, then moves to the review. No "Read receipt" tap,
no total typed in. Rules around that:

- **Once per photo.** `_autoRead` remembers the path it started on, and coming
  back to the screen does not read it again. A retake or replacement is a new
  path and is read.
- **Never overwrites silently.** If the bill already has items (typed by hand or
  from an earlier photo), the existing "Read the receipt again?" confirmation
  is shown first. Cancelling leaves the photo waiting with a Read button.
- **A preference.** Account → "Read receipts automatically" (on by default).
  Off, the photo is shown first and reading starts on the button.
- **Never a dead end.** If recognition fails, times out (45 s) or finds nothing,
  the user still lands on the review with a plain explanation and manual entry.
  `ScanNotifier` turns every failure into a state; none is thrown at the UI.

## What the parser does

`ReceiptParser.parse` works in stages, each in its own file so a rule can be
improved without touching the others:

1. **Rows** (`recognized_text.dart`, `groupIntoRows`). Recognisers return a name
   and its price as two separate lines that only line up by position. Lines are
   put back into visual rows using their geometry, allowing for a tilted photo.
2. **Amounts** (`amount_reading.dart`). Currency prefixes, thousands separators
   (`1,234.50` and `1,00,000`), decimal commas, negatives as `-50`, `(50)` or
   `50-`, and letters read as digits. Digits are handed to the engine's
   `parseAmount`, so **no `double` touches a money value**.
3. **Row kind** (`receipt_keywords.dart`). Each row is classified as item,
   subtotal, total, tax, service, discount, tip, round-off, other charge,
   header or skip, from the words before its amount. Misread look-alikes
   (`T0TAL`, `CG5T`) are repaired.
4. **Items** (`_parseItem`). A row is an item only if it has a plausible price.
   Quantities are read from `2x Naan`, `Naan x2`, `2 Masala Dosa` (only believed
   if it divides the price) and quantity columns. Each item gets a confidence.
5. **Summary block.** Once the first summary row appears, everything below is
   read as subtotal, charges and totals, so a charge is never also an item and
   nothing is counted twice.
6. **Unit prices.** If the items only add up to the subtotal when multiplied by
   their quantities, the receipt listed unit prices; they are multiplied, and the
   user is told.
7. **Date** (`receipt_dates.dart`). `14/11/2026`, `14-11-26`, `2026-11-14`,
   `14 Nov 2026`, `Nov 14, 2026`. Numeric dates are read day-first and flagged
   when month-first is equally valid.
8. **Merchant, currency.** The first name-like row above the items; currency from
   the total row and the text.

### Choosing the total

Not "the biggest number". Candidates are the amounts on rows classified as a
total, de-duplicated and ordered by where they last appeared.

1. If any candidate has a plainly worded label (*Grand Total, Net Payable,
   Amount Payable, Amount Due, Total Payable, Bill Total, Balance Due*), only
   those are considered; otherwise all are.
2. Among those, one that equals **items + charges** wins. That is far better
   evidence than position.
3. Otherwise the bottom-most wins.
4. If several different amounts of the same standing remain and none reconciles
   (two bare "Total"s, or two different "Grand Total"s), the result carries
   `ParseWarning.multipleTotals` and `totalCandidates`. The review asks the user
   which is payable; it does not guess silently.

A plainly worded total is **not** overridden by a bare "Total" that happens to
equal the items. A receipt that prints `Total 500` then `Net Payable 1,250` has
750 of charges the parser did not read, and 1,250 is what is payable.

### Warnings

`ParsedReceipt.warnings` is how the parser says what to double-check:
`noTextFound`, `noItemsFound`, `totalNotFound`, `multipleTotals`,
`itemsDoNotMatchSubtotal`, `totalMismatch`, `dateAmbiguous`, `dateNotFound`,
`merchantNotFound`, `amountsTreatedAsUnitPrices`. The raw recogniser text and the
re-assembled rows are kept (`rawText`, `rowsText`) and shown, expandable, on the
review and on the saved bill, for checking a parse against what was printed.

## The review

The review compares the receipt's printed total with what Divvy computed from the
items and charges, and gives the user the way to resolve each situation:

| Situation | What the user sees |
| --------- | ------------------ |
| Total matches | A tick on "Printed on receipt". |
| Total differs | "Total does not match", with **Correct receipt total** (type the right one) and **Add ₹X as a charge / discount** (the gap becomes an ordinary, editable line; under ₹1 it is labelled *Round off*). |
| Several possible totals | "More than one total found", with each amount to tap. Once chosen, the question goes away. The separate mismatch notice is held back meanwhile, since it would repeat the same problem. |
| No total printed | "Enter receipt total", offered but not required. |
| Merchant or date not found | Named in the main notice; the fields are left empty, not filled in. |
| An item the reader was unsure of | "Check this line" on that row. |
| Nothing read | "No text found" / "No items found" and manual entry. |

Items, charges, merchant, date and currency are all editable; items can be added
and deleted.

## What is not done

Stated plainly, because a receipt reader is easy to oversell.

- **Only the Latin script** is recognised. Receipts in Devanagari, Tamil and other
  scripts would need the matching ML Kit script and parser keywords.
- **Layouts are handled by rules, not learning.** Common restaurant layouts
  (name and price on one row, quantity prefix or column, summary block below) are
  covered by fixtures. A receipt with an unusual structure, such as items in two
  columns, will produce warnings and need correcting, which is what the review is
  for.
- **No image pre-processing** (de-skew, contrast) beyond scaling. A tilted photo
  is handled in the geometry, but a blurred or badly lit one is only as good as
  ML Kit's reading of it.
- **Per-line confidence on iOS.** ML Kit reports it on Android only; the parser's
  own confidence is used on both.
- **Not measured on real receipts at scale.** Accuracy is tested against
  synthetic layouts and one photographed sample. It has not been measured on a
  corpus of real receipts, and there is no figure to quote.
