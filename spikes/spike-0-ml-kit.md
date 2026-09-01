# Spike 0 — Native Build + ML Kit OCR

**Date:** 1 September 2026 · **Branch:** `dev` · **Baseline commit:** `6b3ccec`

---

## Objective

Roadmap §4 Spike 0: prove that an Expo development build containing a **native
module** can be produced and run on a **physical Android device**, and that
on-device ML Kit returns usable text.

The roadmap's stated success condition is exact:

> "raw OCR text from a real photo appears in your terminal, on your phone, over
> USB or LAN."

It matters because it gates everything else (§3 Rank 1: _"Everything else
depends on this"_).

---

## Environment

|                       |                                                          |
| --------------------- | -------------------------------------------------------- |
| OS                    | Windows 11 · 10.0.26200.9168                             |
| Node / npm            | v24.13.0 / 11.6.2                                        |
| Expo CLI              | 57.0.20                                                  |
| Expo SDK              | ~57.0.18                                                 |
| React Native          | 0.86.3                                                   |
| React                 | 19.2.3                                                   |
| TypeScript            | ~6.0.3                                                   |
| JDK (via `JAVA_HOME`) | 21.0.10 (Android Studio JBR)                             |
| Android SDK           | platform 36 + 36.1, build-tools 36.0.0 / 36.1.0 / 37.0.0 |
| Gradle                | 9.3.1                                                    |
| `newArchEnabled`      | **true**                                                 |
| Device connected      | **No**                                                   |

---

## Chosen ML Kit package

**`@react-native-ml-kit/text-recognition@2.0.0`** (MIT, 32 KB, zero JS deps).

Chosen over the alternatives:

| Candidate                                           | Last publish | Verdict                                                                        |
| --------------------------------------------------- | ------------ | ------------------------------------------------------------------------------ |
| `@react-native-ml-kit/text-recognition` 2.0.0       | 2025-09      | **Chosen** — actively maintained, no JS deps, recognises from a plain file URI |
| `react-native-vision-camera-text-recognition` 3.1.1 | 2024-08      | Rejected — stale, and drags in the whole vision-camera stack                   |
| `expo-text-recognition` 0.1.1                       | 2024-07      | Rejected — v0.1.x, unmaintained                                                |

It is the package the roadmap already named, and re-checking confirmed that
choice rather than overturning it.

**Its API fits the planned architecture directly.** `TextRecognition.recognize(uri)`
takes a **local file URI** — no camera required for recognition — and returns
`{ text, blocks: [{ text, frame, lines: [{ text, frame }] }] }`. That maps
one-to-one onto the roadmap's `RecognizedLine[]`, so the planned
`recognize → parseReceipt` split needs no adaptation.

**It is a legacy (Paper) native module**, not a TurboModule: `codegenConfig` is
absent and the source extends `ReactContextBaseJavaModule`. Under
`newArchEnabled=true` it therefore depends on React Native's legacy interop
layer. **Whether that works at runtime is the single most important unanswered
question in this spike.**

---

## Installation

One production dependency:

```
npm install @react-native-ml-kit/text-recognition@^2.0.0
```

No spike-only dependencies were installed. `expo-asset`, used by the harness, was
already present transitively via `expo`.

---

## Native build

```
npx expo prebuild --platform android --no-install
cd android && ./gradlew assembleDebug
```

### ✅ BUILD SUCCESSFUL in 15m 42s — 487 tasks, Gradle exit 0

Verified by artifact, not by exit code alone:

- `android/app/build/outputs/apk/debug/app-debug.apk` — **263 MB**
- `:react-native-ml-kit_text-recognition` Gradle tasks executed
- Autolinking manifest lists `@react-native-ml-kit/text-recognition`
- APK contains **71** ML Kit entries, including
  `lib/{arm64-v8a,armeabi-v7a,x86,x86_64}/libmlkit_google_ocr_pipeline.so`
- Reanimated 4.5.1 and Gesture Handler 2.32 also assembled cleanly under the
  New Architecture

**This retires the "will not build at all" branch of the roadmap's Fallback B.**
The module's old-style `implementation 'com.facebook.react:react-native:+'`
dependency — the most likely breakage point — resolved without intervention.

---

## Device

### ❌ NOT PERFORMED

| Check                           | Result                       |
| ------------------------------- | ---------------------------- |
| Device connected                | **No** — `adb devices` empty |
| adb detected it                 | No                           |
| App installed                   | No                           |
| App launched                    | No                           |
| ML Kit module loaded at runtime | **Unknown**                  |
| OCR returned text               | **Unknown**                  |

The roadmap's success condition explicitly requires the phone. **It has not been
met.** Compiling is not running: the legacy-interop question (above) is a
_runtime_ question that a successful Gradle build cannot answer.

---

## OCR experiment

### ❌ NOT PERFORMED — no fixtures

`spikes/ocr/fixtures/` is empty. No receipt images have been supplied, and none
were fabricated: synthetic or stock receipts are cleaner than real thermal
prints and would have produced a falsely reassuring result, which is the exact
failure mode roadmap §1 D1 warns about.

A harness is ready at `spikes/ocr/OcrSpikeScreen.tsx` — **written but never
executed**. It loads bundled fixtures, calls `recognize()` on each sequentially,
records elapsed time / char / block / line counts, and dumps the **raw**
response as JSON. It performs no parsing.

---

## Results

| Fixture | OCR returned text? | Major text captured? | Major errors | Usability |
| ------- | ------------------ | -------------------- | ------------ | --------- |
| r1–r8   | **Not run**        | —                    | —            | —         |

No result may be inferred from the successful build.

---

## Problems

1. **Gradle wrapper could not download its distribution.** `SocketTimeoutException`
   after 10 s, twice. `curl` reached `services.gradle.org` in 40 ms, so the
   network was fine — `services.gradle.org` 307-redirects to GitHub release
   assets, and the wrapper's hard-coded 10 s connect timeout died on that hop.
   The cache held a stale zero-byte `.part` file, so retries failed identically.
   **Fixed** by computing the wrapper's cache path (base36 of the MD5 of the
   distribution URL → `23ovyewtku6u96viwx3xl3oks`) and placing a `curl`-fetched,
   byte-exact 137,037,885-byte zip there. Reproducible if it recurs.

