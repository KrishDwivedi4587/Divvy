# The Money Model

How Divvy calculates who owes what, and why it is exact rather than
approximately right. Implemented in `src/core/`, specified by roadmap §8.

Established in Phase 1.

---

## The guarantee

> **Σ everyone's final amount === the bill total. Exactly. Every time.**

Formally, and as asserted on every settlement:

```
Σ perPerson.total  ===  grandTotal − unassignedAmount
```

Once every item is assigned — which the app requires before settling —
`unassignedAmount` is zero and this collapses to the plain statement above.

This is not achieved by rounding carefully. It is achieved by construction: no
step in the pipeline is capable of creating or destroying a paisa.

---

## 1. Money is an integer

All money is **integer paise**. `₹123.45` is `12345`.

Floating point cannot hold this guarantee — `0.1 + 0.2 !== 0.3` — so no float
touches a money value anywhere, including at the persistence layer, where the
SQLite columns are `INTEGER`.

`Paise` is a _branded_ type (`number & { readonly [brand]: true }`), so passing
a raw number where money is expected is a compile error. That turns the classic
rupees-versus-paise hundred-fold bug into something the type checker catches.

Percentages are **basis points**: 5% is `500`, 18% is `1800`. Integral, so a tax
rate is never `0.05000000000000001`.

---

## 2. Rounding — one rule, one place

**Half away from zero, to whole paise, applied only when converting a percentage
into an amount.** Nothing else in the engine rounds.

```
percentOf(amount, basisPoints) = round_half_away_from_zero(amount × bp / 10000)
```

Two consequences worth stating:

- There cannot be two rounding rules that disagree, because there is only one
  rounding site.
- _Away from zero_ rather than _up_ keeps `f(−x) = −f(x)`, which is what makes
  the discount path an exact mirror of the charge path.

Everything downstream of that single rounding is exact integer arithmetic.

---

## 3. Splitting one item

```
splitItem(lineTotal, assignees) →
    base      = floor(lineTotal / k)
    remainder = lineTotal − base × k          (0 ≤ remainder < k)
    sort assignees by id
    the first `remainder` assignees get base + 1; the rest get base
```

₹100.00 across three people is **3334 / 3333 / 3333** — summing to exactly 10000. One person pays a single extra paisa.

Sorting by id makes that deterministic: the same bill always produces the same
answer, so "why did Aarav pay a paisa more?" has a real answer rather than being
a mystery. An item with no assignees returns nothing and its value becomes
`unassignedAmount`, rather than being quietly absorbed by somebody.

---

## 4. Apportioning a charge — largest remainder

This is where naive implementations lose money. Each person's exact share of a
tax is fractional; rounding each one independently produces a total that misses
the real charge by a few paise.

Divvy uses the **largest-remainder (Hamilton) method**:

```
apportion(A, weights) →
    W          = Σ weights
    if W = 0   → fall back to equal weights
    floorᵢ     = floor(A × wᵢ / W)
    remainderᵢ = (A × wᵢ) mod W              exact integer, no float
    leftover   = A − Σ floorᵢ                (0 ≤ leftover < n)
    give one extra paisa to the `leftover` largest remainders
    ties break by id ascending
```

Everyone receives their floor, and the leftover paise go to whoever flooring cut
most. **Σ result === A, exactly, always.**

Products `A × wᵢ` are checked against `Number.MAX_SAFE_INTEGER` before being
computed, so precision loss above 2⁵³ raises an error instead of silently
corrupting a total.

### The negative-amount trap

A discount must **not** be pushed through this with a negative `A`.
`Math.floor(−7 / 3)` is `−3`, not `−2`; the floors overshoot, `leftover` goes
negative, and the totals stop reconciling.

The only safe formulation, and the one implemented:

```
apportionSigned(A, w, isNegative) = isNegative
    ? apportion(|A|, w).map(negate)
    : apportion(A, w)
```

There is a test named for this specifically.

### Weights are clamped at zero

A discount can push a person's running base below zero. A proportional share of
a _negative_ weight is meaningless — it would hand that person a negative slice
of a positive charge — so weights are clamped at zero and such a person simply
receives none of the next proportional adjustment.

This was found by the property test, not by inspection.

---

## 5. Adjustments are an ordered list

Not two hardcoded fields. Each adjustment carries:

| Field        | Meaning                                        |
| ------------ | ---------------------------------------------- |
| `mode`       | `percent` (basis points) or `amount` (paise)   |
| `order`      | Ascending; the sequence charges are applied in |
| `base`       | `itemsSubtotal` or `runningTotal`              |
| `isNegative` | True for discounts                             |

This exists because a real Indian restaurant bill charges **GST on
(items + service charge)**, not on items alone. Modelling order and base
explicitly makes that fall out correctly rather than being special-cased, and it
generalises to discounts and tips at no extra cost.

