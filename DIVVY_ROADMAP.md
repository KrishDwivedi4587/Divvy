# DIVVY — Development Roadmap

**Owner:** KD · BSc Computer Science, UIT, Karnavati University
**Project:** Divvy — individual Mobile App Development mini project
**Window:** Tuesday 1 September 2026 → Saturday 31 October 2026 (61 days)
**Feature freeze:** Saturday 17 October 2026 — non-negotiable
**Document status:** living. Update the checkboxes. Do not rewrite the dates.

> **How to use this file.** Open it every morning. Go to §16 (Weekly Schedule), find today's week, do the tasks in order. If you are lost, go to §18 (Do Not Fall Behind) and find out how far behind you are. Everything else in this document is reference material you read once and consult when stuck.

---

## Table of contents

1. [Architecture & Scope Decisions](#1-architecture--scope-decisions) ← **read this first, it changes the brief**
2. [The Governing Reality: your actual time budget](#2-the-governing-reality-your-actual-time-budget)
3. [Critical Path Analysis](#3-critical-path-analysis)
4. [Technical Spikes](#4-technical-spikes)
5. [MVP Tiers](#5-mvp-tiers)
6. [Application Architecture](#6-application-architecture)
7. [Data Model](#7-data-model)
8. [The Calculation Engine](#8-the-calculation-engine)
9. [OCR Service Design](#9-ocr-service-design)
10. [Share Service Design](#10-share-service-design)
11. [User Journey & Screen States](#11-user-journey--screen-states)
12. [UX / Animation Roadmap](#12-ux--animation-roadmap)
13. [Testing Strategy](#13-testing-strategy)
14. [Git Workflow](#14-git-workflow)
15. [Phases](#15-phases)
16. [Weekly Schedule](#16-weekly-schedule)
17. [Milestones](#17-milestones)
18. [Do Not Fall Behind](#18-do-not-fall-behind)
19. [Final Submission State](#19-final-submission-state)
20. [Academic Submission Requirements](#20-academic-submission-requirements)
21. [Claude Code Development Protocol](#21-claude-code-development-protocol)

---

# 1. Architecture & Scope Decisions

I read the full Divvy specification and the surrounding ideation document. It is a strong brief. These are the places where it contradicts itself, under-specifies something that will bite you, or makes an assumption I think is wrong. **I have not changed the concept.** Each decision below is recorded so you can defend it in the viva, and so you know it was a decision rather than a drift.

### D1 — OCR is step 3 in your brief, but the source spec calls it post-MVP. I am siding with the source spec.

Your task description lists the core experience as: capture → OCR → review → people → assign. Read literally, OCR is the second thing the user does and therefore the second thing you build. But the same specification says, in three separate places:

- *"Do not let OCR be load-bearing."*
- Phase table: *"Camera + OCR ... Cut this entirely if phase 2 overruns."*
- Final MVP list: *"Everything else — camera capture, OCR, fractional splits, saved groups, UPI links — is explicitly post-MVP."*

**Decision.** Manual item entry is the *primary* path and gets built first. The camera is an *alternate entry point into the same review screen*. `POST /items` — conceptually — has two producers: a keyboard and a camera. The Review Items screen (S3) does not know or care which one filled it.

This is not a downgrade of the concept. It is what makes the concept survivable. It also gives you the single best line in your viva: *"OCR populates a screen that already worked without it, so an OCR failure costs the user thirty seconds, not the app."*

**Practical consequence:** OCR lives in Phase 5 (5–11 Oct), which sits immediately before the feature freeze. If you are behind on 5 October, you cut it and the app is still complete. If you build OCR first and run out of time, you have a camera and no app.

### D2 — The centre-hold two-person split cannot be the multi-assign mechanism. It can only be a shortcut.

The spec's signature interaction — hold a chip between two avatars, it splits into halves, release assigns half to each — is genuinely beautiful and you should build it. But it has three structural problems:

1. It only ever expresses **two** people. A shared paneer dish among four is the more common real case.
2. It requires the two targets to be **adjacent** in the dock.
3. It is **ambiguous with a normal drag** that happens to be passing between two avatars on its way to a third.

**Decision.** Multi-assignment is a property of the **data model**, not of a gesture. `assignments[itemId]` is an *array of person IDs* from day one, and every part of the engine handles k assignees for any k ≥ 1.

Two UI paths produce it:
- **Path A (correctness, Tier 1):** drop a chip onto an avatar that already owns it → toggles that person off. Drop onto a second avatar → now two people own it. Long-press a chip → "Split between…" sheet with checkboxes for everyone. This handles k = 1..8, always works, zero gesture risk.
- **Path B (the wow, Tier 2):** centre-hold between two adjacent avatars → visual split → release. A shortcut for the most common shared case.

Path A ships regardless. Path B is polish. If Path B never works, the app is not diminished — and Path A is what you demo when the evaluator asks "what if three people shared it?"

### D3 — "Drag onto the *face* of whoever ate it" is a metaphor. There are no faces.

The pitch says faces; the MVP spec says *"free-text names, each with a generated avatar colour and initials."* Photo avatars mean a gallery permission, an image picker, image storage, and a cropping UI, for zero functional gain.

**Decision.** Initials + generated colour from a fixed 8-colour palette. Do not build photo avatars, and do not use the word "face" in your report where "avatar" is what you mean. `expo-contacts` is also **cut** — it adds a runtime permission and a permission-denied state to buy you something that typing a four-letter name already does faster.

### D4 — Quantity is under-specified and Indian receipts will expose it.

Real receipts read `2 x Butter Naan    90.00`. Is ₹90 the unit price or the line total? Both conventions exist, sometimes on the same bill.

**Decision.** `BillItem` stores `quantity`, `unitPrice`, and `lineTotal`. **`lineTotal` is authoritative** for all splitting maths. The OCR parser fills `lineTotal` from the trailing number and sets `quantity` only when it confidently sees a leading `N x`. The review screen lets you correct any of the three. Splitting *by quantity unit* ("Aarav had one naan, Priya had the other") is **Tier 3 and almost certainly cut** — a 2-quantity item shared between 2 people splits by value, 50/50, which is the same answer 95% of the time.

### D5 — Rounding must be exact, and floating-point rupees cannot deliver that.

Your brief asks for a guarantee that everyone's totals sum to the bill total. `0.1 + 0.2 !== 0.3` makes that impossible with float rupees.

**Decision.** **All money is an integer number of paise.** Never a float, anywhere, at any layer, including the database. Formatting to `₹1,234.50` happens only at the render boundary. Apportionment uses the **largest-remainder (Hamilton) method** with deterministic tie-breaking, which makes `Σ personTotal === grandTotal` true *by construction*, not by luck. See §8.

This is the strongest single technical answer you will have in the viva, and it costs about 40 lines of code.

### D6 — GST in India is charged on (subtotal + service charge). Order of operations matters.

The spec says "tax and service charge distribute proportionally" and stops there. On a real Indian restaurant bill the sequence is: items subtotal → service charge (usually 5–10%) → GST (5% or 18%) on *subtotal + service charge* → discount.

**Decision.** Adjustments are an **ordered list**, each with an explicit `base` of either `itemsSubtotal` or `runningTotal`. The default bill has two adjustments — Service Charge (`itemsSubtotal`) and GST (`runningTotal`) — and the engine applies them in order. This is barely more code than the naive version and it is correct against a real receipt, which you will be able to demonstrate by holding one up.

### D7 — Discounts are in your test plan but not in the spec.

Your testing brief asks for a receipt with a discount. Nothing in the concept mentions discounts.

**Decision.** Discount is just an adjustment with a negative effective amount, apportioned by the *same* function. **Watch the sign:** `Math.floor()` on negative numbers rounds *away* from zero and will break the invariant. The rule enforced in code and in tests: **apportion the absolute value, then negate.** UI for adding a discount is Tier 2; engine support is Tier 1 because the engine is where correctness lives.

### D8 — "Unassigned count must be zero to settle" is a hard blocker with no escape hatch. That is a demo hazard.

**Decision.** Keep the blocker — it is the right default and it is what makes the app *fair by design*. But add a one-tap **"Split remaining equally"** button in the blocked state. It is a genuine UX improvement (that is what people actually do with the mystery ₹40 "extra plate" line) and it is insurance against you freezing on stage with one chip unassigned.

### D9 — SQLite is justified, but it must not be the live source of truth.

The brief says "SQLite only if genuinely useful." It is: bills → items → people → assignments is genuinely relational, your report almost certainly needs a database-design section, and past-bill history is in the MVP list. But writing to SQLite on every drag would be a performance disaster.

**Decision.** Zustand holds the active bill in memory and is the single source of truth *during* a session. A repository layer (`src/data/billRepository.ts`) snapshots it to SQLite on a debounce and on settle. **Settlements are never persisted** — always recomputed from inputs. Derived data in a database is a bug waiting to happen, and "I chose not to store computed totals" is a good answer to a database-design question.

### D10 — Your environment has two concrete problems right now.

- **JDK 25 is installed.** Android Gradle Plugin does not support it; local `expo run:android` will fail with a cryptic Gradle error. Either install **JDK 17** (Temurin) and set `JAVA_HOME` for Android builds, or use **EAS Build (cloud)** and never touch Gradle. *Recommendation: EAS Build.* Free-tier queues can be 20–60 minutes, so never make a build the last step of a work session.
- **You are on Windows.** iOS is out of scope entirely — no Mac, no simulator, no App Store build. State this in your report as a deliberate scope boundary ("Android-only, targeting the device class the user base actually holds"), not as a limitation you forgot to mention.

### D11 — Reanimated 4 requires the New Architecture.

Reanimated 4 is Fabric-only. Recent Expo SDKs default to New Arch, so this should be fine — but if any dependency in your set breaks under it, **fall back to Reanimated 3 immediately** rather than debugging. Nothing in Divvy's animation set needs a Reanimated 4 exclusive feature. Do not spend a day on this.

### D12 — Ambiguities I am flagging rather than resolving

These need answers from a human, not from me:

| Question | Why it matters | Action |
|---|---|---|
| Is 31 Oct the **report** deadline, the **demo/viva** date, or both? | Changes whether the last week is writing or rehearsing | **Confirm with course requirements** |
| Required report format, length, section list, template? | Section 20 is my best guess at a standard Indian university mini-project report | **Confirm with course requirements** |
| Is a **signed APK** a submission artefact, or a live demo only? | Changes whether EAS Build is on the critical path | **Confirm with course requirements** |
| Must source be on a **public** GitHub repo? | Changes your git hygiene and README obligations | **Confirm with course requirements** |
| Is a **literature survey / synopsis** required? | 4–6 hours of work if yes, zero if no | **Confirm with course requirements** |
| Plagiarism / similarity check threshold? | Affects how you write, not what you build | **Confirm with course requirements** |
| **Do you own an Android phone you can develop on daily?** | If no, the entire plan changes on day 1 | **Answer this today** |
| **Navratri / Diwali holidays.** Both fall inside this window in Gujarat, and Navratri in Ahmedabad is not a period in which anyone codes. | Could remove 5–8 productive days from mid-to-late October | **Check the academic calendar in Week 0 and pre-emptively pull work forward** |

---

# 2. The Governing Reality: your actual time budget

The source specification estimates Divvy at **3 weeks full-time**. You have **8.7 calendar weeks**. It is very tempting to read that as "I have nearly three times the budget."

You do not. Here is the honest arithmetic:

| | |
|---|---|
| Calendar days | 61 |
| Realistic weekday output (classes, commute, other coursework) | ~2 h × 5 days = 10 h |
| Realistic weekend output | ~5 h × 2 days = 10 h |
| **Realistic weekly output** | **~20 h, and 20 is optimistic** |
| Total available | ~170 h |
| Full-time-equivalent weeks (at 40 h) | **~4.2 weeks** |
| Minus festivals, illness, other submissions, one bad week | **~3.5 FTE weeks** |

**You have almost exactly the budget the spec estimated, spread thinner.** The extra calendar time is not for extra features — it is consumed by context-switching overhead, the academic report, real device testing, and the buffer that a 3-week estimate never includes.

**Rule:** every time you feel like you are "ahead," reread this section. The correct use of spare time is polish and testing, never scope.

---

# 3. Critical Path Analysis

Ranked by *risk × how much of the project dies if it fails*.

### Rank 1 — Dev build with a native module on a physical Android device 🔴🔴🔴

Not in your list, and it is the highest risk item in the project. ML Kit text recognition is a native module. It cannot run in Expo Go. Getting a custom development build onto your phone from a Windows machine involves EAS credentials, Android SDK or a cloud queue, USB debugging, and a device that cooperates.

**Everything else depends on this.** If it takes four days, you have lost a week. Prove it on **day 1**.

### Rank 2 — The gesture system 🔴🔴🔴

This is the project. The specific hard parts, in order of how much time they will eat:

1. **Drag vs. scroll conflict.** Chips live in a scrollable area. A pan gesture on a chip and a scroll gesture on its parent will fight. Resolution: activate drag on a **long-press (~180 ms)**, compose with `Gesture.Simultaneous` / `.blocksExternalGesture()`, and — critically — render the lifted chip in a **portal layer above the ScrollView** so it is not clipped by the parent's bounds. If you skip the portal, the chip will visually disappear at the container edge and you will lose an afternoon confused.
2. **Measuring avatar positions.** Use `useAnimatedRef` + `measure()` inside a worklet, write rects into a shared value array, re-measure on layout change and on dock scroll. Do **not** measure inside the pan handler — measure once and cache.
3. **Hit-testing in a worklet.** Distance from chip centre to each avatar centre, nearest wins if under threshold. Runs on the UI thread every frame.
4. **Magnetic snap tuning.** The spec says three days. Believe it. `withSpring` damping/stiffness has no correct value you can derive — you tune it by feel on a real device. Emulator feel is a lie.

**If this fails, the premise of the app fails.** Which is exactly why it is proven in a throwaway spike in Week 0, before any real code exists.

### Rank 3 — The calculation engine 🟡

Technically easy, but it is the one thing that must be *provably* correct, and it is the part an evaluator can attack with a question. Low risk, high consequence, and — importantly — **it can be built and fully tested on your laptop with no device, no emulator, and no build.** That makes it perfect Week-1 work, running in parallel with build problems.

### Rank 4 — Share card rendering 🟡

`react-native-view-shot` capturing an off-screen view has a history of platform-specific failures (blank captures, wrong scale, New Architecture regressions). The mitigation is trivial and you should just adopt it up front: **capture a card that is actually on screen.** S7 is a real full-screen route showing the card exactly as it will look. Zero off-screen trickery. This is also better UX (you see what you're sending) and removes the entire class of bug.

### Rank 5 — OCR 🟡 (high failure probability, low consequence)

Thermal-printed Indian receipts are genuinely bad input: faded ink, tight leading, variable column alignment, mixed Devanagari/Gujarati/Latin, and totals interleaved with items. You will not get 90%. **You do not need to.**

Because of D1, OCR failing costs you one demo moment, not the app. Its risk is *contained*, which is why it sits at Rank 5 despite being the most likely thing to disappoint you.

### Order of proof

```
Day 1–2   Dev build on device with a native module           ← if this fails, everything changes
Day 3–4   Drag + hit-test spike (throwaway code)             ← if this fails, the premise changes
Day 5–6   OCR spike + share-image spike                      ← if these fail, features get cut
Week 1    Calculation engine (pure TS, no device needed)     ← runs in parallel with all of the above
Week 2+   Build the actual application
```

**Nothing that is not on this list gets touched before 14 September.**

---

# 4. Technical Spikes

Rules that apply to all spikes:

- Spike code lives in `spikes/` and is **deleted or archived**, never promoted into `src/`. You are buying *information*, not code.
- Every spike has a **hard stop**. When the hard stop is reached, you take the fallback and move on **the same day**. No extensions. This is the single most important rule in this document.
- Every spike ends with 3–6 lines written into `docs/spike-log.md`: what you tried, what happened, what you decided. That file becomes report material for free.

---

### Spike 0 — Development build with a native module on a physical device

**Why it matters.** It gates everything. Also validates that your phone, cable, drivers, and EAS account all work — the boring failures that eat days.

**Time.** 4 hours. **Hard stop: end of Wednesday 2 September.**

**Do:**
1. `npx create-expo-app@latest divvy-spike --template blank-typescript`
2. Add `expo-camera`, `expo-haptics`, `react-native-gesture-handler`, `react-native-reanimated`, `@react-native-ml-kit/text-recognition`
3. `eas build --profile development --platform android` (or local, if you install JDK 17)
4. Install the APK on your phone, run `npx expo start --dev-client`
5. Screen shows a button; pressing it takes a photo and `console.log`s the recognised text blocks

**Success:** raw OCR text from a real photo appears in your terminal, on your phone, over USB or LAN.

**Fallback ladder:**
- **A.** Local Gradle fails → use EAS Build cloud. (Do this first anyway.)
- **B.** ML Kit will not build at all → **drop OCR entirely.** Camera still captures the receipt; the photo is pinned beside the manual entry list so you type what you see with the bill on screen. This is an honest, shippable product and a defensible viva answer. Update D1's framing to "camera as reference, not extraction."
- **C.** No usable Android device at all → develop against an emulator, accept that gesture feel cannot be tuned properly, and **cut the magnetic snap to a simple threshold snap.** Escalate immediately; this changes the whole plan.

---

### Spike 1 — Drag, hit-test, and the scroll conflict

**Why it matters.** Rank 2 on the critical path. If dragging a chip out of a scrolling list to a dock is not smooth, the app's entire premise — *make the mapping physical* — collapses.

**Time.** 1 day. **Hard stop: end of Friday 4 September.**

**Do:** hardcode 8 chips in a `ScrollView` and 4 circular avatars in a fixed bottom dock. Long-press a chip → it lifts (scale 1.08 + shadow + light haptic), follows the finger, and on release logs which avatar it landed on. The list must still scroll normally on a plain drag.

**Success — all five must be true:**
- Chip follows the finger with no perceptible lag on a **physical device in release-ish mode**
- The chip is visible **outside** the ScrollView bounds while dragging (portal works)
- Correct avatar identified on ≥ 19 of 20 attempts
- Normal vertical scrolling of the chip list still works
- No dropped frames when dragging fast (check with the Perf Monitor)

**Fallback:** **tap-to-select → tap-to-assign.** Tap a chip (it highlights, avatars pulse), tap an avatar (assigned, haptic, total rolls). This is genuinely fast, completely reliable, and keeps every downstream feature intact. You lose the signature interaction, not the app. If you take this fallback, say so in the viva as a deliberate accessibility argument — tap-to-assign is usable one-handed and by users with motor impairments, which is true.

---

### Spike 2 — OCR quality on real Indian restaurant bills

**Why it matters.** Determines whether the lift-off moment is achievable, and calibrates how much parser effort is worth spending.

**Time.** 1 day. **Hard stop: end of Wednesday 9 September.**

**Prerequisite — do this in Week 0, it takes 20 minutes and it is on the critical path:** collect **8 real receipts**. Ask friends and family, check your wallet, photograph what you find at the next meal out. You need: 2 clean thermal prints, 1 faded, 1 with visible quantities (`2 x`), 1 with service charge + GST split out, 1 with a discount line, 1 with a non-Latin script line, 1 genuinely messy. **You cannot build or test this project without them.**

**Do:** run ML Kit over all 8. Dump the raw `TextBlock` output to JSON fixture files in `src/ocr/fixtures/`. Then, on paper, work out the pairing heuristic: right-aligned trailing number on a text line is the amount, the text to its left is the name. Count how many line items pair correctly.

**Success:** **≥ 60%** of true line items correctly paired (name + amount) across the corpus. Sixty percent, not ninety. At 60% the user corrects four items out of ten and still saves time versus typing all ten.

**Fallback:**
- 30–60% → ship OCR anyway, but frame the review screen as "check these" rather than "confirm these," and make **add/edit/delete on the review screen extremely fast**. This is fine.
- < 30% → **camera-as-reference mode** (Fallback B from Spike 0). Photo stays pinned above the entry field.

**Trap to avoid:** you will be tempted to write a restaurant-specific parser to push 60% to 75%. The spec explicitly forbids it and it is a week-long hole. The correct investment is in the correction UI, not the parser.

---

### Spike 3 — The centre-hold two-person split gesture

**Why it matters.** It is the demo's peak moment. It is also, per D2, *optional* — the data model already supports multi-assign, so this spike tests a shortcut, not a capability.

**Time.** Half a day. **Hard stop: end of Thursday 10 September.** Do not start it until Spike 1 has passed.

**Do:** extend the Spike 1 rig. When the dragged chip's centre sits within a corridor between two adjacent avatars for > 250 ms, both grow rings and the chip renders as two leaning halves. Release logs both person IDs.

**Success:** the dead-zone between two avatars is discoverable *without instruction* by one other person you hand the phone to, and it does not misfire when you drag past two avatars toward a third.

**Fallback:** cut the gesture. Long-press a chip → "Split between…" bottom sheet with checkboxes. **Build this sheet regardless of the spike outcome** — it is the only way to express a 3+ way split and it is Tier 1.

---

### Spike 4 — Rendering and sharing the summary image

**Why it matters.** The final beat of the demo. It is also the step most likely to fail silently on one specific Android version.

**Time.** Half a day. **Hard stop: end of Friday 11 September.**

**Do:** build a static, hardcoded summary card as a real on-screen view. `react-native-view-shot` → PNG at 2–3× pixel density → `expo-sharing.shareAsync()`. Verify the PNG actually arrives in WhatsApp and is legible.

**Success:** a readable PNG lands in a WhatsApp chat from your physical device.

**Fallback ladder:**
- **A.** Capture fails off-screen → capture only on-screen (this is the plan anyway, per §3 Rank 4).
- **B.** `view-shot` broken entirely → `expo-media-library` save-to-gallery, then user shares from the gallery. Slightly worse, entirely functional.
- **C.** Nothing image-based works → `Share.share({ message })` with a well-formatted **plain-text** summary. Ugly but it ships, and a text summary is arguably *more* useful in a group chat because it is copy-pasteable. Keep this path in the codebase permanently as the error fallback regardless.

---

### Spike budget summary

| Spike | Budget | Hard stop |
|---|---|---|
| 0 — Dev build | 4 h | Wed 2 Sep |
| 1 — Drag + hit-test | 1 d | Fri 4 Sep |
| 2 — OCR quality | 1 d | Wed 9 Sep |
| 3 — Centre-hold split | 0.5 d | Thu 10 Sep |
| 4 — Share image | 0.5 d | Fri 11 Sep |
| **Total** | **~4 days** | **All resolved by Sun 13 Sep** |

**If any spike is unresolved on 13 September, take its fallback that day and proceed.** An unresolved spike on 14 September is a project-threatening event, not a technical curiosity.

---

# 5. MVP Tiers

### Tier 1 — Absolutely required (a valid submission is impossible without these)

| # | Feature | Notes |
|---|---|---|
| T1.1 | Create a bill session (title, date) | |
| T1.2 | Add / edit / delete items manually — name, amount, quantity | The fast-entry row: type name → amount → Enter → chip flies up, field clears |
| T1.3 | Add / remove people with generated colour + initials avatars | Free text only. No contacts. |
| T1.4 | Assign an item to one or more people | Whatever the interaction ends up being — drag *or* tap fallback |
| T1.5 | Live per-person running totals | Under each avatar |
| T1.6 | Unassigned counter, with settle blocked at > 0 | Plus "Split remaining equally" escape hatch (D8) |
| T1.7 | Tax + service charge, proportional distribution | Ordered adjustments, D6 |
| T1.8 | Settle screen: per-person amount + their item list | |
| T1.9 | Share the summary (image, or text as fallback) | |
| T1.10 | SQLite persistence + past-bills list on Home | |
| T1.11 | **Calculation engine unit-tested, reconciliation invariant proven** | Non-negotiable. This is the technical spine. |
| T1.12 | Design tokens: one typeface, two weights, one spacing scale, dark theme | Consistency is cheaper than decoration |

### Tier 2 — Important polish (this is what turns a pass into a good grade)

| # | Feature |
|---|---|
| T2.1 | Camera capture + on-device OCR + review screen (the "lift-off" moment) |
| T2.2 | Magnetic snap on drag |
| T2.3 | Rolling/odometer number animation on every total change |
| T2.4 | Haptics audit — one haptic per meaningful event, no more |
| T2.5 | Centre-hold two-person split gesture (Spike 3) |
| T2.6 | Onboarding: 3 cards, card 3 is a live interactive drag demo |
| T2.7 | Designed empty states (no bills, no items, no people) |
| T2.8 | Designed error states (camera denied, OCR found nothing, invalid amount) |
| T2.9 | Discount adjustment in the UI |
| T2.10 | Screen transitions, staggered list entry (30–50 ms) |
| T2.11 | "Show only unassigned" filter on the assign screen |

### Tier 3 — Stretch (only if Tier 1 + 2 are stable **and** it is before 12 October)

| # | Feature |
|---|---|
| T3.1 | Fractional split by weight (½ / ⅓) rather than equal |
| T3.2 | Split a quantity-N item by units rather than by value |
| T3.3 | Saved friend groups for repeat use |
| T3.4 | UPI deep-link per person (`upi://pay?...`) |
| T3.5 | Round-to-whole-rupee display mode with residue to the payer |
| T3.6 | Light theme |
| T3.7 | Bill search / filter on Home |
| T3.8 | The full cinematic lift-off (bounding boxes highlighting in sequence, items peeling off the photo) |

> **On T3.8:** the *simple* lift-off — items animate into the tray with a stagger — is Tier 2 and you will build it. The *cinematic* version, with per-item bounding boxes tracked back to coordinates on the receipt photo, is a separate and much harder problem (you must map OCR frame coordinates to displayed-image coordinates through the aspect-fit transform). Budget it as Tier 3 and expect to cut it.

### Explicitly rejected — do not build these even with spare time

Accounts, login, auth of any kind · multi-device sync or realtime · payment processing · currency conversion or multi-currency · i18n · a cross-bill debt ledger (that is Splitwise) · restaurant-specific OCR parsers · a settings screen · **any AI/LLM feature** · photo avatars · contacts integration · iOS · a web build · dark/light auto-switching · analytics · crash reporting SDKs · custom native modules you write yourself.

> If you have spare time, the correct spend is: more device testing, better empty states, and rehearsing the demo. Not features.

---

# 6. Application Architecture

### Guiding rule

**`src/core/` contains zero React, zero Expo, zero React Native imports.** It is plain TypeScript that could run in Node. This one constraint is what makes the money logic testable in under a second on your laptop with no emulator, and it is the architectural decision most worth explaining in the viva.

### Folder structure

```
divvy/
├── app/                              # expo-router routes ONLY. Thin. No business logic.
│   ├── _layout.tsx                   # Stack + providers (DragProvider, DB init, theme)
│   ├── index.tsx                     # S1  Home
│   ├── onboarding.tsx                # S0  first run only
│   └── bill/
│       ├── new.tsx                   # S2  Setup           (modal sheet)
│       └── [id]/
│           ├── _layout.tsx
│           ├── items.tsx             # S3  Items
│           ├── capture.tsx           # S3b Camera          (Phase 5)
│           ├── review.tsx            # S3c OCR review      (Phase 5)
│           ├── assign.tsx            # S4  Assign  ← centre of gravity
│           ├── settle.tsx            # S6  Settle
│           └── share.tsx             # S7  Share preview   (modal)
│
├── src/
│   ├── core/                         # ── PURE. No React. Fully unit-tested. ──
│   │   ├── money.ts                  # Paise brand, parse, format, guards
│   │   ├── apportion.ts              # largest-remainder apportionment
│   │   ├── splitItem.ts              # one item across k assignees
│   │   ├── settle.ts                 # computeSettlement(bill) → Settlement
│   │   └── __tests__/
│   │       ├── money.test.ts
│   │       ├── apportion.test.ts
│   │       ├── splitItem.test.ts
│   │       ├── settle.test.ts
│   │       └── reconciliation.property.test.ts    ← the important one
│   │
│   ├── domain/
│   │   ├── types.ts                  # every interface in §7
│   │   └── factories.ts              # createBill(), createPerson(), createItem()
│   │
│   ├── store/
│   │   ├── billStore.ts              # zustand — the active bill, mutations only
│   │   └── selectors.ts              # memoised: settlement, unassignedIds, perPersonTotal
│   │
│   ├── data/
│   │   ├── db.ts                     # expo-sqlite open, PRAGMA foreign_keys=ON, migrations
│   │   ├── migrations/001_init.sql
│   │   └── billRepository.ts         # the ONLY file that writes SQL
│   │
│   ├── ocr/
│   │   ├── recognize.ts              # ML Kit wrapper → RecognizedLine[]   (impure, thin)
│   │   ├── parseReceipt.ts           # PURE: RecognizedLine[] → ParsedItem[]  ← unit-tested
│   │   ├── fixtures/                 # raw ML Kit JSON from the 8 real receipts
│   │   └── __tests__/parseReceipt.test.ts
│   │
│   ├── share/
│   │   ├── ShareCard.tsx             # the visual card component
│   │   ├── buildShareText.ts         # PURE: Settlement → string  (the always-works fallback)
│   │   └── exportShareCard.ts        # view-shot → PNG → expo-sharing
│   │
│   ├── gestures/                     # ── the hard part, isolated ──
│   │   ├── DragProvider.tsx          # portal layer + shared values for drag state
│   │   ├── useDropTarget.ts          # avatar registers its measured rect
│   │   ├── useDraggableChip.ts       # long-press → pan → release
│   │   └── hitTest.ts                # PURE worklet: point + rects → target id
│   │
│   ├── features/
│   │   ├── people/  PersonDock.tsx  AvatarBubble.tsx  AddPersonSheet.tsx
│   │   ├── items/   ItemChip.tsx  QuickAddRow.tsx  ItemEditSheet.tsx
│   │   ├── assign/  AssignBoard.tsx  UnassignedHeader.tsx  SplitBetweenSheet.tsx
│   │   ├── charges/ ChargesSheet.tsx
│   │   └── settle/  PersonSettleCard.tsx
│   │
│   ├── ui/                           # dumb + reusable, no domain knowledge
│   │   ├── theme/tokens.ts           # colours, spacing, radii, type ramp, springs
│   │   ├── Text.tsx  Button.tsx  Sheet.tsx  Screen.tsx  EmptyState.tsx
│   │   └── RollingNumber.tsx
│   │
│   └── lib/  haptics.ts  id.ts  cn.ts
│
├── spikes/                           # throwaway. never imported by src/.
├── docs/
│   ├── DIVVY_ROADMAP.md              # this file
│   ├── spike-log.md
│   ├── architecture.md               # written incrementally → becomes a report chapter
│   ├── test-plan.md
│   ├── regression-checklist.md
│   ├── receipts/                     # the 8 test receipt photos
│   └── screenshots/
├── assets/
├── jest.config.js
├── eas.json
└── README.md
```

### State management

**Zustand, one store.** Not Redux (ceremony you do not need), not Context (re-render storms on a screen where 12 chips and 6 avatars all subscribe), not Jotai (no benefit here).

| State | Where it lives | Why |
|---|---|---|
| Active bill: items, people, assignments, adjustments | **Zustand `billStore`** | Single source of truth, cheap subscriptions, survives navigation between S3/S4/S5/S6 |
| Settlement (all totals) | **Derived — never stored** | `computeSettlement(bill)` memoised in `selectors.ts`. Storing it would let it drift. |
| Drag position, lifted chip id, hover target | **Reanimated shared values in `DragProvider`** | Must live on the UI thread. Putting this in Zustand would put animation on the JS thread and destroy the frame rate. **This is the one boundary you must not blur.** |
| Past bills list | **SQLite, loaded on demand** | Not needed in memory during a session |
| Onboarding-seen flag | **AsyncStorage** | One boolean does not need a table |
| Sheet open/closed, filter toggles | **Local `useState`** | Ephemeral, screen-scoped |

**The one rule to hold on to:** *animation state is shared values; application state is Zustand; money truth is derived from Zustand by pure functions.* Three layers, no leakage.

### The calculation engine boundary

```
      Zustand billStore  ──(plain Bill object)──▶  src/core/settle.ts  ──▶  Settlement
             │                                            ▲
             │                                            │
     UI mutates via                             pure, no imports from
     store actions                              react / expo / store
```

`computeSettlement` takes a `Bill` and returns a `Settlement`. It has no knowledge that React exists. Tests call it directly with fixture objects. When an evaluator asks "how do you know the maths is right," you open `reconciliation.property.test.ts` and run it in front of them.

### The OCR boundary

```
Camera ─▶ recognize.ts ─▶ RecognizedLine[] ─▶ parseReceipt.ts ─▶ ParsedItem[] ─▶ Review screen ─▶ billStore
         (impure, thin)     (serialisable)      (PURE, tested)
```

`RecognizedLine[]` is a plain serialisable structure. That is what makes fixtures possible: you capture it once from a real receipt, save it as JSON, and then iterate on the parser forever with `npm test` and no camera, no phone, no build.

### The share boundary

`ShareCard.tsx` renders from a `Settlement` and nothing else. `exportShareCard.ts` knows about view-shot and sharing and nothing about the settle screen. `buildShareText.ts` is pure and is both the fallback path and a trivially testable unit.

---

# 7. Data Model

```ts
// ─────────────── src/domain/types.ts ───────────────

/** Integer paise. NEVER a float. NEVER rupees. Branded to make mixing a type error. */
export type Paise = number & { readonly __brand: unique symbol };

export type ID = string;

// ── Inputs ──────────────────────────────────────────

export interface Person {
  id: ID;
  name: string;
  /** index into the fixed 8-colour palette in ui/theme/tokens.ts */
  colorIndex: number;
  /** 1–2 chars, derived from name at creation, editable */
  initials: string;
}

export interface BillItem {
  id: ID;
  name: string;
  /** >= 1. Display only in MVP — splitting is always by value (D4). */
  quantity: number;
  unitPrice: Paise;
  /** AUTHORITATIVE for all splitting. Equals unitPrice * quantity unless manually overridden. */
  lineTotal: Paise;
  source: 'manual' | 'ocr';
  /** 0..1 from ML Kit; drives the "check this" highlight on the review screen */
  ocrConfidence?: number;
  /** original OCR text, kept for debugging + the report's "OCR limitations" section */
  rawText?: string;
}

export type AdjustmentKind = 'service' | 'tax' | 'discount' | 'tip' | 'other';

export interface Adjustment {
  id: ID;
  label: string;                     // "GST", "Service Charge", "Loyalty discount"
  kind: AdjustmentKind;
  mode: 'percent' | 'amount';
  /** percent → BASIS POINTS (500 = 5.00%). amount → Paise. Integer either way. Never a float. */
  value: number;
  /** ascending; defines application order. Service charge before GST. (D6) */
  order: number;
  /** 'itemsSubtotal' = % of items only. 'runningTotal' = % of items + all preceding adjustments. */
  base: 'itemsSubtotal' | 'runningTotal';
  /** true for discounts; the engine apportions |amount| then negates (D7) */
  isNegative: boolean;
}

export interface Bill {
  id: ID;
  title: string;
  createdAt: string;                 // ISO 8601
  settledAt?: string;
  people: Person[];
  items: BillItem[];
  /** itemId → personIds. Empty array = unassigned. Kept sorted for determinism. */
  assignments: Record<ID, ID[]>;
  adjustments: Adjustment[];
  receiptImageUri?: string;
  /** who physically paid; receives any residue in round-to-rupee mode (T3.5) */
  payerId?: ID;
}

// ── Outputs (always derived, never persisted — D9) ──

export interface ItemShare  { itemId: ID; share: Paise; assigneeCount: number; }
export interface AdjustmentShare { adjustmentId: ID; share: Paise; }   // negative for discounts

export interface PersonSettlement {
  personId: ID;
  itemShares: ItemShare[];
  subtotal: Paise;                   // Σ itemShares
  adjustmentShares: AdjustmentShare[];
  total: Paise;                      // subtotal + Σ adjustmentShares
}

export interface Settlement {
  perPerson: PersonSettlement[];
  itemsSubtotal: Paise;              // Σ every item lineTotal
  adjustmentTotals: { adjustmentId: ID; amount: Paise }[];
  grandTotal: Paise;                 // itemsSubtotal + Σ adjustmentTotals
  unassignedItemIds: ID[];
  unassignedAmount: Paise;
  /** MUST be true. Asserted in dev, surfaced as an error state in prod. */
  reconciles: boolean;
}

// ── OCR (serialisable, so it can be fixtured) ───────

export interface RecognizedLine {
  text: string;
  /** ML Kit frame coordinates */
  bbox: { x: number; y: number; width: number; height: number };
  confidence?: number;
}

export interface ParsedItem {
  name: string;
  amount: Paise;
  quantity: number;
  confidence: number;                // parser's own confidence, not ML Kit's
  sourceLineIndex: number;
}
```

### SQLite schema

```sql
-- src/data/migrations/001_init.sql
PRAGMA foreign_keys = ON;   -- SQLite does NOT enforce FKs by default. Good viva detail.

CREATE TABLE bills (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  settled_at  TEXT,
  receipt_uri TEXT,
  payer_id    TEXT
);

CREATE TABLE people (
  id          TEXT PRIMARY KEY,
  bill_id     TEXT NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  initials    TEXT NOT NULL,
  color_index INTEGER NOT NULL,
  sort_order  INTEGER NOT NULL
);

CREATE TABLE items (
  id               TEXT PRIMARY KEY,
  bill_id          TEXT NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  quantity         INTEGER NOT NULL DEFAULT 1,
  unit_price_paise INTEGER NOT NULL,     -- INTEGER, never REAL
  line_total_paise INTEGER NOT NULL,
  source           TEXT NOT NULL CHECK (source IN ('manual','ocr')),
  raw_text         TEXT,
  sort_order       INTEGER NOT NULL
);

CREATE TABLE assignments (
  item_id   TEXT NOT NULL REFERENCES items(id)  ON DELETE CASCADE,
  person_id TEXT NOT NULL REFERENCES people(id) ON DELETE CASCADE,
  PRIMARY KEY (item_id, person_id)       -- makes double-assignment impossible at the storage layer
);

CREATE TABLE adjustments (
  id          TEXT PRIMARY KEY,
  bill_id     TEXT NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
  label       TEXT NOT NULL,
  kind        TEXT NOT NULL,
  mode        TEXT NOT NULL CHECK (mode IN ('percent','amount')),
  value       INTEGER NOT NULL,          -- basis points or paise
  apply_order INTEGER NOT NULL,
  base        TEXT NOT NULL,
  is_negative INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_items_bill  ON items(bill_id);
CREATE INDEX idx_people_bill ON people(bill_id);
CREATE INDEX idx_assign_item ON assignments(item_id);
```

**Three schema decisions worth saying out loud in the viva:**
1. No `settlements` table. Computed values are never stored, so they can never be stale. (D9)
2. Money columns are `INTEGER` paise. `REAL` would reintroduce float error at the persistence layer even if the engine were perfect. (D5)
3. `assignments` is a composite-key join table, which makes many-to-many the *default* and makes duplicate assignment structurally impossible.

### Referential integrity in the UI layer

Two cases the store must handle explicitly — both are classic sources of "the totals went weird" bugs:

- **Delete an item that is assigned** → remove its row from `assignments`. Cascade handles the DB; your Zustand reducer must do the same in memory.
- **Delete a person who owns items** → remove them from every assignment array. Items where they were the *only* assignee become **unassigned**, and the unassigned counter must go up. Show a confirm dialog naming the count: *"Remove Priya? 3 items will become unassigned."*

---

# 8. The Calculation Engine

This is the part of Divvy that must be *provably* correct. It is also the cheapest part to make excellent.

### Principles

1. **Integer paise everywhere.** `₹123.45` is `12345`. No floats at any layer. (D5)
2. **Percentages in basis points.** `5%` is `500`. `18%` is `1800`.
3. **Every distribution is exact by construction**, using largest-remainder, not by rounding and hoping.
4. **Determinism.** Ties break by `personId` lexicographic order, so the same bill always produces the same answer — which is what makes tests meaningful and what makes "why did Aarav get the extra paisa" answerable.
5. **The invariant is asserted, not assumed.**

### Step 1 — Split one item across k assignees

```
splitItem(lineTotal, assignees[]) → Map<personId, Paise>

  if k === 0 → item is unassigned; contributes to unassignedAmount, not to anyone
  base      = floor(lineTotal / k)
  remainder = lineTotal - (base * k)          // 0 <= remainder < k
  sort assignees by id
  first `remainder` assignees get base + 1; the rest get base
```

`₹100.00 / 3` → `10000 / 3` → 3333, 3333, 3334 → **sums to 10000 exactly.** Someone pays one extra paisa; it is deterministic, and it is invisible.

### Step 2 — Person subtotal

```
subtotal(person) = Σ over items where person ∈ assignees of splitItem(...)[person]
```

By construction, `Σ over all people of subtotal === Σ over assigned items of lineTotal`. Exact, no rounding involved — every paisa was allocated in Step 1.

### Step 3 — Apportion an adjustment (largest remainder / Hamilton)

```
apportion(amount A, weights w[]) → Paise[]

  W = Σ w
  if W === 0:                                   // nobody has a subtotal but charges exist
      apportion equally: w[i] = 1 for all i, recurse
  exact[i]     = A * w[i] / W                   // conceptually; computed as integer math
  floors[i]    = floor(A * w[i] / W)
  allocated    = Σ floors
  leftover     = A - allocated                  // 0 <= leftover < n
  remainders   = (A * w[i]) mod W               // integer, exact — no float remainder
  give one extra paisa to the `leftover` largest remainders
  ties break by personId ascending
  ⇒ Σ result === A, exactly, always
```

**The negative-amount trap.** For a discount, do **not** run this with a negative `A` — `floor(-7/3)` is `-3`, not `-2`, and the invariant breaks. The rule, enforced by a named test:

```ts
if (isNegative) return apportion(Math.abs(A), weights).map(x => -x);
```

### Step 4 — The full settlement

```
computeSettlement(bill) → Settlement

  1. itemsSubtotal = Σ item.lineTotal                  (ALL items, assigned or not)
  2. for each item: shares = splitItem(item.lineTotal, assignments[item.id])
  3. person.subtotal = Σ their shares
  4. unassignedAmount = Σ lineTotal where assignees.length === 0
  5. runningBase = person.subtotal[]                   (the weight vector)
     for each adjustment, in `order`:
        pool  = adj.base === 'itemsSubtotal' ? itemsSubtotal : Σ runningBase
        A     = adj.mode === 'percent'
                  ? roundHalfUp(pool * adj.value / 10000)     // basis points
                  : adj.value
        A     = adj.isNegative ? -A : A
        shares = apportion(|A|, runningBase) signed by adj.isNegative
        record shares; runningBase[i] += shares[i]
  6. person.total   = person.subtotal + Σ their adjustment shares
  7. grandTotal     = itemsSubtotal + Σ adjustment amounts
  8. reconciles     = (Σ person.total === grandTotal - unassignedAmount)
     __DEV__ && invariant(reconciles, 'RECONCILIATION FAILED')
```

Note step 8: when items are unassigned, the correct invariant is `Σ personTotals === grandTotal − unassignedAmount`. Once the unassigned counter hits zero — which the app requires before settling (T1.6) — this collapses to the guarantee your brief asked for:

> **Σ everyone's final amount === the bill total. Exactly. Every time.**

### Worked example (put this in the report)

| | |
|---|---|
| **People** | Aarav, Priya, Zoya |
| **Items** | Paneer Tikka ₹340 (Aarav + Priya) · Dal Makhani ₹280 (all three) · Cold Coffee ₹150 (Zoya) · Naan ×4 ₹160 (all three) |
| **Charges** | Service charge 5% on items · GST 5% on (items + service) |

```
itemsSubtotal = 34000 + 28000 + 15000 + 16000 = 93000 paise (₹930.00)

STEP 1 — item splits (ids sorted A < P < Z, so remainders go to Aarav first)
  Paneer  34000 / 2 → Aarav 17000, Priya 17000
  Dal     28000 / 3 → base 9333, rem 1 → Aarav 9334, Priya 9333, Zoya 9333
  Coffee  15000 / 1 → Zoya 15000
  Naan    16000 / 3 → base 5333, rem 1 → Aarav 5334, Priya 5333, Zoya 5333

STEP 2 — subtotals
  Aarav 17000 + 9334 +     0 + 5334 = 31668
  Priya 17000 + 9333 +     0 + 5333 = 31666
  Zoya      0 + 9333 + 15000 + 5333 = 29666
  Σ = 93000 ✓  (== itemsSubtotal, exactly)

STEP 3a — Service charge 5% of itemsSubtotal 93000 = 4650
  apportion(4650, [31668, 31666, 29666]), W = 93000
    floors    : 1583, 1583, 1483        (Σ = 4649)
    remainders: 37200, 27900, 27900     (integer: A*w mod W)
    leftover 1 → largest remainder (Aarav)
  → Aarav 1584, Priya 1583, Zoya 1483   Σ = 4650 ✓
  running:  33252,  33249,  31149       Σ = 97650 ✓

STEP 3b — GST 5% of runningTotal 97650 = 4882.5 → 4883 (half-up)
  apportion(4883, [33252, 33249, 31149]), W = 97650
    floors    : 1662, 1662, 1557        (Σ = 4881)
    remainders: 75216, 60567, 59517
    leftover 2 → two largest remainders (Aarav, Priya)
  → Aarav 1663, Priya 1663, Zoya 1557   Σ = 4883 ✓

STEP 4 — finals
  Aarav 33252 + 1663 = 34915  →  ₹349.15
  Priya 33249 + 1663 = 34912  →  ₹349.12
  Zoya  31149 + 1557 = 32706  →  ₹327.06

  Σ person totals = 102533
  grandTotal      = 93000 + 4650 + 4883 = 102533
  ✓ RECONCILES EXACTLY
```

Note what happened at each rounding point: the service charge left one stray paisa and the GST left two, and in both cases the largest-remainder rule placed them deterministically rather than letting them vanish. Aarav pays ₹0.03 more than Priya for reasons that are fully explainable — he was first in id order on two remainder distributions.

> Verify these numbers against your engine in Week 1. If the engine disagrees, one of you is wrong and finding out which is the entire point of the exercise. Put the verified table in your report.

### Formatting

`formatPaise(102233) → "₹1,022.33"`. Indian digit grouping (`1,00,000` not `100,000`) via `Intl.NumberFormat('en-IN')` — a small touch that reads as care to an Indian evaluator. Parsing user input: strip `₹`, commas, and spaces; accept `340`, `340.5`, `340.50`; reject anything else with an inline error. **Never `parseFloat` into a money value** — parse to paise directly with a regex and integer math.

---

# 9. OCR Service Design

### Pipeline

```
expo-camera photo
      ↓
ML Kit TextRecognition  (recognize.ts — impure, ~20 lines, the only ML Kit import in the codebase)
      ↓
RecognizedLine[]        ← serialisable. Save to fixtures here.
      ↓
parseReceipt.ts         ← PURE. 100% of the parsing logic. 100% of the tests.
      ↓
ParsedItem[]
      ↓
Review screen (S3c) — every field editable, low-confidence rows highlighted
      ↓
billStore
```

### Parsing heuristic (keep it generic — D1, and the spec forbids per-restaurant parsers)

1. **Group blocks into visual lines** by y-overlap, since ML Kit returns blocks, not lines.
2. **Find the amount:** the rightmost token on the line matching `/(?:₹|Rs\.?)?\s*\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?$/`. Right-alignment is the strongest signal on a printed receipt.
3. **Find the name:** everything to the left of the amount, trimmed, with a leading quantity pattern (`/^(\d+)\s*[xX×]\s*/`) stripped into `quantity`.
4. **Reject non-item lines** by keyword: `total`, `subtotal`, `sub total`, `gst`, `cgst`, `sgst`, `tax`, `service`, `discount`, `round`, `cash`, `card`, `change`, `bill no`, `table`, `gstin`, `thank`, `invoice`. Case-insensitive.
5. **Opportunistically detect charges:** a line matching `service` + an amount becomes a suggested `Adjustment`, not an item. Same for `gst`/`tax`. This is a nice win when it fires and harmless when it doesn't.
6. **Confidence** per item: does it have both a name and an amount? Is the name ≥ 3 chars and not mostly digits? Is the amount plausible (₹5–₹5000)? Anything below threshold gets a visible "check this" highlight on the review screen rather than being silently dropped.
7. **Sanity check:** if a `TOTAL` line was found, compare `Σ parsedItems` against it. If they differ by more than 15%, show a non-blocking banner: *"These items add up to ₹840 but the bill says ₹1,120 — some items may be missing."* This is honest, useful, and reads as very mature engineering.

### Why fixtures are the whole trick

Once you have `RecognizedLine[]` JSON saved from 8 real receipts, you can iterate on `parseReceipt.ts` with `npm test` in a two-second loop, on a plane, with no phone. Every parser improvement is measured against all 8 receipts at once, so you can never fix one bill and silently break another. **Capture these fixtures during Spike 2 and never delete them.** They are also, directly, the evidence table in your report's testing chapter.

---

# 10. Share Service Design

### Three layers, decreasing fidelity, all present in the shipped app

| Layer | Mechanism | When |
|---|---|---|
| **1** | `ShareCard.tsx` rendered on-screen at S7 → `react-native-view-shot` at 3× → `expo-sharing.shareAsync()` | Happy path |
| **2** | Same capture → `expo-media-library` save to gallery, "Saved to Photos" toast | If sharing fails |
| **3** | `buildShareText(settlement)` → `Share.share({ message })` | If capture fails |

Layer 3 is not just a fallback — expose it as a permanent **"Copy as text"** secondary action. Plain text is often *more* useful in a WhatsApp group because it is copy-pasteable and searchable. This turns your defensive engineering into a feature, which is exactly the framing to use in the viva.

### The card

Square-ish (1080×1350 renders well in WhatsApp), dark background matching the app, bill title + date, one row per person with their initials avatar and amount, a subtle divider, then the bill total and a one-line footer (`Split with Divvy`). Every name and amount must be legible as a WhatsApp thumbnail — test this on an actual chat, at actual thumbnail size, on your actual phone.

### The capture rule (from §3 Rank 4)

**Never capture an off-screen view.** S7 is a real route showing the exact card. Its ref is passed to `captureRef`. What you see is what you send, and the entire class of blank-capture bugs disappears.

---

# 11. User Journey & Screen States

### Primary flow

```
LAUNCH
  │
  ├─ first run? ──▶ S0 ONBOARDING (3 cards; card 3 = live interactive drag demo)
  │                      │
  ▼                      ▼
S1 HOME  ◀───────────────┘
  │  "New Bill"  ·  list of past bills
  │
  ▼
S2 SETUP (modal sheet) — title + add people
  │
  ▼
S3 ITEMS ─────────────────────┐
  │  quick-add row            │  [ 📷 Scan bill ]
  │  (PRIMARY PATH)           │        │
  │                           │        ▼
  │                           │   S3b CAPTURE ──▶ processing ──▶ S3c REVIEW
  │                           │                                      │
  │  ◀────────────────────────┴──────────────────────────────────────┘
  │        both producers converge on the same item list
  ▼
S4 ASSIGN  ★ the app's centre of gravity
  │  chips above · avatar dock below · live totals · "N of M unassigned"
  │
  ├──▶ S5 CHARGES (bottom sheet, not a route) — tax / service / discount, live preview
  │
  ▼  (blocked while unassigned > 0; "Split remaining equally" offered)
S6 SETTLE — per-person cards, ordered by amount, each showing their items
  │
  ▼
S7 SHARE PREVIEW (modal) — the card exactly as it will send
  │
  ├──▶ native share sheet ──▶ WhatsApp
  └──▶ save to gallery  /  copy as text
  │
  ▼
back to S1 HOME — bill now appears in history
```

**Why this shape.** It is a linear workflow, not a set of parallel sections, so there is **no tab bar** — and being able to explain that choice is a small, real signal of design maturity. Max depth is four. S5 is a sheet rather than a route because charges are a *modification of the current context*, not a destination.

**The one deviation from your brief's flow:** capture is a *branch off S3*, not a step before it. Direct consequence of D1.

### Every state, per screen

Evaluators probe unhappy paths. These are graded.

#### S0 Onboarding
- Normal: 3 cards, swipeable, skippable from card 1
- **Blocked:** card 3 disables "Get started" until one successful practice drag (teaches the gesture; also the first wow)
- Never shown again — `AsyncStorage` flag

#### S1 Home
- **Empty:** illustrated, *"No bills yet. The next time you eat out, this takes fifteen seconds."* + big New Bill button. **Design this before you design the populated state** — it is the first thing a user sees and the last thing a student builds.
- Loading: 3 skeleton cards, never a spinner
- Populated: past bills, newest first, each with date, title, total, stacked avatars
- **DB error:** *"Couldn't load your past bills"* + Retry. The New Bill button must still work — a history failure must never block a new bill.

#### S2 Setup
- Empty: 0 people, Continue disabled, hint *"Add at least two people"*
- **Validation:** 1 person → *"Add someone to split with"*; duplicate name → allow it but auto-suffix initials; blank name → ignore the submit
- Max: soft-cap at 8 people (the palette has 8 colours; more than 8 avatars will not fit the dock legibly). Cap it and say why in the report.

#### S3 Items
- **Empty:** *"Add your first item"* with the quick-add row focused and the keyboard already up. Two buttons: type, or scan.
- **Invalid amount:** inline red hint under the field, submit blocked, keyboard stays up
- **₹0 item:** allowed (complimentary items exist), but flagged in review
- Populated: list + running items subtotal in the header

#### S3b Capture
- **Permission not yet asked:** a short pre-permission screen explaining why, *then* the OS prompt. Never fire the OS prompt cold.
- **Permission denied:** *"Divvy can't open the camera. You can still add items by hand."* → primary button goes to manual entry, secondary opens `Linking.openSettings()`. **This is the single most likely state an evaluator will deliberately trigger. Make it good.**
- **Permission denied permanently:** same screen, settings link only
- Capturing: shutter, freeze frame, brief flash
- **Capture failed:** retry + "add manually" escape

#### S3c OCR Review
- **Processing:** the receipt photo on screen with a scanning sweep. Do not show a spinner — pace the animation to cover the real processing time.
- **Found items:** staggered entry into the list, low-confidence rows visibly flagged
- **Found nothing:** *"Couldn't read this bill. It happens with faded receipts — add the items and the photo will stay on screen to copy from."* → manual entry **with the photo pinned above it**. This turns the failure into a usable feature.
- **Totals mismatch:** non-blocking banner (§9 step 7)
- **OCR crashed:** identical to "found nothing." The user must never see a stack trace or the word "OCR."

#### S4 Assign
- **No people:** cannot happen (S2 enforces ≥ 2), but guard anyway → *"Add people first"* + link
- **No items:** *"Nothing to assign yet"* + link to S3
- Normal: chips + dock + live totals + `"4 of 12 unassigned"`
- **All assigned:** header goes to a green *"Everything assigned"*, Settle becomes prominent
- **Dragging:** avatars pulse once; the hovered avatar rings
- **Invalid drop** (released over dead space): chip springs back to its slot with a damped spring; **no haptic** — silence is the correct feedback for "nothing happened"
- **Blocked settle:** tapping Settle with unassigned > 0 → sheet listing the unassigned items + *"Split remaining equally"* (D8)
- **Person removed mid-flow:** confirm dialog naming how many items become unassigned

#### S5 Charges (sheet)
- Default: Service Charge and GST rows, both zero, percent mode
- Live preview: per-person delta updates as you type
- **Invalid:** percent > 100 or negative → inline error, disabled apply
- **Discount > subtotal:** clamp to subtotal, warn *"Discount can't exceed the bill"*

#### S6 Settle
- Normal: per-person cards ordered by amount, each expandable to its items
- **Reconciliation failure** (`settlement.reconciles === false` — should be impossible): a visible error card, *"Something doesn't add up. Please check your items."* Never silently show wrong money. Ship this; it costs ten lines and it is the correct professional behaviour.
- Total row: bill total, items subtotal, each charge

#### S7 Share
- Rendering: brief skeleton of the card shape
- **Capture failed:** fall to Layer 2, then Layer 3, silently and automatically. The user sees a share sheet either way.
- **No share targets:** *"Saved to your photos instead"*

### Global states
- **Offline:** nothing changes. Divvy is fully offline by design — worth demonstrating in airplane mode during the viva.
- **Backgrounded mid-bill:** Zustand + debounced SQLite snapshot means the draft survives. Test this by force-killing the app mid-assignment.
- **Low storage / SQLite write failure:** toast, app stays usable in memory.

---

# 12. UX / Animation Roadmap

**The governing rule: functional completeness always precedes animation.** A screen ships working and plain, then gets its motion in Phase 6. If you animate as you build, you will polish a screen you later delete.

**Global principles** (set these in `ui/theme/tokens.ts` on day one and never deviate):
- Springs, not linear tweens. Define exactly three: `spring.snappy`, `spring.gentle`, `spring.bouncy`.
- Stagger list entry by 30–50 ms per item.
- Skeletons, never spinners.
- **One haptic per meaningful event, never more.** Haptic spam is worse than silence.
- Any number that changes rolls; it never jumps.

| # | Interaction | What happens | Priority | Haptic | Fallback | Tier |
|---|---|---|---|---|---|---|
| A1 | **Quick-add item** | Type name → amount → Enter. Chip scales in at the list top with `spring.snappy`, field clears, keyboard stays up | 🔴 High | `selection` | Item just appears | **T1** |
| A2 | **Capture → processing** | Shutter freeze, photo settles into frame, scan line sweeps top→bottom over ~1.2 s | 🟡 Med | `impactLight` on shutter | Static photo + skeleton | T2 |
| A3 | **Lift-off (simple)** | Parsed items enter the tray staggered 40 ms, from below, with slight overshoot; the photo desaturates and recedes to 0.6 scale behind | 🔴 High | `notificationSuccess` once, at the end | Plain list appearance | T2 |
| A4 | **Lift-off (cinematic)** | Each item's bbox highlights on the photo, then peels off along a curve into the tray | 🟢 Low | as A3 | A3 | T3 |
| A5 | **Chip pickup** | Long-press 180 ms → scale 1.08, lift shadow, slight rotation | 🔴 High | `impactLight` | Tap to select (highlight) | **T1** |
| A6 | **Avatars announce** | On pickup, every avatar pulses 1.0 → 1.1 → 1.0 over 200 ms, staggered 40 ms across the dock | 🔴 High | none | Static ring outline | T2 |
| A7 | **Drag follow** | Chip tracks the finger 1:1 in a portal layer above everything; rotation lags proportional to horizontal velocity | 🔴 High | none | — | **T1** |
| A8 | **Magnetic attraction** | Within 40 px of an avatar, the avatar grows a ring and the chip springs toward its centre | 🟡 Med | none | Ring only, no snap | T2 |
| A9 | **Drop** | Chip shrinks into the avatar; the avatar's total rolls digit-by-digit to its new value | 🔴 High | `impactMedium` | Chip disappears, total jumps | **T1** |
| A10 | **Invalid drop** | Chip springs back to its slot, `spring.gentle` | 🔴 High | **none** — silence is correct | Chip snaps back | **T1** |
| A11 | **Centre-hold split** | Held in the corridor between two avatars > 250 ms: both ring, chip splits into two translucent leaning halves | 🟢 Low | `impactHeavy` on release | "Split between…" sheet | T2 |
| A12 | **Split-between sheet** | Checkbox list; on apply, the chip gains N coloured dots and all N totals roll simultaneously | 🔴 High | `impactMedium` | Instant update | **T1** |
| A13 | **Assigned chip** | Dims to 60% opacity, gains coloured owner dots | 🔴 High | none | Just dims | **T1** |
| A14 | **Unassigned counter** | `"4 of 12"` rolls down; at zero it morphs into a green "Everything assigned" pill | 🟡 Med | `notificationSuccess` at zero | Text swap | T2 |
| A15 | **Charges preview** | Typing a % rolls every per-person delta live | 🟡 Med | none | Update on blur | T2 |
| A16 | **Settle reveal** | Person cards enter staggered 60 ms, each total counting up from its pre-tax subtotal to its final value over 600 ms | 🔴 High | `notificationSuccess` once | Static list | T2 |
| A17 | **Share card render** | Card scales in from 0.95 with a soft shadow bloom | 🟢 Low | none | Appears | T2 |
| A18 | **Screen transitions** | Consistent horizontal push; sheets spring from the bottom | 🟡 Med | none | Defaults | T2 |
| A19 | **Onboarding drag demo** | Live, real gesture, two fake avatars, a fake chip. Cannot continue until one successful drop. | 🟡 Med | as A5/A9 | Static illustration | T2 |
| A20 | **Empty states** | Illustration + a single clear action | 🔴 High | none | Text only | T2 |

**Animation time-box:** all of Phase 6 is 12–18 October, and that is the entire budget. Anything not animated by 17 October ships unanimated. **A working plain screen beats a beautiful broken one, every single time.**

---

# 13. Testing Strategy

### 13.1 Unit tests — `src/core/` (the non-negotiable ones)

Fast (< 2 s for the whole suite), no device, no emulator, run on every commit.

**`money.test.ts`**
- `parseAmount`: `"340"` → 34000 · `"340.5"` → 34050 · `"340.50"` → 34050 · `"₹1,234.50"` → 123450 · `"1,00,000"` → 10000000
- Rejects: `""`, `"abc"`, `"-5"`, `"3.999"`, `"12.345"`
- `formatPaise` round-trips for 10 000 random values
- `formatPaise(10000000)` → `"₹1,00,000.00"` (Indian grouping)

**`splitItem.test.ts`**
- 1 person → gets 100%
- 2 people, ₹100.00 → 5000 / 5000
- 3 people, ₹100.00 → 3333 / 3333 / 3334, **sums to 10000**
- 3 people, ₹0.01 → 0 / 0 / 1, sums to 1
- 7 people, ₹100.00 → sums to 10000
- 0 assignees → empty map, contributes to unassigned
- **Determinism:** same input, 100 runs, byte-identical output
- Fuzz: for 1..12 people × 500 random amounts, `Σ shares === lineTotal` **always**

**`apportion.test.ts`**
- Equal weights → equal shares (±1 paisa)
- Zero total weight → falls back to equal apportionment
- One person has weight 0 → gets 0
- `Σ result === A` for 10 000 random `(A, weights)` pairs
- **Negative amounts:** `apportion(-4650, w)` sums to exactly `-4650` ← the D7 trap; name this test explicitly
- Tie-breaking is by id and is stable

**`settle.test.ts`**
- The §8 worked example, exact expected paise values
- Service-then-GST ordering produces a different (correct) answer than GST-then-service
- Percent mode and amount mode agree when the amount equals the computed percentage
- Discount reduces every person's share, never below zero in total
- Unassigned items are excluded from person subtotals but included in `itemsSubtotal`
- Removing a person reassigns nothing and increases `unassignedAmount` correctly

**`reconciliation.property.test.ts` ← the flagship test**
```
For 1,000 randomly generated bills:
  1–20 items, amounts ₹1–₹5,000
  1–8 people
  random assignments (including some items assigned to 0 and some to everyone)
  0–4 adjustments, random percent/amount, random order, ~20% negative

ASSERT: Σ perPerson.total === grandTotal − unassignedAmount   (exactly, integer equality)
ASSERT: settlement.reconciles === true
ASSERT: no NaN, no Infinity, no non-integer anywhere in the output
```
**Run this in front of the evaluator.** It is the single most convincing thirty seconds available to you.

### 13.2 OCR testing — the 8-receipt corpus

`src/ocr/__tests__/parseReceipt.test.ts` runs `parseReceipt` over all 8 fixtures and asserts a **minimum item count and a minimum accuracy per receipt**, so a parser change can never silently regress one bill while fixing another.

| # | Receipt | What it proves | Target |
|---|---|---|---|
| R1 | Clean thermal print | Baseline | ≥ 80% items paired |
| R2 | Clean, different chain | Not overfitted to R1 | ≥ 80% |
| R3 | Faded / low contrast | Graceful degradation | ≥ 40%, **no crash** |
| R4 | Visible quantities (`2 x`) | Quantity extraction | quantity parsed on ≥ 1 line |
| R5 | Service charge + CGST/SGST split | Charge lines rejected as items, ideally suggested as adjustments | 0 charge lines misread as items |
| R6 | Contains a discount line | Discount not treated as an item | 0 false items |
| R7 | Non-Latin script line | No crash, Latin lines still parse | **no crash** |
| R8 | Genuinely messy / crumpled | Worst case | **no crash**, ≥ 1 item or clean "found nothing" |

**Every one of these produces a row in your report's testing chapter.** That table is worth real marks and it costs you nothing extra to produce.

### 13.3 Gesture testing — manual matrix, on a physical device

Run before every milestone. Record pass/fail in `docs/regression-checklist.md`.

| # | Case | Expected |
|---|---|---|
| G1 | Drag one chip to one avatar | Assigned, haptic, total rolls |
| G2 | Drag the same chip to a second avatar | Now assigned to both, both totals correct |
| G3 | Drag onto an avatar that already owns it | Unassigned from that person |
| G4 | Drop over dead space | Springs back, no assignment, **no haptic** |
| G5 | Drop over the header / status bar | Springs back |
| G6 | Drag 5 chips in rapid succession | No dropped assignments, no stuck chips |
| G7 | Start a drag, then scroll the chip list | List scrolls OR drag continues — never both, never a stuck ghost chip |
| G8 | Plain vertical swipe on a chip | List scrolls, no drag activates |
| G9 | Long-press then release without moving | Chip returns to rest, nothing assigned |
| G10 | Centre-hold between two avatars | Both assigned, heavier haptic |
| G11 | Drag *past* two avatars toward a third | Only the third is assigned (no false split) |
| G12 | Rotate the device mid-drag | No crash; rects re-measured after rotation |
| G13 | Assign every item | Counter hits zero, header morphs, Settle enables |
| G14 | Remove a person who owns 3 items | Confirm dialog, 3 items go unassigned, counter rises |
| G15 | Background the app mid-drag, return | No stuck chip, state intact |
| G16 | 8 people + 20 items | Dock still legible, no frame drops |

### 13.4 Device testing — what an emulator cannot tell you

**Must be tested on a physical Android phone:**
- Gesture *feel* — spring tuning is meaningless on an emulator. This is not a preference; emulator input timing is fundamentally different.
- Haptics — emulators have none
- Camera + real focus/exposure on a glossy thermal receipt under restaurant lighting
- ML Kit performance and actual on-device latency
- Frame rate during drag (Perf Monitor, in a **release** build — dev builds lie)
- The share sheet and real WhatsApp delivery
- Share card legibility at WhatsApp thumbnail size
- Battery/thermal behaviour after 10 minutes of camera use
- Safe areas, notch/punch-hole, gesture-navigation bar collision with your bottom dock
- Airplane-mode operation (prove the offline claim)
- Force-kill and relaunch mid-bill

**Test at minimum:** your primary demo phone, plus **one other Android device** — ideally an older/cheaper one, and ideally one with a different screen aspect ratio. Borrow one for an hour. A layout that breaks on a friend's phone is exactly what will happen if the evaluator asks to try it on theirs.

### 13.5 Regression checklist (`docs/regression-checklist.md`)

Run before every milestone tag. Should take ~12 minutes.

```
[ ] npm run typecheck                          — 0 errors
[ ] npm run lint                               — 0 errors
[ ] npm test                                   — all green, incl. property test
[ ] Cold launch → Home renders                 (< 3 s)
[ ] Home empty state renders (clear app data)
[ ] New bill → 2 people → 5 items → assign all → settle → share → PNG in WhatsApp
[ ] Camera permission DENIED path reaches manual entry
[ ] OCR "found nothing" path reaches manual entry with the photo pinned
[ ] Gesture matrix G1–G8 (fast pass)
[ ] Delete a person who owns items → confirm → counter correct
[ ] Charges: 5% service + 5% GST → per-person totals sum to the bill total
[ ] Settle screen: Σ person totals === bill total (check by hand, once, with a calculator)
[ ] Force-kill mid-bill → relaunch → draft survives
[ ] Airplane mode → full flow works
[ ] Past bill opens from Home and shows the right numbers
[ ] No console errors, no yellow boxes
```

---

# 14. Git Workflow

Solo project. Keep it boring.

### Branches

```
main          — always builds, always demoable. Tagged at every milestone.
dev           — daily work. Merge to main only at a milestone.
spike/*       — throwaway spikes. Never merged to main; merged to dev only if archived under spikes/.
feat/*        — only for genuinely risky work (the gesture system, OCR). Otherwise commit on dev.
```

Do not create a feature branch for every task. You are one person; branch ceremony is pure overhead. The only reason `feat/*` exists is so you can abandon the gesture rewrite cleanly if it goes wrong.

### Commits

Conventional-ish prefixes, present tense, one logical change each:

```
feat(core): add largest-remainder apportionment
fix(assign): re-measure avatar rects after dock scroll
test(core): property test for reconciliation invariant
chore(deps): add react-native-view-shot
docs(report): draft architecture chapter
```

**Commit at least once per working session, even if incomplete.** An uncommitted day is a lost day.

### Tags

```
v0.1-m1-engine       Calculation engine complete + tested
v0.2-m2-gestures     Gesture system proven
v0.3-m3-slice        End-to-end manual flow
v0.4-m4-mvp          ★ Tier 1 complete — this is your safety net
v0.5-m5-ocr          OCR path live
v0.6-m6-freeze       Feature freeze
v0.9-m7-candidate    Submission candidate
v1.0-final           Submitted
```

`v0.4-m4-mvp` matters most. From 4 October onward, **you can always check out that tag and submit something complete.** Every day after that is upside, not risk.

### Backup — three places, no excuses

1. **GitHub private repo**, pushed at the end of every session (`git push origin dev`)
2. **Weekly zip** of the whole folder to Google Drive, dated: `divvy-2026-09-13.zip`. Includes `node_modules`? No. Includes `docs/receipts/`? **Yes** — those photos are irreplaceable.
3. **The signed APK** uploaded to Drive at every milestone from M4 onward

> A dead laptop in the last week of October has ended more mini projects than any bug. Three copies, weekly, no negotiation.

### Repository hygiene for submission

`.gitignore` covering `node_modules/`, `.expo/`, `android/`, `ios/`, `*.keystore`, `.env`. A real `README.md` with screenshots, setup steps, and the architecture diagram. No commented-out code, no `console.log` spam, no `spikes/` in `main` unless archived deliberately. Someone will open this repo.

---

# 15. Phases

---

## Phase 0 — Foundation & Risk Elimination
### Tue 1 Sep → Sun 6 Sep

**Objective.** Prove the two things that can kill the project — the native dev build, and the drag gesture — before writing a single line of application code. Have a running app skeleton on your physical phone.

**Tasks**
1. Confirm the D12 unknowns with your course coordinator. Send that email **today**.
2. Check the academic calendar for Navratri/Diwali dates. Mark the dead days on your own copy of §16.
3. **Collect 8 real restaurant receipts** and photograph them into `docs/receipts/`. (20 minutes. On the critical path.)
4. Install JDK 17 alongside JDK 25, *or* commit to EAS Build cloud. (D10)
5. `npx create-expo-app@latest divvy --template blank-typescript`; init git; push a private GitHub repo.
6. **Spike 0** — dev build with `@react-native-ml-kit/text-recognition` on your phone.
7. Set up `expo-router`, the folder structure from §6 (empty files are fine), TypeScript strict mode, ESLint, Prettier, Jest.
8. Write `ui/theme/tokens.ts`: 8-colour avatar palette, background/surface/text ramp, one accent, 4/8/12/16/24/32 spacing, type ramp, three spring configs.
9. **Spike 1** — drag + hit-test + scroll conflict.
10. Write `docs/spike-log.md` entries for Spikes 0 and 1.

**Deliverables**
- `divvy/` repo on GitHub, `dev` branch, builds and runs on your physical Android phone
- Development build APK installed on the demo device
- `src/` folder skeleton, `app/_layout.tsx` + `app/index.tsx` rendering a themed placeholder
- `ui/theme/tokens.ts` complete
- `spikes/drag/` — working drag prototype
- `docs/receipts/` — 8 photographed receipts
- `docs/spike-log.md` — Spikes 0 & 1 recorded
- `npm run typecheck`, `npm run lint`, `npm test` all wired and passing on an empty suite

**Definition of Done**
- [ ] Your phone runs the app from `npx expo start --dev-client`
- [ ] ML Kit returns text from a photo (or Fallback B is *decided and written down*)
- [ ] A chip can be dragged from a scrolling list onto one of 4 avatars, correctly, 19/20 times (or the tap fallback is *decided and written down*)
- [ ] 8 receipts photographed
- [ ] Design tokens file exists and nothing in the app uses a hardcoded colour

**Risks → mitigation**
| Risk | Mitigation |
|---|---|
| Dev build fails on Windows/JDK 25 | Go straight to EAS cloud build. Do not debug Gradle. Hard stop Wed 2 Sep. |
| EAS free-tier queue is slow | Start builds at the *beginning* of a session, work on tokens/structure while it queues |
| No physical device | Escalate on day 1 — borrow one, or the whole plan changes |
| The drag spike goes well and you start building the real app | **Don't.** Spike code is throwaway. Phase 1 is the engine. |

**Ask Claude Code to:**
- Scaffold the Expo + expo-router + TypeScript-strict project with the exact folder structure in §6, creating empty placeholder files
- Write `ui/theme/tokens.ts` from the visual direction in this document
- Configure Jest so `src/core/**` tests run in plain Node with no RN transform (fast)
- Build the throwaway drag prototype in `spikes/drag/` — hardcoded chips and avatars, portal layer, long-press activation, worklet hit-test, `console.log` the hit avatar
- Set up `npm run check` = `typecheck && lint && test`

---

## Phase 1 — The Calculation Engine
### Mon 7 Sep → Sun 13 Sep

**Objective.** A complete, provably correct, fully unit-tested money engine — with zero UI. All remaining spikes resolved.

Doing this second, before any screens, is deliberate: it is the only part of the project that must be *provably* right, it needs no device, and it lets you make real progress on days when a build is broken.

**Tasks**
1. `src/domain/types.ts` — every interface from §7
2. `src/core/money.ts` — `Paise` brand, `parseAmount`, `formatPaise` (Indian grouping), guards
3. `src/core/splitItem.ts` — §8 Step 1
4. `src/core/apportion.ts` — largest remainder, with the negative-amount rule
5. `src/core/settle.ts` — `computeSettlement`
6. All five test files from §13.1, including the property test
7. **Spike 2** (OCR quality) — capture the 8 fixture JSONs into `src/ocr/fixtures/`
8. **Spike 3** (centre-hold split) — half a day, only if Spike 1 passed
9. **Spike 4** (share image)
10. Hand-verify the §8 worked example with a calculator; correct the document if the engine disagrees with you (one of you is wrong — find out which)
11. Start `docs/architecture.md` — write the money-model section while it is fresh. It becomes a report chapter for free.

**Deliverables**
- `src/core/` complete, `src/domain/types.ts` complete
- `src/core/__tests__/` — 5 files, all green, suite runs in < 2 s
- `src/ocr/fixtures/` — 8 real receipt OCR dumps as JSON
- `spikes/share/`, `spikes/split/` prototypes
- `docs/spike-log.md` — all 5 spikes recorded with decisions
- `docs/architecture.md` — money model section drafted
- Tag `v0.1-m1-engine`

**Definition of Done**
- [ ] `npm test` green, including 1 000-case property test
- [ ] `Σ perPerson.total === grandTotal − unassignedAmount` holds for every generated case
- [ ] Negative-adjustment test passes (the D7 trap)
- [ ] Zero imports of react / react-native / expo anywhere under `src/core/`
- [ ] All 5 spikes have a written decision — **green or fallback, no "still investigating"**
- [ ] 8 OCR fixtures saved

**Risks → mitigation**
| Risk | Mitigation |
|---|---|
| Rounding bugs eat days | The property test finds them in seconds. Write it *early*, not last. |
| Spike 2 disappoints and you start writing a better parser | **Stop.** Record the number, take the fallback, move on. Parser work is Phase 5, time-boxed. |
| Adjustment ordering gets confusing | Model it as an explicit ordered list from the start (D6). Do not special-case "tax" and "service". |
| Engine feels "done" so you skip tests | The tests *are* the deliverable. Untested engine = phase not complete. |

**Ask Claude Code to:**
- Implement `src/domain/types.ts` exactly as specified in §7
- Implement `money.ts`, `splitItem.ts`, `apportion.ts`, `settle.ts` per the algorithms in §8 — integer paise only, basis points for percentages, largest remainder, deterministic id tie-breaking
- Write all five test files, **including the 1 000-case property test**, and explicitly include the negative-adjustment case
- Write `parseReceipt.ts` against the fixtures with the §9 heuristic, and a test asserting a minimum accuracy per fixture
- Draft `docs/architecture.md` §"Money model" from the code it just wrote

> **Say this to Claude Code explicitly:** *"src/core must not import react, react-native, expo, or the store. If you need a value from state, take it as a parameter."*

---

## Phase 2 — The Gesture System
### Mon 14 Sep → Sun 20 Sep

**Objective.** Build the real S4 Assign screen with hardcoded data and no persistence. Get the drag, the hit-test, the snap, and the haptics feeling genuinely good. **This is the project.**

The spec is explicit and correct about this: build S4 first, with four fake people and eight fake items in `useState`. If the gesture doesn't feel good, the premise fails, and you need to know that on 20 September, not 18 October.

**Tasks**
1. `src/gestures/DragProvider.tsx` — portal layer, shared values for `draggedItemId`, `dragX/Y`, `hoveredTargetId`
2. `src/gestures/useDropTarget.ts` — avatars register measured rects into a shared value array; re-measure on layout and dock scroll
3. `src/gestures/hitTest.ts` — pure worklet: point + rects → nearest target within threshold
4. `src/gestures/useDraggableChip.ts` — long-press(180 ms) → pan → release
5. `features/items/ItemChip.tsx`, `features/people/AvatarBubble.tsx`, `features/people/PersonDock.tsx`
6. `ui/RollingNumber.tsx` — digit-column odometer
7. `app/bill/[id]/assign.tsx` with **hardcoded** items and people
8. Wire `computeSettlement` in so the avatar totals are real, from real engine output
9. Haptics: pickup(light), drop(medium), invalid(none), all-assigned(success)
10. Magnetic snap tuning — **budget three days of feel work and do not feel bad about it**
11. `SplitBetweenSheet.tsx` (T1, Path A from D2)
12. Centre-hold split (T2, Path B) — **only if everything above is done by Friday 18 Sep**
13. Run gesture matrix G1–G16 on a physical device

**Deliverables**
- `src/gestures/` complete
- `features/items/ItemChip.tsx`, `features/people/*`
- `ui/RollingNumber.tsx`
- `app/bill/[id]/assign.tsx` — fully functional against hardcoded data
- Assignment state shape matching §7 (`Record<itemId, personId[]>`)
- `docs/regression-checklist.md` created, G1–G16 recorded
- A 20-second screen recording of the drag working — **this is your proof of life; keep it**
- Tag `v0.2-m2-gestures`

**Definition of Done**
- [ ] G1–G16 all pass on a physical device
- [ ] No frame drops during drag in a release-ish build (Perf Monitor)
- [ ] Totals under avatars roll and are computed by `computeSettlement`, not by ad-hoc arithmetic
- [ ] Multi-assign works for k = 1..4 via *at least one* path
- [ ] Hand the phone to one other person with no instructions. They successfully assign an item. (If they can't, the interaction is wrong — fix the affordance, not the spring constant.)
- [ ] `npm run check` green

**Risks → mitigation**
| Risk | Mitigation |
|---|---|
| **Drag/scroll conflict eats the week** | Long-press activation + portal layer. Already proven in Spike 1 — reuse that exact approach, don't reinvent it. |
| Spring tuning becomes infinite | **Hard-cap it at 3 days.** Set a timer. "Good" is when a second person can use it, not when you stop noticing improvements. |
| Chip clipped at ScrollView bounds | Portal layer. If you see clipping, this is the cause — do not debug anything else first. |
| Avatar rects go stale after scroll/rotate | Re-measure on `onLayout` and on scroll end. G12 covers rotation. |
| Building persistence "while you're here" | **No.** Hardcoded data only this week. Persistence is Phase 3. |

**Ask Claude Code to:**
- Port the *approach* from `spikes/drag/` into `src/gestures/` as production code — provider, `useDropTarget`, worklet `hitTest`, `useDraggableChip`
- Build the Assign screen with a hardcoded fixture of 4 people and 8 items, calling `computeSettlement` for the totals
- Build `RollingNumber` as a translating digit column driven by a Reanimated shared value
- Build the "Split between…" bottom sheet with checkboxes
- Add haptics per the §12 table — *"exactly one haptic per event; do not add haptics I did not list"*

> **Say this explicitly:** *"Do not add persistence, navigation, or a database this week. Hardcoded data only. If you think something needs the store, ask me first."*

---

## Phase 3 — Vertical Slice
### Mon 21 Sep → Sun 27 Sep

**Objective.** Replace hardcoded data with real state and real persistence. Build S1, S2, S3, and S5. By Sunday you can create a bill, add people, type items, assign them, set charges, and see correct per-person numbers — end to end, from a cold app launch.

**Tasks**
1. `src/store/billStore.ts` — Zustand, all mutations (add/edit/delete item, add/remove person, assign/unassign, adjustments)
2. `src/store/selectors.ts` — memoised settlement, unassigned ids, per-person totals
3. Referential integrity: delete-item and delete-person cases from §7
4. `src/data/db.ts` + `migrations/001_init.sql` + `billRepository.ts` (save, load, list, delete)
5. Debounced snapshot on mutation; load draft on launch
6. `app/index.tsx` — S1 Home: New Bill + past bills list
7. `app/bill/new.tsx` — S2 Setup sheet: title + add people
8. `app/bill/[id]/items.tsx` — S3 with the quick-add row (name → amount → Enter → clear, keyboard stays up)
9. `features/charges/ChargesSheet.tsx` — S5 with live preview
10. Wire S4 to the real store
11. Navigation between all screens, with correct back behaviour
12. Test: force-kill mid-bill, relaunch, draft survives

**Deliverables**
- `src/store/`, `src/data/` complete
- `app/index.tsx`, `app/bill/new.tsx`, `app/bill/[id]/items.tsx`, `charges` sheet
- SQLite schema + migration applied on a device
- End-to-end manual flow working from cold launch
- Tag `v0.3-m3-slice`

**Definition of Done**
- [ ] Cold launch → new bill → 3 people → 6 items → assign all → set 5% service + 5% GST → correct per-person totals
- [ ] Totals verified against a hand calculation, once, with a calculator
- [ ] Force-kill mid-bill → relaunch → draft restored
- [ ] Deleting a person who owns items behaves per §7 (confirm dialog, counter rises)
- [ ] Past bills appear on Home and reopen with the right numbers
- [ ] `npm run check` green

**Risks → mitigation**
| Risk | Mitigation |
|---|---|
| SQLite writes cause drag jank | Debounce snapshots (500 ms) and never write inside a gesture handler. Zustand is the live truth. (D9) |
| Zustand re-render storms on S4 | Subscribe with narrow selectors. A chip subscribes to *its own* assignment, not the whole bill. |
| Migration/schema churn | The schema is in §7 and it is final. If you must change it, delete the DB in dev — no migration ladder for a project this size. |
| Quick-add row fights the keyboard | Budget half a day for this specifically; it is fiddlier than it looks and it is a Tier-1 interaction. |

**Ask Claude Code to:**
- Implement the Zustand store with the exact mutation set, including the two referential-integrity cases
- Implement `billRepository.ts` as the **only** file containing SQL, with `PRAGMA foreign_keys = ON`
- Build S1, S2, S3, S5 using only `ui/` primitives and `theme/tokens.ts` — *"no hardcoded colours, no hardcoded spacing"*
- Wire S4 to the store, replacing the hardcoded fixture
- Add a debounced persistence middleware

---

## Phase 4 — Settle, Share, and MVP Completion ★
### Mon 28 Sep → Sun 4 Oct

**Objective.** Complete **Tier 1**. On 4 October, Divvy is a finished, submittable application. Everything after this date is improvement, not risk.

This is the most important week in the schedule.

**Tasks**
1. `app/bill/[id]/settle.tsx` — per-person cards ordered by amount, expandable to items, totals row
2. Reconciliation-failure error state (§11 S6)
3. Blocked-settle sheet + **"Split remaining equally"** (D8)
4. `src/share/ShareCard.tsx` — the visual card
5. `src/share/buildShareText.ts` — pure, tested
6. `src/share/exportShareCard.ts` — view-shot → sharing, with all three fallback layers
7. `app/bill/[id]/share.tsx` — S7 on-screen preview, capture from a real visible view
8. Mark bill settled, write to history, return to Home
9. Full regression checklist run
10. **Build a signed release APK and put it on Drive.** This is your safety net.
11. Record a 60-second demo video of the complete flow

**Deliverables**
- S6, S7 complete
- `src/share/` complete with three fallback layers
- Signed release APK on Google Drive
- 60-second demo video
- Full regression checklist run and recorded
- Tag **`v0.4-m4-mvp`** ← the safety net
- `main` updated from `dev`

**Definition of Done**
- [ ] Full flow: launch → bill → people → items → assign → charges → settle → share → **PNG in a real WhatsApp chat**
- [ ] Card legible at WhatsApp thumbnail size on a real phone
- [ ] All three share fallback layers manually verified (force each one)
- [ ] Σ person totals === bill total, verified by hand
- [ ] Signed APK installs on a **second** phone and works
- [ ] `v0.4-m4-mvp` tagged and pushed
- [ ] APK + video backed up to Drive

**Risks → mitigation**
| Risk | Mitigation |
|---|---|
| view-shot returns blank | Capture on-screen only (§10). Fallback ladder is already built. Do not debug for more than 2 hours — take Layer 2. |
| Release build differs from dev | Build the release APK **this week**, not in October. Release-only crashes are real and take time to find. |
| "I'll polish the settle screen while I'm here" | **No.** Functional this week; beautiful in Phase 6. |
| Signing keystore confusion | EAS manages credentials. Let it. Do not hand-manage a keystore. |

**Ask Claude Code to:**
- Build the Settle screen from `Settlement`, including the `reconciles === false` error state
- Build the blocked-settle sheet with "Split remaining equally"
- Build `ShareCard` at a fixed 1080×1350 aspect, and `exportShareCard` with the three-layer fallback
- Write `buildShareText` as a pure function + a unit test
- Produce a release-profile EAS build config

---

## Phase 5 — Camera & OCR
### Mon 5 Oct → Sun 11 Oct

**Objective.** Add the capture → OCR → review path as an accelerator on top of the working manual path. **This entire phase is cuttable.**

**Tasks**
1. `app/bill/[id]/capture.tsx` — `expo-camera`, pre-permission screen, capture, retry
2. Permission-denied state (§11 S3b) — the state an evaluator will deliberately trigger
3. `src/ocr/recognize.ts` — thin ML Kit wrapper
4. Promote `parseReceipt.ts` from Phase 1 into the app path
5. `app/bill/[id]/review.tsx` — S3c: editable rows, low-confidence highlighting, add/delete
6. "Found nothing" state with the photo pinned above manual entry
7. Totals-mismatch banner (§9 step 7)
8. Auto-suggest detected service charge / GST as adjustments
9. Simple lift-off animation (A3): staggered entry, photo desaturates and recedes
10. Test against all 8 physical receipts, on the device, in real lighting
11. Record accuracy per receipt in `docs/test-plan.md` — this table is report material

**Deliverables**
- S3b, S3c complete
- `src/ocr/` complete and wired
- Accuracy table for all 8 receipts
- Tag `v0.5-m5-ocr`

**Definition of Done**
- [ ] Photograph a real bill → items appear → correct 2–3 → assign → settle
- [ ] Permission-denied path reaches manual entry cleanly
- [ ] "Found nothing" path reaches manual entry with the photo pinned
- [ ] No crash on any of the 8 receipts
- [ ] Accuracy recorded for all 8
- [ ] **Manual entry still works exactly as before** ← regression check, non-negotiable

**Risks → mitigation**
| Risk | Mitigation |
|---|---|
| Accuracy is disappointing | **Expected.** Improve the *review UI*, not the parser. 60% is the bar. |
| Parser rabbit hole | Hard-cap parser work at **1.5 days**. Set a timer. |
| Camera perf/thermal issues | Capture a still photo; never run live frame processing. |
| OCR work breaks manual entry | Manual entry is in the regression checklist. Run it daily this week. |
| **You are behind schedule entering this week** | **Cut this phase entirely.** Go straight to Phase 6. The app is complete without it. This is why it sits here. |

**Ask Claude Code to:**
- Build the camera screen with the pre-permission explainer and the denied state
- Wire `recognize.ts` → the already-tested `parseReceipt.ts` → the review screen
- Build the review screen with inline-editable rows and confidence highlighting
- Implement the simple staggered lift-off (A3) — *"not the cinematic bbox version"*
- Add the totals-mismatch banner and the charge auto-suggestion

---

## Phase 6 — Polish & Feature Freeze
### Mon 12 Oct → Sat 17 Oct

**Objective.** Make it feel expensive. **Feature freeze lands Saturday 17 October and it does not move.**

**Tasks**
1. Every empty state: Home, Items, Assign, past bills (§11)
2. Every error state, visually designed rather than a red toast
3. Skeleton loaders replacing every spinner
4. Staggered list entry everywhere (30–50 ms)
5. Screen transitions + sheet springs, consistent
6. Full haptic audit — *remove* any haptic not in the §12 table
7. Full animation audit — every motion is a spring from `tokens.ts`, no linear tweens
8. `app/onboarding.tsx` — 3 cards, card 3 is the live interactive drag demo (A19)
9. Typography audit — one typeface, two weights, the type ramp, no exceptions
10. Colour audit — zero hardcoded colours outside `tokens.ts`
11. Safe areas, thumb zone, gesture-nav bar collision with the dock
12. Seed 3 realistic past bills so Home is never empty in the demo
13. **Feature freeze Sat 17 Oct.** Tag `v0.6-m6-freeze`.

**Deliverables**
- All empty and error states designed
- Onboarding complete
- Haptic + animation + type + colour audits done and recorded
- 3 seeded demo bills
- Tag `v0.6-m6-freeze`

**Definition of Done**
- [ ] Every screen has a designed empty state (verified by clearing app data and walking through)
- [ ] Every error state has been triggered manually at least once
- [ ] Zero spinners remain
- [ ] Zero hardcoded colours outside `tokens.ts` (grep for `#`)
- [ ] Onboarding runs on first launch and can be replayed by clearing data
- [ ] `npm run check` green
- [ ] **Nothing new gets built after this tag**

**Risks → mitigation**
| Risk | Mitigation |
|---|---|
| Polish is infinite | Work the list in order. When Saturday ends, stop. Unfinished polish ships unpolished — that is fine. |
| A "small feature" sneaks in | It doesn't. Write it in `docs/future-scope.md` and it becomes a report section instead. |
| Onboarding takes longer than expected | It is Tier 2. If Thursday arrives and it isn't working, cut to 2 static cards. |

**Ask Claude Code to:**
- Audit every screen for missing empty/error/loading states and implement them from `ui/EmptyState.tsx`
- Replace all spinners with shape-matched skeletons
- Grep the codebase for hardcoded colours and spacing and replace them with tokens
- Add staggered entry to every list
- Build the onboarding flow with a live drag demo on card 3
- Produce a list of every haptic call site so you can audit it by hand

---

## Phase 7 — Stabilization, Testing & Documentation
### Mon 19 Oct → Sun 25 Oct

**Objective.** Break it, fix it, document it, photograph it. No new features. By Sunday you have a submission candidate.

**Tasks**
1. Full regression checklist on the primary device
2. Full regression checklist on a **second, older** Android device
3. Gesture matrix G1–G16 on both devices
4. All 8 receipts, on-device, real lighting
5. Airplane-mode pass
6. Force-kill / background / rotate pass
7. Fix every crash. Fix P1 bugs. **Log P2/P3 bugs into `docs/known-limitations.md` instead of fixing them** — that file becomes the report's Limitations section.
8. **Capture all screenshots** — every screen, plus the drag mid-motion, plus each empty state. Consistent device frame. Do this once, properly, in one sitting.
9. Record the final **90-second demo video** (this is your viva backup if the phone misbehaves)
10. Write the report bulk: abstract, problem statement, objectives, requirement analysis, system architecture, data model, algorithms, implementation, testing, results, limitations, future scope, conclusion, references
11. Update `README.md` with screenshots and setup
12. Build the release APK; install and test on both devices
13. Tag `v0.9-m7-candidate`

**Deliverables**
- Bug log with everything triaged
- `docs/known-limitations.md`
- `docs/screenshots/` — complete set
- 90-second demo video
- Report draft, all sections present
- Release APK, verified on 2 devices
- `README.md` complete
- Tag `v0.9-m7-candidate`

**Definition of Done**
- [ ] Zero known crashes
- [ ] Regression checklist passes on **both** devices
- [ ] Screenshots complete and consistent
- [ ] Demo video recorded
- [ ] Report draft complete — *every* section has content, even if rough
- [ ] APK verified on both devices
- [ ] Backed up to Drive

**Risks → mitigation**
| Risk | Mitigation |
|---|---|
| A serious bug surfaces on the second device | This is *why* the week exists. You have a whole week and `v0.4-m4-mvp` to fall back on. |
| Report writing takes longer than expected | It will. Start Monday, not Friday. Your `docs/` files already contain most of it. |
| Fixing P2 bugs eats the week | Triage ruthlessly. A documented limitation scores better than a rushed fix that breaks something else. |
| Screenshots taken piecemeal look inconsistent | One sitting, one device, one time of day, one framing. |

**Ask Claude Code to:**
- Run the regression checklist and report failures (it can't tap a screen — have it verify what it *can*: types, lint, tests, and a code read-through against the checklist)
- Draft report sections **from the actual code** — architecture from the folder structure, data model from `types.ts` and the schema, algorithms from `src/core/`
- Generate `README.md` with the architecture diagram and setup steps
- Sweep for dead code, stray `console.log`s, and unused dependencies

---

## Phase 8 — Submission
### Mon 26 Oct → Sat 31 Oct

**Objective.** Submit. Nothing else.

**Tasks**
1. **Mon 26:** Report — finalise, format, proofread. Insert screenshots. References.
2. **Tue 27:** Presentation slides. 8–10 slides: problem, solution, architecture, the algorithm, demo, testing, limitations, future scope.
3. **Wed 28:** Viva prep — §19 question list. Rehearse the demo **five times, start to finish, out loud.**
4. **Thu 29:** Final build. Final regression pass. Final APK. Git cleanup — squash nothing, but clean the README, remove `spikes/` from `main` if it isn't archived deliberately, verify `.gitignore`.
5. **Fri 30:** Final backup — GitHub, Drive zip, APK, report PDF, video, screenshots. **On two separate services.** Charge the demo phone. Seed the demo bills. Set the phone to Do Not Disturb. Print a clean high-contrast receipt that OCRs reliably.
6. **Sat 31:** Submit. Tag `v1.0-final`.

**Only permitted code changes this week:** a crash that occurs in the demo flow. Nothing else. Not a colour, not a spacing value, not a "quick" fix.

**Deliverables**
- Final report (PDF)
- Presentation deck
- Final signed APK
- Demo video
- Clean GitHub repo, tagged `v1.0-final`
- Backups in two places
- A rehearsed demo

**Definition of Done**
- [ ] Everything the course requires is submitted, on time, in the required format
- [ ] Demo rehearsed 5 times end to end without notes
- [ ] Backup verified by **downloading it and opening it**
- [ ] Demo phone charged, DND on, demo bills seeded, test receipt printed

**Risks → mitigation**
| Risk | Mitigation |
|---|---|
| Last-minute "improvement" breaks the app | Code freeze. `v0.9-m7-candidate` is the fallback and it is one `git checkout` away. |
| Phone dies / misbehaves in the viva | 90-second video ready to play. Second device has the APK installed. |
| OCR fails live | Use the printed high-contrast receipt. If it still fails, **say so and type the items** — you designed for that, and saying so out loud is a *strength*. |
| Submission portal problems | Submit on Friday if the portal allows it. Never on the last hour of the last day. |

---

# 16. Weekly Schedule

Assume ~20 h/week (§2). **Max acceptable unfinished** is the amount you can carry into the next week without needing the emergency plan.

---

### Week 0 · Tue 1 Sep – Sun 6 Sep · *Foundation & Risk*
**Objective:** prove the build and the drag. Write no application code.

- [ ] Email the coordinator the §D12 questions **(today)**
- [ ] Check academic calendar for Navratri/Diwali; mark dead days
- [ ] Photograph 8 real receipts into `docs/receipts/`
- [ ] Scaffold the Expo project; GitHub private repo; `dev` branch
- [ ] **Spike 0** — dev build + ML Kit on your phone *(hard stop Wed)*
- [ ] `ui/theme/tokens.ts` + folder skeleton + `npm run check` wired
- [ ] **Spike 1** — drag + hit-test + scroll conflict *(hard stop Fri)*

**Output:** app runs on your phone; drag prototype works or its fallback is decided.
**Max unfinished:** Spike 1 tuning may be rough. **Spike 0 may not be unfinished.**

---

### Week 1 · Mon 7 – Sun 13 Sep · *The Engine*
**Objective:** provably correct money maths; all spikes closed.

- [ ] `domain/types.ts` + `core/money.ts`
- [ ] `core/splitItem.ts` + `core/apportion.ts` (mind the negative case)
- [ ] `core/settle.ts`
- [ ] All 5 test files, **including the property test**
- [ ] **Spike 2** — OCR quality, save 8 fixtures *(hard stop Wed)*
- [ ] **Spike 3** — centre-hold *(hard stop Thu)* · **Spike 4** — share image *(hard stop Fri)*
- [ ] Draft the money-model section of `docs/architecture.md`
- [ ] **Tag `v0.1-m1-engine`**

**Output:** `npm test` green with 1 000-case reconciliation proof. Every spike has a written verdict.
**Max unfinished:** Spikes 3 and 4 may end in fallbacks. **The engine and its tests may not be unfinished.**

---

### Week 2 · Mon 14 – Sun 20 Sep · *The Gesture System*
**Objective:** S4 feels good, on hardcoded data.

- [ ] `DragProvider` + portal layer
- [ ] `useDropTarget` (measure + re-measure) + worklet `hitTest`
- [ ] `useDraggableChip` (long-press → pan → release)
- [ ] `ItemChip`, `AvatarBubble`, `PersonDock`, `RollingNumber`
- [ ] Assign screen wired to `computeSettlement` (hardcoded data)
- [ ] Haptics + magnetic snap tuning *(cap: 3 days)*
- [ ] `SplitBetweenSheet`; centre-hold **only if** the above is done by Fri
- [ ] Gesture matrix G1–G16 on device
- [ ] **Tag `v0.2-m2-gestures`** + keep a 20 s screen recording

**Output:** you can drag a dish onto a person and watch a number roll, on your phone.
**Max unfinished:** centre-hold split, magnetic snap fine-tuning. **G1–G9 may not be unfinished.**

---

### Week 3 · Mon 21 – Sun 27 Sep · *Vertical Slice*
**Objective:** real state, real persistence, real screens.

- [ ] `billStore` (all mutations + referential integrity)
- [ ] `selectors.ts` (memoised settlement)
- [ ] SQLite schema + `billRepository` + debounced snapshot
- [ ] S1 Home, S2 Setup sheet
- [ ] S3 Items with the quick-add row *(budget half a day for keyboard behaviour)*
- [ ] S5 Charges sheet with live preview
- [ ] Rewire S4 from hardcoded to store
- [ ] Force-kill / restore test
- [ ] **Tag `v0.3-m3-slice`**

**Output:** cold launch → create → assign → correct totals, end to end.
**Max unfinished:** Home's past-bills list polish, charges preview animation.

---

### Week 4 · Mon 28 Sep – Sun 4 Oct · ★ *MVP Completion*
**Objective:** Tier 1 complete. The safety net exists.

- [ ] S6 Settle + reconciliation error state
- [ ] Blocked-settle sheet + "Split remaining equally"
- [ ] `ShareCard` + `buildShareText` + `exportShareCard` (3 layers)
- [ ] S7 Share preview; verify a PNG in real WhatsApp
- [ ] Mark settled → history → Home
- [ ] Full regression checklist
- [ ] **Signed release APK → Drive**; 60 s demo video
- [ ] **Tag `v0.4-m4-mvp`; merge `dev` → `main`**

**Output:** a complete, submittable Divvy. **From here, you cannot fail.**
**Max unfinished:** *nothing.* If this week slips, go to §18 immediately.

---

### Week 5 · Mon 5 – Sun 11 Oct · *Camera & OCR* — **cuttable**
**Objective:** OCR as an accelerator.

> **Gate:** if `v0.4-m4-mvp` is not tagged, **skip this entire week** and go to Week 6.

- [ ] S3b Capture + pre-permission + denied state
- [ ] `recognize.ts` wired to `parseReceipt.ts`
- [ ] S3c Review — editable rows, confidence highlighting
- [ ] "Found nothing" → manual entry with the photo pinned
- [ ] Totals-mismatch banner + charge auto-suggestion
- [ ] Simple lift-off animation (A3)
- [ ] All 8 receipts tested on-device; accuracy table recorded
- [ ] **Tag `v0.5-m5-ocr`**

**Output:** photograph a bill, correct a couple of items, settle.
**Max unfinished:** the whole phase. Cut it without guilt.

---

### Week 6 · Mon 12 – Sat 17 Oct · *Polish → **FREEZE***
**Objective:** make it feel expensive. Then stop building.

- [ ] Empty states, everywhere
- [ ] Error states, everywhere, designed
- [ ] Skeletons replace spinners; stagger every list
- [ ] Screen transitions + sheet springs
- [ ] Haptic audit · animation audit · type audit · colour audit
- [ ] Onboarding with the live drag demo (cut to 2 static cards if Thursday arrives)
- [ ] Safe areas / thumb zone / gesture-nav collision
- [ ] Seed 3 demo bills
- [ ] **Sat 17 Oct: FEATURE FREEZE. Tag `v0.6-m6-freeze`.**

**Output:** an app that does not look like a student project.
**Max unfinished:** onboarding, some transitions. **The freeze may not be unfinished.**

---

### Week 7 · Mon 19 – Sun 25 Oct · *Stabilize & Document*
**Objective:** break it, fix it, write it up.

- [ ] Regression + gesture matrix on **two** devices
- [ ] All 8 receipts on-device; airplane mode; force-kill; rotate
- [ ] Fix all crashes; triage P2/P3 into `docs/known-limitations.md`
- [ ] **Screenshots — all of them, one sitting**
- [ ] 90-second demo video
- [ ] Report bulk (start Monday — see §20)
- [ ] `README.md` with screenshots + architecture
- [ ] Release APK verified on both devices
- [ ] **Tag `v0.9-m7-candidate`**

**Output:** a submission candidate.
**Max unfinished:** report polish. **Screenshots, video, and APK may not be unfinished.**

---

### Week 8 · Mon 26 – Sat 31 Oct · *Submit*
**Objective:** submit. Build nothing.

- [ ] Mon: report finalise + proofread + screenshots inserted
- [ ] Tue: presentation deck (8–10 slides)
- [ ] Wed: viva prep; **rehearse the demo 5× out loud**
- [ ] Thu: final build, final regression, git cleanup
- [ ] Fri: backups ×2 services (verify by re-downloading); charge phone; seed demo bills; print the test receipt
- [ ] Sat: **submit. Tag `v1.0-final`.**

**Output:** submitted, rehearsed, backed up.
**Max unfinished:** nothing.

---

# 17. Milestones

| # | Milestone | Date | App state | Demonstrable | Committed to git | Hard? |
|---|---|---|---|---|---|---|
| **M0** | Foundation & spikes resolved | **Sun 6 Sep** | Placeholder screen on a real phone | Dev build runs; drag prototype works | Repo, skeleton, tokens, `spikes/drag/`, 8 receipts, spike log | 🔴 **Hard** |
| **M1** | Calculation engine | **Sun 13 Sep** | No UI change | `npm test` — 1 000-case reconciliation proof | `src/core/`, tests, OCR fixtures, all 5 spike verdicts · `v0.1-m1-engine` | 🔴 **Hard** |
| **M2** | Gesture system | **Sun 20 Sep** | S4 works on hardcoded data | **Drag a dish onto a person, watch the number roll** | `src/gestures/`, `assign.tsx`, chips + dock · `v0.2-m2-gestures` | 🔴 **Hard** — go/no-go on the premise |
| **M3** | Vertical slice | **Sun 27 Sep** | S1–S5 real, persisted | Create a bill from scratch and get correct totals | store, data layer, S1/S2/S3/S5 · `v0.3-m3-slice` | 🔴 **Hard** |
| **M4** | ★ **Tier 1 MVP** | **Sun 4 Oct** | **Complete, submittable app** | **Full flow ending in a PNG in WhatsApp** | S6, S7, share service, **release APK** · `v0.4-m4-mvp` · `main` updated | 🔴 **Hard — the safety net** |
| **M5** | OCR path | **Sun 11 Oct** | Camera + OCR live | Photograph a real bill; items appear | `src/ocr/`, S3b, S3c, accuracy table · `v0.5-m5-ocr` | 🟢 **Soft — cuttable** |
| **M6** | Feature freeze | **Sat 17 Oct** | Polished | The app as it will be submitted | states, onboarding, audits, demo seeds · `v0.6-m6-freeze` | 🔴 **Hard — does not move** |
| **M7** | Submission candidate | **Sun 25 Oct** | Stable, tested, documented | Everything, on two devices | screenshots, video, report draft, README, APK · `v0.9-m7-candidate` | 🔴 **Hard** |
| **M8** | Final submission | **Sat 31 Oct** | Submitted | The viva demo | report, deck, APK, clean repo · `v1.0-final` | 🔴 **Hard** |

**The two dates that matter most:** **4 October** (you can no longer fail) and **17 October** (you stop building). Everything else is a checkpoint. These two are commitments.

---

# 18. Do Not Fall Behind

## Red flags

Check yourself against these every Sunday. Any one of them means read the emergency schedules.

🚩 **It's 3 September and the dev build still isn't on your phone.** → Switch to EAS cloud today. If still failing on the 4th, escalate: borrow a machine, ask a friend, post the exact error.

🚩 **It's 13 September and any spike is "still investigating."** → Take the fallback today. Write it in the spike log. Move on. An unresolved spike is a decision you are refusing to make.

🚩 **It's 20 September and the drag doesn't feel right.** → Ship it as-is or take the tap fallback. **Do not spend Week 3 on springs.** A working tap-to-assign beats a beautiful drag you finish on 18 October.

🚩 **It's 27 September and there's no end-to-end flow.** → You are one week behind. Emergency Schedule A.

🚩 **It's 4 October and M4 isn't tagged.** → This is the serious one. Emergency Schedule B, and cut OCR immediately.

🚩 **You spent more than 2 days on the OCR parser.** → Stop. Record the accuracy number. Improve the review UI instead. The parser is not the product.

🚩 **You are animating a screen whose logic isn't finished.** → Stop. Finish the logic. Animation is Phase 6 and only Phase 6.

🚩 **You wrote code for something in the "explicitly rejected" list.** → Delete it. Today. It is not a sunk cost; it is an active liability.

🚩 **You haven't committed in 3 days.** → Commit now, even broken, on `dev`.

🚩 **It's 17 October and you're still adding features.** → Freeze. Whatever is half-built gets reverted or hidden behind a flag. Do not carry a half-feature into Week 7.

🚩 **It's 25 October and the report has fewer than 5 sections written.** → Stop all technical work. Write.

## Scope cuts, in exact order

When you lose time, cut in this order and do not skip ahead:

1. **Cinematic lift-off (T3.8)** → simple staggered entry
2. **Centre-hold split gesture (T2.5)** → "Split between…" sheet only
3. **Onboarding (T2.6)** → 2 static cards, or none
4. **Magnetic snap (T2.2)** → plain threshold snap
5. **Discount UI (T2.9)** → engine keeps it, UI drops it
6. **Rolling numbers (T2.3)** → totals jump instead
7. **The whole OCR phase (T2.1)** → manual entry only; camera becomes "photo as reference," or is removed
8. **Past bills history (T1.10)** → single-session only; **update your report's scope section to match**
9. **Drag itself** → tap-to-select, tap-to-assign

If you are cutting past #7, you are in serious trouble — go to Emergency Schedule C.

## Non-negotiables — never sacrifice these

1. **The calculation engine and its tests.** If the money is wrong, nothing else matters. This is also the easiest thing to defend in a viva.
2. **`Σ person totals === bill total`.** The invariant, proven, running.
3. **Manual item entry.** The app's actual spine.
4. **Assignment of one item to multiple people.** Without it, Divvy is an equal-split calculator.
5. **Some way to share the result.** Even plain text.
6. **The app not crashing.** A crash in the viva is worth more lost marks than every missing feature combined.
7. **Camera-permission-denied handling.** Evaluators test this deliberately.
8. **The report.** A brilliant app with no report is a fail. An adequate app with a strong report is a good grade.
9. **Backups in two places.**
10. **`v0.4-m4-mvp` tagged and pushed.**

## Emergency schedules

### 🟡 Schedule A — one week behind

*Symptom: it's ~27 Sep with no end-to-end flow, or ~20 Sep with no working assign screen.*

- **Cut OCR entirely, today.** Delete Week 5 from your plan and reclaim 7 days. This is the whole reason OCR was scheduled where it was.
- Reframe the project honestly: *"Camera capture with on-device OCR is documented as future scope; the manual-entry path was prioritised because reliability matters more than automation."* This is a **good** viva answer, not an excuse.
- Compress Weeks 4–6 into Weeks 4–5 (28 Sep – 11 Oct): MVP completion, then polish.
- Feature freeze **still 17 Oct**. You now have 6 days of slack in it.
- Apply scope cuts 1–4.
- **Nothing else changes.** The report, testing, and submission weeks are untouched.

### 🟠 Schedule B — two weeks behind

*Symptom: it's 4 Oct and M4 isn't tagged; the vertical slice is incomplete.*

- Cut OCR, onboarding, magnetic snap, centre-hold, and rolling numbers (scope cuts 1–6). Do it in one sitting.
- **Reorder ruthlessly.** Priority: (1) settle screen works, (2) share works *as plain text*, (3) SQLite persistence. Nothing else.
- Move the feature freeze to **12 Oct** — earlier, not later. You need *more* stabilization time when you're behind, not less.
- If drag is still unreliable, **take the tap fallback now.** Half a day, and it removes your largest remaining risk permanently.
- Start writing the report in **Week 6**, in parallel — you cannot afford to leave it all to Week 7.
- Target the **Minimum acceptable submission** in §19 and be at peace with it.

### 🔴 Schedule C — three weeks behind

*Symptom: it's ~11 Oct and there's no working end-to-end app.*

This is a triage situation. The objective changes from "build Divvy" to "submit something complete, honest, and defensible."

- **11–17 Oct — build the smallest complete Divvy that exists:**
  - One screen. Hardcoded people added by a text field.
  - Manual item entry.
  - **Tap** an item, **tap** a person to assign. No drag at all.
  - The real calculation engine (you built it in Week 1 — it is done and it is your strongest asset).
  - Settle screen with per-person totals.
  - `Share.share({ message })` plain-text summary.
  - No SQLite. Single session. In-memory only.
- **17 Oct: absolute freeze.** No exceptions.
- **18–25 Oct:** test it, screenshot it, video it, write the report.
- **26–31 Oct:** submit.

**Your report is now the primary deliverable, and it should be excellent.** Write the architecture, the calculation model, the property-based testing approach, and a genuinely thoughtful "what I would build next" section describing the gesture system and OCR. A small app with rigorous engineering behind it and an honest, well-argued write-up is a respectable submission. A half-built ambitious app with no report is not.

**Do not, under any circumstances, attempt the drag system after 11 October.**

---

# 19. Final Submission State

### 🟡 Minimum acceptable — this must be true no matter what

An Android app that installs and runs offline. Create a bill, add people by name, add items by hand. Assign an item to one or more people by *some* interaction. Live per-person totals. Tax and service charge distributed proportionally with a **proven** reconciliation invariant. A settle screen. A shareable summary (image or text). No crashes on the happy path. Camera permission denial handled gracefully if the camera exists at all.

Plus: a complete report, screenshots, a demo video, and a clean tagged repo.

*This is a solid pass. If everything goes wrong, this is where you land — and you land there because of the M4 tag on 4 October.*

### 🟢 Target — realistic, and what you should be aiming at

Everything above, **plus**:

- **Drag-and-drop assignment** with magnetic snap, haptics, and rolling per-avatar totals
- Multi-person assignment via drag *and* via the split sheet
- **Camera capture with on-device OCR**, a review screen where every field is editable, and graceful handling of poor results
- The simple lift-off animation
- SQLite persistence with a past-bills history on Home
- Designed empty states and error states throughout
- Onboarding with a live interactive drag demo
- A dark, consistent, token-driven visual system
- The property-based reconciliation test, runnable live in the viva
- Tested on two physical devices; a 90-second demo video
- A report with a real architecture chapter, the calculation algorithm worked through, and an honest OCR accuracy table across 8 real receipts

*This is an excellent mini project and it is comfortably achievable on this schedule.*

### 🔵 Exceptional — only if Tier 1 + 2 are stable before 12 October

Everything above, **plus** any of: the centre-hold two-person split · the cinematic lift-off with per-item bounding boxes · fractional (½/⅓) splits · UPI deep-links per person · round-to-whole-rupee mode · saved friend groups.

**Pick at most two.** Exceptional is not "more features" — it is the same app with nothing rough left in it.

### What the app looks like on 31 October 2026

You hand your phone to the evaluator. It opens on a dark Home screen with three past bills. They tap **New Bill**, type two names, and either photograph the printed receipt you brought or type three items. They land on the Assign screen: chips above, two avatars below with ₹0.00 under each. They press and hold a chip. It lifts. Both avatars pulse. They drag it onto one face, feel the haptic, and watch a number roll up from zero.

They do it three more times. The counter reaches zero and turns green. They tap Settle. Three cards resolve into their final amounts. They tap Share and a card appears, ready for WhatsApp.

The whole thing took ninety seconds and they did it without being told how. Then you open your laptop and run the property test in front of them.

---

# 20. Academic Submission Requirements

> ⚠️ **Everything in this section is my best reconstruction of a standard Indian university mini-project report. Confirm the actual required structure, length, and format with your course coordinator in Week 0.** Where I am guessing, I have said so.

### Report sections and where the content comes from

| Section | Source | When |
|---|---|---|
| **Abstract** (150–250 w) | The one-sentence description + the problem | Week 8 (write last) |
| **Problem statement** | Spec §"The problem". The key line: expense-sharing apps track balances *over time*; nothing serves *this bill, right now, at this table* | Week 7 |
| **Objectives** | Tier 1 list (§5) turned into 5–7 numbered objectives | Week 7 |
| **Literature / background survey** | ⚠️ **Confirm whether required.** If yes: compare Splitwise, Settle Up, Google Pay bill split — and argue the gap. 4–6 hours. | Week 7 |
| **Requirement analysis** | Functional = Tier 1 + Tier 2. Non-functional = offline-first, < 3 s cold launch, 60 fps drag, no accounts, no network | Week 7 |
| **System architecture** | `docs/architecture.md` + the §6 folder structure + the layer diagram | Written incrementally, Weeks 1–6 |
| **Data model / database design** | §7 — the TypeScript interfaces, the ER relationships, the SQLite schema, and the three schema decisions | Week 3 (draft) / Week 7 |
| **Algorithms** | §8. The strongest chapter you have: integer paise, largest-remainder apportionment, the reconciliation invariant, the worked example | Week 1 (draft) / Week 7 |
| **Implementation details** | Gesture system, worklets and why, OCR pipeline, share service and its fallback ladder | Week 7 |
| **UI screenshots** | `docs/screenshots/` — every screen plus every empty state | Week 7 |
| **Testing** | §13. Unit test summary, the property test, the 8-receipt OCR accuracy table, the gesture matrix, the device matrix | Week 7 |
| **Results** | What works, performance numbers, OCR accuracy across the corpus | Week 7 |
| **Limitations** | `docs/known-limitations.md` — written *as you go* rather than invented at the end | Weeks 5–7 |
| **Future scope** | Tier 3 + the rejected list, **with reasons for rejection**. "I considered AI and concluded it added nothing" is a strong paragraph. | Week 7 |
| **Conclusion** | Week 8 | |
| **References** | Expo, Reanimated, Gesture Handler, ML Kit docs; anything you cite. ⚠️ **Confirm the citation style.** | Week 7 |

### Also to confirm (from §D12)

Report length and template · whether a synopsis/abstract was already due · plagiarism threshold · whether the APK is submitted or only demoed · whether the repo must be public · viva format, duration, and date · presentation slide count/time limit · whether a hardcopy is required.

### Presentation deck — 8–10 slides

1. Title
2. The problem (be concrete — the ₹640 dish the vegetarian didn't eat)
3. The solution in one sentence + one screenshot
4. Architecture diagram
5. **The calculation algorithm** — largest remainder and the invariant. *This is your differentiator; do not skip it for another screenshot.*
6. The gesture system — why worklets
7. OCR + why it is deliberately not load-bearing
8. Live demo
9. Testing + results
10. Limitations & future scope

### Viva preparation — rehearse answers to these

- Why no backend? *(All participants are physically co-located; requiring five installs is worse product design and more work. Offline-first is a feature.)*
- Why not split equally by default? *(Equal splitting systematically overcharges whoever ate least. That's the actual problem.)*
- How do you guarantee the totals add up? *(Integer paise, largest-remainder apportionment, and a property test over 1 000 random bills. Want to see it run?)*
- Why Reanimated worklets? *(JS-thread animation drops frames under load; drag must run on the UI thread.)*
- Why no tab bar? *(It's a linear workflow, not parallel sections.)*
- What happens when OCR fails? *(Nothing important — it populates a screen that already works without it. Here, let me deny the camera permission and show you.)*
- Why SQLite and not AsyncStorage? *(bills → items → people → assignments is genuinely relational; a join table makes many-to-many the default and duplicate assignment structurally impossible.)*
- Why store no totals in the database? *(Derived data can go stale. Totals are always recomputed from inputs.)*
- Did you consider adding AI? *(Yes, and I concluded it added nothing. There's no point in this app where a language model earns its inclusion.)*
- What would you build next? *(Fractional splits, UPI deep-links — and here's why I deliberately didn't build sync.)*
- What was hardest? *(The drag/scroll gesture conflict, and here's specifically how I resolved it: long-press activation plus a portal layer above the ScrollView.)*
- What would you do differently? *(Have a real answer ready. "Nothing" is the worst possible response.)*

---

# 21. Claude Code Development Protocol

Claude Code will write most of this app. The failure mode is not bad code — it is **large, uncontrolled, unverifiable changes** that you cannot review and that break things you did not know were connected. The protocol below exists entirely to prevent that.

### The loop — one unit of work at a time

```
1.  ORIENT      "Read DIVVY_ROADMAP.md §<n> and the files in <dir>. Summarise
                 the current state in 5 lines. Do not write code."

2.  SCOPE       You state ONE unit of work. One unit = one file, or one
                 component, or one function plus its tests. Never "build Phase 3."

3.  PLAN        "Propose an implementation plan. List every file you will
                 create or modify. Do not write code yet."

4.  GATE  ← YOU  Read the file list. If it touches more than ~4 files, or a
                 file you didn't expect, say NO and re-scope. This gate is the
                 single most valuable step in the protocol.

5.  IMPLEMENT   "Implement exactly that plan. Do not refactor anything outside
                 the listed files."

6.  VERIFY      "Run npm run check." (typecheck + lint + test)
                 It must report actual output, not a claim of success.

7.  REVIEW ← YOU  Read the diff. Not skim — read. If you don't understand a
                 line, ask before accepting. You will be asked about this code
                 in a viva by someone who assumes you wrote it.

8.  MANUAL      Run it on your phone. Types passing is not the same as working.

9.  COMMIT      "Write a conventional commit message for these changes."
                 Then: git add -p; git commit; git push origin dev

10. LOG         Update the checkbox in §16. Note anything surprising in
                 docs/spike-log.md.
```

### Session-opener prompt (paste this at the start of every session)

```
Read DIVVY_ROADMAP.md. We are in Phase <N>, Week <W>.

Today's single unit of work: <one specific thing>

Rules for this session:
- src/core/ must never import react, react-native, expo, or the store.
- All money is integer paise. Never a float. Never rupees in a variable.
- No hardcoded colours or spacing — everything from src/ui/theme/tokens.ts.
- Do not add a dependency without asking me first.
- Do not touch files outside the plan you propose.
- Do not build anything from the "explicitly rejected" list in §5.
- Animation comes in Phase 6. Do not animate anything before then.

Start by summarising the current state of the relevant files in 5 lines.
Then propose a plan. Do not write code until I approve it.
```

### Rules that prevent the specific failure modes of this project

| Rule | Why |
|---|---|
| **Never "implement Phase N."** One unit per prompt. | Phase-sized prompts produce 30-file diffs you cannot review. |
| **Plan before code, always.** | The file list is your only early warning. |
| **Reject any plan touching > ~4 files** unless you expected it. | Scope creep is invisible until it isn't. |
| **Tests in the same unit as the code.** | "I'll add tests later" means never. |
| **`npm run check` after every unit**, with real output. | An agent claiming success is not evidence of success. |
| **Commit after every green unit.** | Small commits = a bisectable history and a real safety net. |
| **You run it on the phone.** | Nothing in this project's risk profile is verifiable from a terminal. |
| **No new dependency without your explicit yes.** | The dependency list in the spec is deliberate. |
| **Ask it to explain unfamiliar code before accepting it.** | You are defending this in a viva. |
| **Point at this roadmap rather than re-explaining.** | "Per §8, use largest remainder" is precise, short, and consistent. |

### Where Claude Code is strongest on this project

`src/core/` and its tests (pure functions, clear specification, immediately verifiable) · `parseReceipt.ts` against fixtures · boilerplate screens from a spec · the SQLite layer · sweeping for hardcoded colours and missing states · drafting report sections *from the actual code* · README and architecture docs.

### Where **you** must lead

**Gesture feel.** No agent can tell you whether a spring is right. That is your hands, your phone, three days.
**The tuning loop.** Snap thresholds, long-press duration, haptic timing.
**Design judgement.** Which empty state illustration, which colour, which copy.
**Knowing when to stop.** The hard stops and scope cuts in this document are decisions only you can make.
**Understanding the code.** In a viva, "Claude wrote that part" is the worst sentence available to you. Read every diff.

### A warning worth internalising

The most likely way this project goes wrong is not that Claude Code writes bad code. It is that it writes *plausible* code across many files, quickly, in an area you have not yet formed an opinion about — and you accept it because it typechecks. Two weeks later something is subtly wrong with the money and you cannot find it, because you never actually read the apportionment function.

**The engine's property test is your defence against exactly that.** Write it in Week 1. Run it constantly. It is 40 lines and it is the difference between hoping the maths is right and knowing.

---

## Today, 1 September 2026

Three things, in this order:

1. **Email your course coordinator** the §D12 questions. It costs you ten minutes and unblocks §20.
2. **Photograph 8 real restaurant receipts.** You cannot build or test this project without them, and they are the easiest thing to keep postponing.
3. **Start Spike 0.** Get a development build with a native module onto your physical Android phone. Hard stop: end of tomorrow.

Nothing else. Not the folder structure, not the tokens file, not a single component.

Go.
