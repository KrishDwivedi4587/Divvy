# Three-Day Check-in Plan

Written 3 November 2026. This document records why the project's direction
changed for the check-in, what was built, and what was deliberately left for
later. `DIVVY_ROADMAP.md` is the original planning document and has **not** been
edited; this file sits beside it and explains where the two differ.

---

## 1. The original direction

The roadmap (written 1 September) planned a longer product on Android hardware:

- A Samsung Galaxy Note 9 as the demo device
- On-device OCR through Google ML Kit
- A drag-and-drop gesture system to assign items to people
- SQLite history, Zustand state, a rendered share card
- Submission on 31 October

By 1 September the calculation engine (milestone **M1**, tag `v0.1-m1-engine`) was
complete and proven: 127 tests including a 1,000-bill property test. The
hardware-dependent spikes (ML Kit at runtime, gesture feel, share image) were
blocked on a physical Android phone that was never connected.

## 2. What changed

| Then                                | Now                                  |
| ----------------------------------- | ------------------------------------ |
| Android phone (Galaxy Note 9)       | **iPhone 17**                        |
| Android-oriented ML Kit integration | Must work on iOS, from Windows       |
| Long-horizon plan to 31 October     | **A working demo in three days**     |
| Gestures and OCR as the centrepiece | A reliable photo → bill → split flow |

**The Windows constraint.** Native iOS apps cannot be built on Windows. Xcode is
macOS-only, and Expo's cloud build service (EAS) needs a paid Apple Developer
Program membership to sign an iOS build. Neither is available. So everything
below is designed to run **inside Expo Go**, which loads the app's JavaScript over
the network and needs no local build.

## 3. Platform findings

Researched against Expo's own pages, not assumed. Dates matter here: this
changed during 2026.

