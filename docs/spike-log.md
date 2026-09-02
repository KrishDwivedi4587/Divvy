# Spike Log

The authoritative record of every technical spike: what was asked, what was
actually demonstrated, and what was decided. Roadmap §4 defines all five.

**Nothing here is marked PASS unless the roadmap's own success criterion was
actually demonstrated.** Where a criterion needs hardware, the status says so
rather than being inferred from source inspection or a build succeeding.

Last updated: 1 September 2026.

| Spike | Subject                               | Status                               |
| ----- | ------------------------------------- | ------------------------------------ |
| 0     | Dev build + native module + ML Kit    | **PASS WITH CONDITIONS**             |
| 1     | Drag, hit-test, scroll conflict       | **PENDING HARDWARE**                 |
| 2     | OCR quality on real Indian bills      | **PENDING HARDWARE + FIXTURES**      |
| 3     | Centre-hold two-person split          | **NOT STARTED** (blocked by Spike 1) |
| 4     | Rendering + sharing the summary image | **PENDING HARDWARE**                 |

Hard stop for all five: **Sunday 13 September**. Roadmap §4: _"If any spike is
unresolved on 13 September, take its fallback that day and proceed."_

---

## Spike 0 — Development build with a native module

**Question.** Can this exact stack — Expo SDK 57, RN 0.86.3, New Architecture,
Windows, JDK 21 — build a development APK containing a native module, and does
on-device OCR return usable text?

