# Spike 0 runbook — completing the runtime half

Everything except the device half of Spike 0 is done. This is the exact
sequence to finish it. Budget ~15 minutes, most of it install time.

**A 263 MB debug APK from the build session already exists**, so no rebuild is
needed unless JS or native config has changed since:

```
android/app/build/outputs/apk/debug/app-debug.apk
```

---

## 1. Connect the phone

On the device: Settings → About phone → tap **Build number** seven times →
back → System → Developer options → enable **USB debugging**. Plug in with a
cable that carries data (many charge-only cables do not), and accept the
"Allow USB debugging?" prompt.

```bash
adb devices -l
```

Must show a device with status `device`. If it says `unauthorized`, accept the
prompt on the phone. If nothing appears at all, the cable or the driver is the
problem, not the project.

Record for the report:

```bash
adb shell getprop ro.product.manufacturer
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.sdk
adb shell getprop ro.product.cpu.abi
```

## 2. Install

```bash
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

If the APK is stale, rebuild instead — this also installs and launches:

```bash
npx expo run:android
```

## 3. Point the app at the harness — temporary, do not commit

The harness deliberately does not live in `src/`, so it is not reachable by any
route. Wire it up by hand for the duration of the spike:

```tsx
// src/app/index.tsx — TEMPORARY
export { default } from '../../spikes/ocr/OcrSpikeScreen';
```

Revert with `git checkout src/app/index.tsx` when finished. This is the only
moment spike code touches `src/`, and it must never be committed.

Then start the dev server:

```bash
npx expo start --dev-client
```

## 4. Push a test image

**For question 1 — does the module load and does `recognize()` work?** Any photo
of printed text will do. A phone photo of a book page, a printed page, anything.
This does _not_ need the receipt fixtures.

```bash
adb shell mkdir -p /data/local/tmp/ocr
adb push some-photo.jpg /data/local/tmp/ocr/test.jpg
```

`/data/local/tmp` is used because it sidesteps Android's scoped-storage
permissions entirely — the app can read it without any runtime permission.

## 5. Run

Tap **Recognise**. The status line reports one of three things, and the
distinction is the entire point:

| Status                              | Meaning                                                         |
| ----------------------------------- | --------------------------------------------------------------- |
| `NATIVE MODULE DID NOT LOAD`        | The New Architecture interop question has failed — go to step 6 |
| `MODULE LOADED, RECOGNITION FAILED` | Module works; the URI, file, or image format is wrong           |
| `RECOGNITION OK`                    | The pipeline works. Record `text`, block and line counts        |

Raw JSON also prints in the Metro terminal between the `SPIKE 0 RAW OCR OUTPUT`
markers. Save it to `spikes/ocr/results/`.

## 6. Only if the module did not load

This is the roadmap-authorised diagnostic, and it is **diagnostic only**:

```
# android/gradle.properties
newArchEnabled=false
```

then `npx expo run:android` again. If it works with New Arch off, that is a
major compatibility finding: **stop and report it, do not leave it disabled.**
Divvy needs the New Architecture for Reanimated 4.

## 7. Then the fixtures

Once question 1 is answered, repeat step 4–5 for each of the eight receipts in
`./fixtures` (see its README) and record per-fixture results. That answers
question 2 and completes Spike 0.

---

## Afterwards

- `git checkout src/app/index.tsx` — remove the temporary wiring
- Update `spikes/spike-0-ml-kit.md` with device details and results
- Change the final decision from **PASS WITH CONDITIONS** to **PASS** or **FAIL**
  based on what actually happened
