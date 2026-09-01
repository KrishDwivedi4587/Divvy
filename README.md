# Divvy

Split a restaurant bill by assigning each item to the people who actually ate it,
and see what everyone owes.

Mobile App Development mini project — React Native / Expo, Android, offline-only.

> **Status: in development (Phase 0 — foundation).**
> The app currently renders a placeholder screen. No bill, assignment, OCR,
> persistence or sharing functionality exists yet.

## Requirements

- Node.js (developed against v24)
- Android SDK
- `JAVA_HOME` pointing at a JDK 21 installation — see [`docs/environment.md`](docs/environment.md)

## Getting started

```bash
npm install
npx expo start
```

## Project layout

- `src/app/` — Expo Router routes (routes only; see architecture doc)
- `docs/` — architecture, environment and spike notes
- `spikes/` — disposable technical experiments, never imported by `src/`

## Documentation

| File                                           | Contents                             |
| ---------------------------------------------- | ------------------------------------ |
| [`DIVVY_ROADMAP.md`](DIVVY_ROADMAP.md)         | Plan, scope decisions, schedule      |
| [`docs/architecture.md`](docs/architecture.md) | Structure and separation of concerns |
| [`docs/environment.md`](docs/environment.md)   | Verified toolchain, JDK notes        |
| [`spikes/README.md`](spikes/README.md)         | Spike rules and planned spikes       |

Built with [Expo](https://expo.dev) SDK 57 and
[Expo Router](https://docs.expo.dev/router/introduction/).
