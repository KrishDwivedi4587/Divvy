# Divvy

Split a restaurant bill fairly. Photograph a receipt, add the people, and see
exactly what each person owes, to the paisa.

Mobile App Development mini project. Flutter and Dart, Material 3, built for the
iPhone and also configured for Android. It works entirely on the phone: no
backend, no accounts, nothing uploaded.

> **Status:** feature complete and covered by automated tests (analysis, 798
> unit, data and widget tests). It has **not been run on a physical iPhone or an
> emulator**: development has been on Windows, which cannot build for iOS. See
> [What still needs a real device](#what-still-needs-a-real-device).

## What it does

1. **Take a photo** of a bill, or **upload one** from the gallery. Divvy reads
   it straight away: items, prices, quantities, taxes and charges, the date, the
   merchant and the total.
2. **Check what was read.** Anything uncertain is marked. Fix a price, add or
   delete an item, correct the receipt's total, or add a missing charge. If
   nothing could be read, enter the bill by hand.
3. **Add the people**, from the saved list or new.
4. **Split it**: equally, by item (each item shared by whoever had it), or by
   custom amounts.
5. **Save it.** The bill, its receipt photo and each person's share are kept on
   the phone. Past bills can be searched, sorted, filtered by date, opened, and
   marked as paid back. People, balances and settings live on their own tabs.

The amounts come from a calculation engine that works in integer paise and
guarantees the shares add up to the total exactly
([how](docs/CALCULATION_ENGINE.md)). How a photo becomes a bill is in
[docs/RECEIPT_OCR.md](docs/RECEIPT_OCR.md), and how the app is put together is in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Run it

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.47 or
later, with Dart 3.13).

```bash
flutter pub get
flutter run
```

`flutter run` picks a connected phone or emulator; `flutter devices` lists them.

Receipt reading uses Google ML Kit and the database uses SQLite, both of which
need a phone, so the app runs on **iOS and Android only**: it will not run on the
web or as a Windows desktop app.

### iPhone

Building for iOS needs a **Mac with Xcode**. Flutter cannot build iOS on Windows.

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run -d <your iPhone>
```

- The minimum iOS version is **15.5**, which ML Kit requires. It is set in
  `ios/Podfile` and the Xcode project.
- The camera and photo-library descriptions are already in
  `ios/Runner/Info.plist`. The photo picker runs out of process, so the app
  never needs library permission.
- To install on your own iPhone, open `ios/Runner.xcworkspace` in Xcode and pick
  your team under Signing & Capabilities.

### Android

```bash
flutter pub get
flutter run -d <your device or emulator>
```

## Checks

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

`flutter test` runs everything: the engine (including a 1,000-bill property
test), the receipt parser, the SQLite repositories on a real database, and the
screens, with a full create-to-restart journey. Widget tests save screenshots to
`build/screens/` for looking at the design.

## What still needs a real device

These are covered by tests with fakes, but have not been seen working on a phone:

- The camera and the photo library, including the permission prompts.
- Real ML Kit recognition: it is tested through a fake recogniser and one
  photographed sample, not on a range of real receipts.
- Reading speed and memory on a large photo.
- The look and feel on an iPhone 17: safe areas, the keyboard, scrolling and the
  status bar. These are checked at iPhone-sized layouts in tests, not on the
  device.

## Not in this version

- Only the Latin script is recognised. Receipts in other scripts are read badly
  or not at all, and are entered by hand.
- No sync, backup or export: the bills live on one phone. "Delete all data" in
  Account erases them.
- No notifications and no payments: Divvy records who owes whom, and does not move
  money.