Service-charge-then-GST and GST-then-service produce genuinely different totals.
Both reconcile.

---

## 6. The full settlement

```
1. itemsSubtotal   = Σ every item.lineTotal          (assigned or not)
2. for each item   : shares = splitItem(lineTotal, assignees)
3. person.subtotal = Σ their shares
4. unassignedAmount = Σ lineTotal where assignees = ∅
5. runningBase = person.subtotal[]
   for each adjustment in `order`:
       pool   = base = 'itemsSubtotal' ? itemsSubtotal : Σ runningBase
       A      = mode = 'percent' ? percentOf(pool, value) : value
       shares = apportionSigned(A, clamp₀(runningBase), isNegative)
       runningBase += shares
6. person.total = person.subtotal + Σ their adjustment shares
7. grandTotal   = itemsSubtotal + Σ adjustment amounts
8. reconciles   = (Σ person.total === grandTotal − unassignedAmount)
```

Step 8 is computed and returned on every settlement, not assumed. The UI treats
`reconciles === false` as a visible error state rather than displaying money it
cannot justify.

---

## 7. Worked example

Three people, four items, service charge 5% on items, GST 5% on
(items + service). Verified against the implementation in `settle.test.ts`.

```
itemsSubtotal = 34000 + 28000 + 15000 + 16000 = 93000        (₹930.00)

Item splits (ids sorted, so remainders go to Aarav first)
  Paneer  34000 / 2 → Aarav 17000, Priya 17000
  Dal     28000 / 3 → 9334, 9333, 9333
  Coffee  15000 / 1 → Zoya 15000
  Naan    16000 / 3 → 5334, 5333, 5333

Subtotals   Aarav 31668   Priya 31666   Zoya 29666      Σ = 93000 ✓

Service 5% of 93000 = 4650
  floors 1583/1583/1483 (Σ 4649), leftover 1 → largest remainder → Aarav
  → 1584, 1583, 1483                                    Σ = 4650 ✓
  running 33252, 33249, 31149                           Σ = 97650 ✓

GST 5% of 97650 = 4882.5 → 4883 (half away from zero)
  floors 1662/1662/1557 (Σ 4881), leftover 2 → Aarav, Priya
  → 1663, 1663, 1557                                    Σ = 4883 ✓

Totals      Aarav ₹349.15   Priya ₹349.12   Zoya ₹327.06
            Σ = 102533  =  93000 + 4650 + 4883  =  grandTotal ✓
```

Note what happened: the service charge left one stray paisa and GST left two. In
both cases largest-remainder placed them deterministically rather than letting
them evaporate. Aarav pays ₹0.03 more than Priya for a fully explainable reason
— he sorted first on two remainder distributions.

---

## 8. Formatting

`formatPaise(10000000)` → `"₹1,00,000.00"` — Indian digit grouping (last three
digits, then groups of two).

Implemented directly rather than via `Intl.NumberFormat('en-IN')`: Hermes ships
a reduced Intl on some Android builds, and ICU versions differ on whether a
non-breaking space follows the symbol. Money has to render identically on every
device and in every test, so ten lines beats depending on the platform's ICU.

Parsing never uses `parseFloat`. The integer and fractional parts are read as
digit strings and combined with integer arithmetic, so no float ever touches a
money value even transiently.

---

## 9. Errors

Two deliberately different strategies:

- **Invalid domain data throws `DomainError`** with a typed `code`
  (`UNKNOWN_PERSON`, `DUPLICATE_ID`, `NEGATIVE_AMOUNT`, …). It means a bug
  upstream, and failing loudly beats returning plausible but wrong money.
- **Invalid user input returns a typed result** (`parseAmount` →
  `{ ok: false, reason }`). The UI has to render an inline message, not crash.

---

## 10. How this is proven

| Test                              | What it establishes                                                                   |
| --------------------------------- | ------------------------------------------------------------------------------------- |
| `money.test.ts`                   | Parsing, Indian formatting, the single rounding rule, 10,000-value format round-trip  |
| `splitItem.test.ts`               | Exactness and determinism; fuzz over 1–12 people × 500 amounts                        |
| `apportion.test.ts`               | Largest remainder, tie-breaking, 10,000-pair fuzz, and the named negative-amount trap |
| `settle.test.ts`                  | The worked example to the paisa, ordering, discounts, unassigned items, validation    |
| `reconciliation.property.test.ts` | **1,000 generated bills; the invariant holds exactly on every one**                   |

The property test generator is seeded, so a failure reports the seed and is
reproducible rather than a one-off ghost.

None of these need Android, Expo, Metro, a device or a network. That is the
whole point of keeping `src/core/` free of framework imports: the part of the
project that must be _provably_ right is the part that can be proven fastest.