- **App Store Expo Go supports SDK 57.** Expo's changelog entry of 3 September
  2026,
  [Login now required for running projects in Expo Go](https://expo.dev/changelog/expo-go-57-login),
  says Expo Go "has recently been updated in the Apple App Store, and now supports
  projects running on Expo SDK 57".
- **A free Expo account login is required on iOS**, in both the terminal
  (`npx expo login`) and the Expo Go app, using the same account. This was
  introduced in the same entry. It does not apply to simulators or development
  builds.
- **The Apple Developer Program / `eas go` instructions** on the Expo Go docs
  page, and in the
  [May 2026 changelog](https://expo.dev/changelog/expo-go-and-app-store-may-2026),
  describe building your own Expo Go through TestFlight. That is for SDKs the
  store does not carry. It does not apply to this project.
- **Unverified risk: SDK 58 shipped on 15 October 2026.** It is not possible
  from here to see which SDK the App Store's Expo Go currently supports. If it has
  moved to SDK 58 and dropped 57, the project will not open. The setup guide has a
  check and fallbacks; see [`docs/ios-demo.md`](ios-demo.md).
- **`expo-image-picker` is included in Expo Go.** So are `expo-image`,
  `expo-symbols`, Reanimated and Gesture Handler. Everything the demo uses is
  available.
- **ML Kit is not.** It is a native module Expo Go cannot load, and Expo's own
  dependency checker also reports it as "untested on New Architecture".

## 4. Decisions

| Decision                                                     | Why                                                                                                                                                                 |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Run in Expo Go on SDK 58 (was 57; see section 11)            | The only iOS route available from Windows without a paid account                                                                                                    |
| `expo-image-picker` for **both** camera and gallery          | One package, one result type, one workflow. The camera opens the system camera, which behaves identically in Expo Go and a production build                         |
| Gallery needs no permission                                  | iOS's picker runs out of process (PHPicker); the app only ever receives the single photo chosen                                                                     |
| **OCR deferred**; manual entry with the photo kept on screen | ML Kit cannot run in Expo Go. This is the roadmap's own pre-approved Fallback B ("camera as reference, not extraction"), so it is a planned fallback, not a retreat |
| No state library; `useReducer` + Context                     | One small tree of screens. The logic lives in a pure, tested reducer. Zustand stays out of the dependency list                                                      |
| Equal split between participants                             | The calculation engine already supports per-item assignment; the _interface_ for it (drag, or tap-to-assign) is the deferred part                                   |
| `expo-symbols` for icons                                     | Already in the SDK; native SF Symbols on iPhone. No icon library added                                                                                              |
| Recent bills last for the session only                       | Persisting is a later phase. It is stated in the UI copy and docs rather than faked                                                                                 |
| Dark theme, one accent                                       | Kept from Unit D (roadmap T1.12)                                                                                                                                    |

### Architecture decisions that changed because of iOS

- **Platform scope.** `docs/architecture.md` said "Android-only" and Unit C
  removed the iOS config. That is reversed: iOS is now the primary platform and
  the `ios` block is back in `app.json`.
- **A `src/platform/` directory** holds native integrations (camera, gallery),
  separate from `src/core/`, which must stay free of native imports.
- **Web is a supported fallback**, not a goal. `react-native-web` was already
  installed; running the app in a browser (including iPhone Safari) is the safety
  net if Expo Go and SDK 57 do not line up.
- **Spike 0 (ML Kit on Android) stays on record.** Its build evidence is still
  valid. Its remaining runtime question is now moot for the check-in and is
  recorded as an addendum in [`spike-log.md`](spike-log.md).

## 5. Implementation sequence

Followed in this order, committed on branch `feat/ios-checkin-mvp`:

1. **Platform readiness**: Expo SDK compatibility, the only new runtime
   dependency (`expo-image-picker`), iOS config, connection scripts
2. **Pure logic**: the bridge from form text to the existing engine, plus the
   state reducer
3. **Design system**: reusable primitives built from the existing tokens
4. **Camera and gallery workflow**: one shared path, every failure state handled
5. **Bill screens**: Home, Bill details, People, Summary
6. **Verification and documentation**

## 6. What is complete

| Feature                                                | Status                                                             |
| ------------------------------------------------------ | ------------------------------------------------------------------ |
| Camera capture, preview, retake                        | Built and unit-tested; **iPhone camera not yet tried on a device** |
| Gallery upload, preview, replace                       | Built and unit-tested; **iPhone picker not yet tried on a device** |
| Permission denied / blocked / cancelled / error states | Built; branch logic unit-tested with the native module mocked      |
| Bill details with validation                           | Built; verified in a browser                                       |
| Participants (add, remove, validation)                 | Built; verified in a browser                                       |
| Summary with exact per-person amounts and breakdown    | Built; verified against hand-calculated figures                    |
| Plain-text share via the system share sheet            | Built; **share sheet needs the phone**                             |
| Recent bills (this session)                            | Built; verified in a browser                                       |
| Calculation engine                                     | Untouched since M1; 127 original tests still pass                  |

## 7. What is deferred

- **OCR / automatic reading of the receipt.** Needs a development build (a Mac or
  a paid EAS account for iOS). The photo is displayed beside manual entry instead.
  No extracted data is ever shown, because none is extracted.
- **Per-item assignment and the drag gesture.** The engine supports it; the
  interface is the work. Roadmap Spike 1 (drag feasibility) is a physical-device
  measurement and has not been run.
- **Persistence** of past bills across app restarts.
- **A rendered share image.** Text sharing is built; the image card is not.
- **Discount entry in the UI.** The engine supports discounts; the form does not
  expose them yet.
- **A custom app icon and splash screen.** Still Expo's defaults.

## 8. What needs the iPhone

Everything marked "built" above has been exercised on **web only** (a browser at
iPhone width) or in unit tests. None of it has run on an iPhone. These need real
hardware, in this order of importance:

1. Expo Go opens the project at all (SDK compatibility: see §3)
2. **Take photo** opens the iPhone camera, and the captured photo reaches Preview
3. **Upload from gallery** opens the photo picker, and the chosen photo reaches Preview
4. Camera permission prompt, and the "Camera access is off" state with Settings
5. Keyboard behaviour on the decimal pad (see the guide), safe areas, the notch
6. The share sheet

A step-by-step script is in [`docs/ios-demo.md`](ios-demo.md).

## 9. Test results

| Check                                                 | Result                                                    |
| ----------------------------------------------------- | --------------------------------------------------------- |
| `npm run check` (types, lint, format, tests)          | passes                                                    |
| Unit tests                                            | 274 across 10 suites, all passing (127 from M1, 147 new)  |
| `npx expo export --platform ios`                      | exits 0; 1,165 modules, 2.5 MB Hermes bytecode            |
| `npx expo export --platform android`                  | exits 0                                                   |
| `expo-doctor`                                         | 20/21; the remaining warning is the deliberate ML Kit one |
| Dev server answers on the LAN address from the laptop | verified (HTTP 200)                                       |
| Tunnel mode starts from this machine                  | verified ("Tunnel ready")                                 |
| End-to-end flow in a browser at 390×844               | verified                                                  |
| **On an actual iPhone 17**                            | **not yet tested**                                        |

## 10. A defect found along the way

The `apportionSigned` fuzz test from the M1 milestone failed during this work. It
asserted a sum equalled `-amount`, and in about 2.5% of runs the random amount
was 0, making `-amount` negative zero, which `Object.is` treats as different from
the `+0` the sum produces. It is a test bug, not an engine bug; the engine is
unchanged. The assertion was corrected without reducing coverage and the zero
case is now pinned by a deterministic test. See the commit message for the full
reasoning.

---

## 11. Update: upgraded to Expo SDK 58

On first launch the iPhone's Expo Go (SDK 58.0.0) rejected the project with
"Project is incompatible with this version of Expo Go". This is the unverified
risk recorded in section 3: the App Store build had moved to SDK 58 and dropped 57.
Divvy was upgraded to **SDK 58** (React Native 0.88.1, React 19.3.0, expo-router
58.0.29). Section 3's statements about SDK 57 are kept as the record of what was
known on 3 November; they no longer describe the project.

Result: 274 tests pass, `tsc` is clean, iOS, Android and web exports succeed, the
dev server serves an SDK 58 manifest and a full iOS bundle. Whether the project
now opens in the iPhone's Expo Go is **not yet confirmed on the device**. Versions
and the one code change are in [`environment.md`](environment.md) and
[`architecture.md`](architecture.md).
