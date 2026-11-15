# The calculation engine

How Divvy works out who owes what, and why the answer is exact rather than
approximately right. The engine is pure Dart in
`lib/features/bills/domain/engine/`, with no Flutter, database or UI imports
(a test enforces this).

It is a port of the TypeScript engine from the original React Native prototype
(tag `v0.1-m1-engine`). The rules are unchanged; what differs is listed in
[Parity with the original](#parity-with-the-original).

---

## The guarantee

> **The sum of everyone's final amount equals the bill total. Exactly. Every time.**

Formally, and asserted on every settlement:

```
sum(perPerson.total) == grandTotal - unassignedAmount
```

Once every item is assigned (which the app requires before saving),
`unassignedAmount` is zero and this is simply "everyone's amounts add up to the
total".

This is not achieved by rounding carefully. It is achieved by construction: no
step is capable of creating or destroying a paisa.

---

## 1. Money is an integer

All money is **integer minor units**: paise for rupees, cents for dollars.
Rs 123.45 is `12345`. No `double` touches a money value anywhere, including the
database, where money columns are `INTEGER`.

`Paise` is a Dart **extension type** over `int`, so passing a bare `int` where
money is expected is a compile error. That turns the classic
rupees-versus-paise hundred-fold bug into something the analyzer catches, at no
runtime cost.

Percentages are **basis points**: 5% is `500`, 18% is `1800`. A tax rate is
never `0.05000000000000001`.

The engine keeps JavaScript's safe-integer limit (2^53 - 1) as its bound on any
product, so the same code stays exact if it were ever compiled to the web.
Products are checked before they are computed.

---

## 2. Rounding: one rule, one place

**Half away from zero, to whole paise, applied only when converting a
percentage into an amount.** Nothing else in the engine rounds.

```
percentOf(amount, bp) = round_half_away_from_zero(amount * bp / 10000)
```

There cannot be two rounding rules that disagree, because there is only one
place that rounds. "Away from zero" rather than "up" keeps `f(-x) == -f(x)`,
which makes the discount path an exact mirror of the charge path. Everything
after it is exact integer arithmetic.

---

## 3. Splitting one item

```
splitItem(lineTotal, assignees):
  base      = floor(lineTotal / k)
  remainder = lineTotal - base * k            (0 <= remainder < k)
  sort assignees by id
  the first `remainder` assignees get base + 1; the rest get base
```

Rs 100.00 across three people is **3334 / 3333 / 3333**, summing to exactly
10000. Sorting by id makes it deterministic: the same bill always gives the same
answer, so "why did Aarav pay a paisa more?" has a real answer. An item nobody
has returns nothing; its value becomes `unassignedAmount` rather than being
quietly absorbed by someone.

---

## 4. Apportioning a charge: largest remainder

This is where naive code loses money. Each person's exact share of a tax is
fractional; rounding each independently misses the real charge by a few paise.
Divvy uses the **largest-remainder (Hamilton) method**:

```
apportion(A, weights):
  W           = sum(weights)            (all zero -> equal weights)
  floor_i     = floor(A * w_i / W)
  remainder_i = (A * w_i) mod W         exact integer, no double
  leftover    = A - sum(floor_i)        (0 <= leftover < n)
  one extra paisa to the `leftover` largest remainders; ties by id ascending
```

Everyone gets their floor and the leftover paise go to whoever flooring cut
most. `sum(result) == A`, exactly, always.

### The negative-amount trap

A discount must not be pushed through `apportion` as a negative number: floor
division of a negative number rounds *away* from zero (floor(-7 / 3) is -3, not
-2), so the floors overshoot, `leftover` goes negative and the totals stop
reconciling. The only safe form, and the one implemented, is to apportion the
magnitude and negate afterwards (`apportionSigned`). Tests are named for it.

### Weights are clamped at zero

A big discount can push a person's running base below zero. A proportional share
of a *negative* weight is meaningless (it would hand them a negative slice of a
positive charge), so weights are clamped at zero and that person receives none of
the next proportional adjustment. This was found by the property test, not by
inspection.

---

## 5. Adjustments are an ordered list

Not two hard-coded fields. Each carries a mode (`percent` as basis points, or a
fixed `amount`), an `order`, a `base` (`itemsSubtotal` or `runningTotal`) and
whether it is negative.

This exists because a real Indian restaurant bill charges **GST on (items plus
service charge)**, not on items alone. Service-then-GST and GST-then-service
give genuinely different totals; both reconcile.

The app orders charges the way a restaurant bill does (`BillDraft`): discounts,
then service and other charges, then tax (on the running total), then tip.
Within a kind, entry order holds.

---

## 6. The full settlement

```
1. itemsSubtotal    = sum of every item.lineTotal      (assigned or not)
2. for each item:   shares = splitItem(lineTotal, assignees)
3. person.subtotal  = sum of their shares
4. unassignedAmount = sum of lineTotal where nobody is assigned
5. runningBase = person.subtotals
   for each adjustment in `order`:
       pool   = base == itemsSubtotal ? itemsSubtotal : sum(runningBase)
       A      = mode == percent ? percentOf(pool, value) : value
       shares = apportionSigned(A, clamp0(runningBase), isNegative)
       runningBase += shares
6. person.total = person.subtotal + sum(their adjustment shares)
7. grandTotal   = itemsSubtotal + sum(adjustment amounts)
8. reconciles   = sum(person.total) == grandTotal - unassignedAmount
```

Step 8 is computed and returned on every settlement, not assumed. The UI treats
`reconciles == false` as a visible error instead of showing money it cannot
justify.

---

## 7. Worked example

Three people, four items, 5% service charge on items, 5% GST on items plus
service. Asserted in `test/unit/engine/settle_test.dart`.

```
itemsSubtotal = 34000 + 28000 + 15000 + 16000 = 93000       (Rs 930.00)

Item splits (ids sorted, so remainders go to Aarav first)
  Paneer  34000 / 2 -> Aarav 17000, Priya 17000
  Dal     28000 / 3 -> 9334, 9333, 9333
  Coffee  15000 / 1 -> Zoya 15000
  Naan    16000 / 3 -> 5334, 5333, 5333

Subtotals   Aarav 31668   Priya 31666   Zoya 29666     sum = 93000

Service 5% of 93000 = 4650 -> 1584, 1583, 1483           sum = 4650
GST 5% of 97650 = 4882.5 -> 4883 (half away) -> 1663, 1663, 1557

Totals      Aarav 349.15   Priya 349.12   Zoya 327.06
            sum = 102533 = 93000 + 4650 + 4883 = grandTotal
```

The same bill, entered the way the receipt prints it (service 46.50 and GST 48.83
as amounts), gives the same totals through the app's draft model.

---

## 8. Split modes in the app

The engine itself only knows "items, each shared equally by whoever is assigned
to it, plus ordered adjustments". The app's three split modes are built on that
without changing it (`BillDraft`):

| Mode        | How it maps onto the engine                                                              |
| ----------- | ---------------------------------------------------------------------------------------- |
| **Equally** | Every item is assigned to everyone                                                       |
| **By item** | Each item is assigned to the people who had it                                           |
| **Amounts** | Each person's amount becomes one item only they share; charges then spread in proportion |

**Amounts is new in the Flutter version.** The original engine and prototype had
equal and by-item splitting only; no custom-amount mode existed. It is expressed
in terms of the existing engine rather than adding a new calculation, so the
reconciliation guarantee covers it too. The amounts must add up to the items
total or the bill cannot be saved.

---

## 9. Formatting and parsing

`formatPaise(Paise)` gives Indian grouping (rupee sign, then `1,00,000.00`): the
last three digits, then groups of two. It is written by hand rather than taken
from a locale library so it is identical on every device and in every test.

For display in any currency the app uses `formatMoney`
(`lib/core/utils/currency.dart`), which groups the whole part with `intl` as an
integer and appends the two-digit fraction as text. A test asserts it agrees with
`formatPaise` for 10,000 random rupee amounts.

Parsing never uses `double.parse`. The integer and fractional parts are read as
digit strings and combined with integer arithmetic.

---

## 10. Errors

- **Invalid domain data throws `DomainError`** with a typed code. It means a bug
  upstream, and failing loudly beats returning plausible but wrong money.
- **Invalid user input returns a typed result** (`parseAmount`, `parsePercent`).
  The UI has to show an inline message, not crash.

Saving is guarded twice: `BillDraft.problems` lists everything wrong with a bill
(no items, fewer than two people, an unassigned item, no payer, custom amounts
that do not add up) and `BillService.save` refuses any bill that has one.

---

## Parity with the original

The Dart engine was checked against the TypeScript engine three ways.

1. **Ported tests, case for case.** The original suites are ported, including the
   1,000-bill reconciliation property test, the 10,000-pair apportionment fuzz,
   the 12 x 500 item-split fuzz and the D7 negative-amount regression block.
2. **Same random stream.** The property test's seeded generator (Mulberry32) was
   ported and checked to produce the same numbers as the original for the same
   seeds.
3. **Differential test.** 200 bills were settled by the original TypeScript
   engine and the results saved in `test/fixtures/ts_engine_golden.json`
   (provenance in `test/fixtures/README.md`). The Dart engine settles the same
   bills, and every item share, adjustment share, subtotal and total must match
   exactly. It does.

| Suite                            | Original (Jest) | Dart | Notes                                            |
| -------------------------------- | --------------: | ---: | ------------------------------------------------ |
| money                            |              51 |   53 | adds a too-large amount and a safe-range case    |
| splitItem                        |              12 |   12 | includes the 12 x 500 fuzz                       |
| apportion                        |              21 |   21 | includes the 10,000-pair fuzz and the D7 block   |
| settlement                       |              39 |   40 | adds a duplicate-adjustment-id case              |
| reconciliation property          |               5 |    6 | 1,000 generated bills; adds a generator-stream check |
| input helpers (amount, %, names) |              63 |   63 |                                                  |
| differential vs TypeScript       |               - |    2 | new                                              |

Differences, all intentional and tested:

- **Maximum people is 12, not 8.** The cap existed because the prototype's avatar
  palette had eight colours. The new avatars do not depend on colour, and the
  split fuzz already covers up to 12 people.
- **Type-enforced checks.** A fractional paisa or a negative zero cannot exist in
  Dart integers. The original tests for those become construction-time checks on
  `toPaise` or are noted as not applicable; none was dropped silently.
- **Exact integer division.** Dart's `~/` is exact; the original used a
  floating-point divide then floor. They agree everywhere division is exact,
  which is every realistic amount (the 200-bill differential test confirms it).
- **The fuzz helper prints its seed.** The original had a latent test flake (a
  zero amount made `-0` compare unequal to `0` about 2.5% of the time). Dart
  integers cannot produce it, and the helper reports the seed on any failure so
  a failing run can be replayed (`--dart-define=FUZZ_SEED=...`).