2. **A pipeline exit code was misread as success.** `./gradlew … | tail -60`
   reports `tail`'s status, not Gradle's. The first "exit 0" was wrong and the
   build had actually failed. Subsequent runs captured `$?` directly and were
   confirmed against the APK artifact. Worth remembering: for native builds,
   **verify the artifact, not the exit code**.

3. **Gradle auto-installed** Android SDK Platform 36 and Build-Tools 36.0.0
   mid-build (only 36.1 was present) and accepted their licences.

4. **263 MB debug APK.** ML Kit ships an ~11 MB OCR pipeline per ABI across four
   ABIs, plus bundled models for scripts Divvy will never use — the package
   unconditionally depends on Latin **and** Chinese, Devanagari, Japanese and
   Korean recognisers. See _Consequence for architecture_.

5. **`expo prebuild` modified tracked files** as a side effect: it stamped
   `android.package = "com.anonymous.divvy"` into `app.json` and rewrote the
   `android`/`ios` npm scripts to `expo run:*`. The package name is a real
   production decision — changing it later means regenerating native code.

---

## Decision

# PASS WITH CONDITIONS

**What is proven:** the exact Divvy stack — Expo SDK 57, RN 0.86.3, New
Architecture enabled, Windows, JDK 21, local Gradle — compiles a debug APK with
ML Kit linked and its native OCR libraries packaged. Reanimated 4 and Gesture
Handler build alongside it. Local building is viable; EAS is not required.

**What is not proven, and blocks a full PASS:**

1. **Runtime module load.** ML Kit is a legacy Paper module under
   `newArchEnabled=true`; it depends on RN's interop layer. Compiling proves
   nothing about this.
2. **That OCR returns text at all** on a device.
3. **OCR quality on real Indian receipts** — no fixtures exist.

**Conditions to convert this to PASS:**

- Connect a physical Android device, `npx expo run:android`, launch, and confirm
  `recognize()` returns non-empty text from one real printed document.
- If the module fails to load under New Arch, retry with
  `newArchEnabled=false` in `android/gradle.properties` before concluding
  anything — that isolates interop as the cause and is a one-line test.

**Fallback status:** Fallback B ("ML Kit will not build at all → drop OCR") is
**not** triggered. It builds.

---

## Consequence for architecture

**The planned `recognize → parseReceipt` split is unchanged and confirmed
well-chosen.** `recognize(uri)` returns exactly the block/line/frame shape the
roadmap's `RecognizedLine[]` assumes, and it accepts a file URI, so:

- `src/ocr/recognize.ts` stays a thin impure wrapper (~20 lines).
- `src/ocr/parseReceipt.ts` stays pure and fixture-testable.
- Saving raw responses as JSON fixtures — the thing that lets the parser be
  developed on a laptop with no camera — works as designed.

**Nothing in the architecture is changed by this spike.** Roadmap D1 (OCR is an
accelerator, never load-bearing) stands, and is _reinforced_: OCR still has two
unproven runtime dependencies, so building the manual path first remains right.

**One new production consideration — APK size.** 263 MB is a debug build (four
ABIs, no minification), so it is not the submission figure. But the ML Kit
package pulls five script recognisers unconditionally. For Phase 5, consider
excluding the unused ones:

```gradle
// android/app/build.gradle
configurations.all {
  exclude group: 'com.google.mlkit', module: 'text-recognition-chinese'
  exclude group: 'com.google.mlkit', module: 'text-recognition-japanese'
  exclude group: 'com.google.mlkit', module: 'text-recognition-korean'
}
```

keeping Latin and Devanagari. Combined with a release build and ABI splits this
should fall dramatically. **Not done in this spike** — it is a production task,
and it must be re-validated on a device.

---

## Next actions

1. **Supply 8 receipt photographs** — see `spikes/ocr/fixtures/README.md`. On the
   critical path; roughly twenty minutes.
2. **Connect an Android device** and complete the runtime half of this spike.
3. Decide the real Android package name before native code is regenerated.