**Hypothesis.** The build would be the hard part (roadmap §3 Rank 1: _"the
highest risk item in the project… Everything else depends on this"_).

**Environment.** Windows 11 · Node 24.13.0 · Expo CLI 57.0.20 · RN 0.86.3 ·
`JAVA_HOME` → JDK 21.0.10 (Android Studio JBR) · Android SDK platform 36 ·
Gradle 9.3.1 · `newArchEnabled=true`.

**Experiment.** Compared three ML Kit packages, chose
`@react-native-ml-kit/text-recognition@2.0.0`, ran `expo prebuild` then
`gradlew assembleDebug`.

**Result — build: SUCCESS.** 15m 42s, 487 tasks, Gradle exit 0.

**Evidence** (artifact, not exit code):

- `android/app/build/outputs/apk/debug/app-debug.apk` — 263 MB
- `:react-native-ml-kit_text-recognition` Gradle tasks executed
- Autolinking manifest lists the package
- APK contains 71 ML Kit entries incl.
  `lib/{arm64-v8a,armeabi-v7a,x86,x86_64}/libmlkit_google_ocr_pipeline.so`
- Reanimated 4.5.1 and Gesture Handler 2.32 assembled cleanly under New Arch

The module's legacy `com.facebook.react:react-native:+` coordinate — the most
likely breakage point — resolved without intervention.

**Result — runtime: NOT DEMONSTRATED.** No Android device has been connected.
Verified twice, most recently by `adb kill-server && adb start-server` followed
by an empty `adb devices`, plus a Windows PnP enumeration finding no WPD,
`AndroidUsbDeviceClass` or USB portable device.

**Decision: PASS WITH CONDITIONS.** The build risk is retired; Fallback B ("ML
Kit will not build at all → drop OCR") is **not** triggered. The architecture is
unchanged.

**Remaining validation** — all require the phone:

1. The native module _loads_ at runtime. It is a legacy Paper module
   (`codegenConfig` absent) running under `newArchEnabled=true`, so it depends
   on RN's interop layer. **A successful compile says nothing about this.**
2. `recognize()` returns non-empty text from a real photo.

Procedure: `spikes/ocr/RUNBOOK.md`. The APK already exists, so this is an
`adb install` plus a temporary one-line route edit — roughly 15 minutes. The
harness reports _module did not load_ separately from _recognition failed_,
because that distinction is the entire diagnostic.

If the module fails to load, the roadmap authorises one diagnostic:
`newArchEnabled=false` in `android/gradle.properties`. **Diagnostic only** — if
it works only with New Arch off, that is a major compatibility finding to report,
not a change to leave in place. Reanimated 4 requires the New Architecture.

**Production notes raised by this spike** (not acted on — Phase 5):

- The package pulls **five** script recognisers unconditionally (Latin, Chinese,
  Devanagari, Japanese, Korean). Excluding the three unused ones should cut APK
  size substantially.
- `expo prebuild` stamped the placeholder Android package
  `com.anonymous.divvy` into `app.json`. Changing it later means regenerating
  native code, so decide it early.

---

## Spike 1 — Drag, hit-test, and the scroll conflict

**Question.** Can an item chip be dragged out of a scrolling list and reliably
hit-tested against avatar drop targets?

**Why it matters.** Roadmap §3 Rank 2. If dragging does not feel good, the app's
premise — _make the item-to-person mapping physical_ — collapses.

**Status: PENDING HARDWARE. Not started.**

**Success criteria (roadmap §4) — all five are physical measurements:**

1. Chip follows the finger with no perceptible lag **on a physical device**
2. Chip stays visible outside the ScrollView bounds (portal layer works)
3. Correct avatar identified on ≥ 19 of 20 attempts
4. Normal vertical scrolling of the chip list still works
5. No dropped frames when dragging fast

**Why the emulator cannot close this.** Roadmap §13.4 is explicit: _"spring
tuning is meaningless on an emulator… emulator input timing is fundamentally
different."_ The one local AVD is additionally configured with
`hw.gpu.enabled=no` (software rendering), so its frame behaviour is actively
misleading. Mouse input is not finger input, and there are no haptics.

**Not started deliberately.** Building the prototype now would produce code
whose only purpose is to be measured, measured against nothing. The dependencies
it needs are already present (Gesture Handler 2.32, Reanimated 4.5.1,
react-native-worklets 0.10.1 — all shipped with the template and confirmed
building in Spike 0), so there is no procurement risk to retire early.

**Fallback if it fails:** tap-to-select → tap-to-assign. Fast, reliable, keeps
every downstream feature, and is defensible as an accessibility argument
(one-handed, usable with motor impairments). Loses the signature interaction,
not the app.

**Gates:** Phase 2 (the gesture system) and Spike 3.

---

## Spike 2 — OCR quality on real Indian restaurant bills

**Question.** Across 8 real receipts, what fraction of true line items pair
correctly as name + amount?

**Status: PENDING HARDWARE + FIXTURES. Not started.**

**Success criterion:** **≥ 60%** of true line items correctly paired. Sixty, not
ninety — at 60% the user corrects four items in ten and still saves time.

**Blocked on two independent inputs:**

1. **8 real receipt photographs** — none supplied. Requirements in
   `spikes/ocr/fixtures/README.md`: 2 clean thermal, 1 faded, 1 with visible
   quantities, 1 with service charge + GST, 1 with a discount line, 1 with a
   non-Latin script line, 1 genuinely messy.
2. **A device** — ML Kit recognition runs on-device only. There is no way to run
   it on the laptop.

**No synthetic fixtures were created.** Generated text images are far cleaner
than real thermal prints; a good score on them would be actively misleading
about the risk roadmap D1 names (_"thermal-printed Indian restaurant bills OCR
badly"_). Any synthetic fixture that ever exists must be labelled synthetic and
kept separate from the real corpus.

**Two fixture artifacts, not one** — the roadmap uses one word for both:

- `spikes/ocr/fixtures/` — the **source photographs**, spike input.
- `src/ocr/fixtures/` — the **raw ML Kit JSON dumps**, which become permanent
  production test fixtures for `parseReceipt` (roadmap §13.2). These are
  generated _by_ running Spike 2, so they cannot exist before it runs.

That JSON corpus is what later lets the parser be developed and regression-tested
on a laptop with no camera and no device — a parser change can never silently
fix one receipt while breaking another.

**Trap flagged by the roadmap:** do not write a restaurant-specific parser to
push 60% to 75%. Cap parser work at 1.5 days. The correct investment is the
correction UI.

**Fallbacks:** 30–60% → ship OCR, frame the review screen as "check these".
< 30% → camera-as-reference mode, photo pinned above manual entry.

---

## Spike 3 — The centre-hold two-person split gesture

**Question.** Is the dead-zone between two avatars discoverable without
instruction, and does it avoid misfiring when dragging past two avatars toward a
third?

**Status: NOT STARTED — blocked by sequencing, then by hardware.**

**The roadmap forbids starting it yet.** §4 Spike 3: _"Do not start it until
Spike 1 has passed"_, and _"extend the Spike 1 rig"_ — the rig does not exist.
Building `spikes/split/` now would invert the roadmap's own dependency order and
produce a prototype resting on an unvalidated foundation.

**It is also optional by design.** Roadmap D2: multi-assignment is a property of
the **data model**, not of a gesture — `assignments[itemId]` is an array of
person ids, and the engine already handles k assignees for any k ≥ 1, proven by
the Phase 1 tests. This spike tests a _shortcut_ for the two-person case, not a
capability.

**Success criterion** is explicitly a human trial: another person, handed the
phone with no instruction, discovers it.

**Fallback:** cut the gesture; long-press → "Split between…" sheet with
checkboxes. **That sheet ships regardless of the spike outcome** — it is the only
way to express a 3+ way split, and it is Tier 1.

---

## Spike 4 — Rendering and sharing the summary image

**Question.** Does `react-native-view-shot` → PNG → `expo-sharing` reliably put a
legible image into a WhatsApp chat from a physical Android device?

**Status: PENDING HARDWARE. Not started.**

**Success criterion:** a readable PNG lands in a real WhatsApp chat **from your
physical device**. Every term in that sentence is device-bound; a laptop
prototype cannot answer any part of it.

**Not started deliberately, and no dependencies installed.** It needs
`react-native-view-shot` and `expo-sharing`, neither currently present. Adding
native dependencies forces a fresh ~16-minute native rebuild, and installing them
to support a prototype that cannot be executed defers the same rebuild to the
device session anyway. They should be installed in the same sitting as the
device.

**Roadmap §3 Rank 4 already decides the main design question**, independent of
the spike: **never capture an off-screen view.** S7 is a real full-screen route
showing the exact card, and its ref is what gets captured. That removes the
entire class of blank-capture bugs, and is better UX besides — you see what you
send.

**Fallback ladder:**

- **A.** Off-screen capture fails → capture on-screen only _(already the plan)_
- **B.** view-shot broken → `expo-media-library` save-to-gallery, share manually
- **C.** Nothing image-based works → `Share.share({ message })` plain text.
  **Keep this permanently as the error path regardless of the outcome** — and
  expose it as a "Copy as text" action, since text is copy-pasteable and
  searchable in a group chat.

Note that layer C is pure logic (`Settlement` → `string`) and therefore fully
testable without hardware. It belongs in `src/share/buildShareText.ts` in
Phase 4, not duplicated into a spike.

---

## What can and cannot be closed today

**Every one of the five spikes requires the physical Android device.** That is
not a workaround being avoided — recognition, gesture feel, frame rate, haptics,
the share sheet and WhatsApp delivery are all runtime properties of real
hardware.

| Needs                      | Spikes                  |
| -------------------------- | ----------------------- |
| Physical Android device    | 0 (runtime), 1, 2, 3, 4 |
| 8 real receipt photographs | 2                       |
| Spike 1 to pass first      | 3                       |

**Nothing is blocked on engineering time.** The Phase 1 calculation engine is
complete and proven precisely because it was designed to need none of the above.
