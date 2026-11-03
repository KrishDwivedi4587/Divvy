# Development Environment

Verified 1 September 2026 (Phase 0, Units A–B). Every value below was read from
this machine — nothing here is assumed. Re-verify before trusting it later.

## Machine

|      |                                     |
| ---- | ----------------------------------- |
| OS   | Windows 11, version 10.0.26200.9168 |
| Node | v24.13.0                            |
| npm  | 11.6.2                              |
| Git  | 2.52.0.windows.1                    |

## Project

|              |                           |
| ------------ | ------------------------- |
| Expo SDK     | `~58.0.22`                |
| React Native | `0.88.1`                  |
| React        | `19.3.0`                  |
| expo-router  | `~58.0.29`                |
| TypeScript   | `~6.0.3` (`strict: true`) |

Expo 58 API reference: https://docs.expo.dev/versions/v58.0.0/

## ⚠️ JDK — read this before any Android build

Two different JDKs are visible on this machine, and **the one on `PATH` is not
the one Gradle uses**:

| Source                                                          | Version                                             |
| --------------------------------------------------------------- | --------------------------------------------------- |
| `java` on `PATH`                                                | **25.0.2** — not supported by Android Gradle Plugin |
| **`JAVA_HOME`** → `C:\Program Files\Android\Android Studio\jbr` | **21.0.10** ✅                                      |

**Gradle resolves its JDK from `JAVA_HOME`, not from `PATH`.** Since `JAVA_HOME`
points at Android Studio's bundled JDK 21, local Android builds are expected to
work as-is.

**Rule: leave `JAVA_HOME` pointing at the Android Studio JBR.** Do not "fix" the
PATH JDK to match, and do not set `JAVA_HOME` to JDK 25. If a Gradle build fails
with a Java-version error, check `JAVA_HOME` first — it is the most likely cause.

### Correction to roadmap D10

Roadmap §1 D10 states that JDK 25 blocks Android builds and recommends EAS cloud
builds as the primary path. **That was written before `JAVA_HOME` was inspected
and is inaccurate for this machine.** `JAVA_HOME` is JDK 21 and the Android SDK
is installed locally, so `npx expo run:android` is the intended primary build
path; EAS remains the documented fallback.

The roadmap has deliberately **not** been edited. This note is the correction of
record until D10 is revised with evidence from Spike 0.

## Android SDK

|                |                                           |
| -------------- | ----------------------------------------- |
| `ANDROID_HOME` | `C:\Users\ASUS\AppData\Local\Android\Sdk` |
| Platforms      | `android-36.1`                            |
| Build-tools    | `36.1.0`, `37.0.0`                        |
| adb            | 1.0.41, on `PATH`                         |

## Physical device

**No Android device is currently connected** (`adb devices` returns an empty
list). This is **temporary and not a blocker** — a suitable physical device will
be arranged when required.

Per roadmap §13.4, these must be verified on real hardware and **cannot** be
signed off from an emulator:

- Gesture feel and spring tuning
- Haptics
- Real camera capture of a printed receipt
- ML Kit on-device behaviour and latency
- Frame rate during drag (release build)
- Share sheet and WhatsApp delivery
- Final APK verification

An emulator may be used for interim _functional_ development. It is never final
evidence for the items above.

> The one local AVD (`Practical_Emulator`) is configured with
> `hw.gpu.enabled=no` (software rendering) and an emulated camera, so it is
> unsuitable for judging animation performance or capturing receipts.

## Not yet installed

`eas-cli` is not installed. Not needed while local builds are the primary path.

---

## iOS and Expo Go (added 3 November 2026)

The demo device changed from an Android phone to an **iPhone 17**. The
development machine is still Windows. Verified on this laptop:

|                                      |                                                                                                                           |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| Expo SDK                             | 58 (`~58.0.22`; `npx expo install --check` reports "Dependencies are up to date")                                         |
| `expo-doctor`                        | 19/20; the one warning is `@react-native-ml-kit/text-recognition` "untested on New Architecture", left visible on purpose |
| `npx expo export --platform ios`     | exit 0 (2.7 MB Hermes bytecode); Android also exit 0 (3 MB)                                                               |
| Dev server on the LAN address        | HTTP 200 (`192.168.29.181:8081` at the time)                                                                              |
| Tunnel mode (`npm run start:tunnel`) | starts and prints a tunnel URL (SDK 58 CLI no longer prints "Tunnel ready")                                               |
| Network category                     | **Public** (Windows), with inbound **Allow** rules for Node.js on the Public profile                                      |
| `npx expo whoami`                    | **Not logged in**; an Expo login is required before an iPhone can open the project                                        |

**What Windows cannot do:** build a native iOS app. Xcode is macOS-only, and EAS
cloud builds for iOS need a paid Apple Developer Program membership. Everything is
therefore designed for **Expo Go**, which loads the JavaScript over the network.

**Resolved by the SDK 58 upgrade:** the iPhone's Expo Go reported SDK 58 and rejected
the SDK 57 project, so Divvy moved to SDK 58. See below.

The Android toolchain notes above are unchanged and still accurate; they apply to
the spike work in `spikes/`.

### SDK 58 upgrade (3 November 2026)

Node 24.13.0 meets SDK 58's requirement (22.13+, 24.3+, or 26+). The upgrade used
`npx expo install expo@^58.0.0` then `npx expo install --fix`.

| Package                        | SDK 57  | SDK 58  |
| ------------------------------ | ------- | ------- |
| expo                           | 57.0.31 | 58.0.22 |
| react-native                   | 0.86.3  | 0.88.1  |
| react / react-dom              | 19.2.3  | 19.3.0  |
| expo-router                    | 57.0.29 | 58.0.29 |
| expo-image-picker              | 57.0.20 | 58.0.10 |
| expo-symbols                   | 57.0.3  | 58.0.4  |
| react-native-reanimated        | 4.5.1   | 4.7.1   |
| react-native-worklets          | 0.10.1  | 0.13.0  |
| react-native-gesture-handler   | 2.32.0  | 3.3.0   |
| react-native-screens           | 4.26.x  | 4.30.1  |
| react-native-safe-area-context | 5.7.0   | 5.10.1  |
| @types/react                   | 19.2.x  | 19.3.0  |

npm refused the first in-place install (an `ERESOLVE` on `expo-symbols`, an
optional peer of `expo-router` 58, caused by the SDK 57 lockfile holding old
ranges). It was resolved without `--force` or `--legacy-peer-deps` by deleting
`node_modules` and `package-lock.json` and running `npm install` against the
SDK 58 `package.json`. Transitive dependencies in the lockfile were therefore
re-resolved; all 274 tests still pass.

The generated, git-ignored `android/` folder from Spike 0 is still the SDK 57
prebuild. Expo Go does not use it; delete and regenerate it before any native
Android build.
