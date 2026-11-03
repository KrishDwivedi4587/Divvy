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
| Expo SDK     | `~57.0.18`                |
| React Native | `0.86.3`                  |
| React        | `19.2.3`                  |
| expo-router  | `~57.0.17`                |
| TypeScript   | `~6.0.3` (`strict: true`) |

Expo 57 API reference: https://docs.expo.dev/versions/v57.0.0/

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
| Expo SDK                             | ~57 (packages aligned to the current 57.x patch levels)                                                                   |
| `expo-doctor`                        | 20/21; the one warning is `@react-native-ml-kit/text-recognition` "untested on New Architecture", left visible on purpose |
| `npx expo export --platform ios`     | exit 0 (1,165 modules, 2.5 MB Hermes bytecode)                                                                            |
| Dev server on the LAN address        | HTTP 200 (`192.168.29.181:8081` at the time)                                                                              |
| Tunnel mode (`npm run start:tunnel`) | starts, reports "Tunnel ready"                                                                                            |
| Network category                     | **Public** (Windows), with inbound **Allow** rules for Node.js on the Public profile                                      |
| `npx expo whoami`                    | **Not logged in**; an Expo login is required before an iPhone can open the project                                        |

**What Windows cannot do:** build a native iOS app. Xcode is macOS-only, and EAS
cloud builds for iOS need a paid Apple Developer Program membership. Everything is
therefore designed for **Expo Go**, which loads the JavaScript over the network.

**Not verifiable from here:** which Expo SDK the App Store's Expo Go currently
supports. Expo's changelog (3 Sep 2026) says SDK 57; SDK 58 shipped on 15 Oct. See
[`ios-demo.md`](ios-demo.md) for the check and fallbacks.

The Android toolchain notes above are unchanged and still accurate; they apply to
the spike work in `spikes/`.
