# Divvy

Split a restaurant bill fairly. Photograph a receipt, add the people, and see
exactly what each person owes, to the paisa.

Mobile App Development mini project. React Native, Expo SDK 58, TypeScript. It
runs on an **iPhone through Expo Go**, developed from Windows, and works entirely
on the device: no backend, no accounts, nothing uploaded.

> **Status:** a working MVP for the three-day check-in. The core flow is built and
> verified on web and in unit tests. It has **not yet been run on an iPhone**.

## What it does

1. **Take a photo** of a bill, or **upload one** from the gallery
2. Preview it; retake or replace it
3. Enter the amount, tax, tip and any extra charges
4. Add the people
5. See each person's exact share, with a breakdown, and share it as text

The amounts come from a calculation engine that works in integer paise and
guarantees the shares add up to the total exactly. It has 127 tests, including a
1,000-bill property test.

## Not in this version

- **No OCR.** The photo is shown beside manual entry; nothing is read from it
  and no extracted values are ever displayed. Reading receipts needs a native
  module that Expo Go cannot load.
- **Equal split only.** Splitting by item is planned for a later version.
- **Recent bills last for the session.** They are not saved to the device yet.

## Run it on an iPhone

You need a free [Expo](https://expo.dev/signup) account, **Expo Go** from the
App Store, and the iPhone on the same Wi-Fi as the laptop.

```bash
npm install
npx expo login        # sign in; also sign in inside Expo Go
npx expo start --clear
```

Scan the QR code with the iPhone's Camera app.

If the Wi-Fi blocks the connection (campus networks often do):

```bash
npm run start:tunnel
```

To try it in a browser instead:

```bash
npx expo start --web
```

## Checks

```bash
npm run check         # typecheck, lint, format and tests
```

## Project layout

- `src/app/` — Expo Router screens (routes only)
- `src/core/` — the calculation engine and form-to-bill logic; pure TypeScript
- `src/ui/` — design tokens and reusable components
- `src/features/` — photo and bill features
- `src/platform/` — camera and gallery access
- `src/store/` — state for the bill being built

Built with [Expo](https://expo.dev) and
[Expo Router](https://docs.expo.dev/router/introduction/).
