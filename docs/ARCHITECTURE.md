# Architecture

Divvy is a Flutter app that works entirely on the phone: no backend, no
accounts, nothing uploaded. This document describes how it is put together and
why. It describes what exists in the repository; the calculation rules are in
[CALCULATION_ENGINE.md](CALCULATION_ENGINE.md) and the receipt pipeline in
[RECEIPT_OCR.md](RECEIPT_OCR.md).

## Principles

1. **The money rules are pure Dart.** Everything that decides what a person owes
   lives in `domain/` folders with no Flutter, database or UI imports. A test
   (`test/unit/architecture/layering_test.dart`) fails if that changes. It means
   the part that must be provably right can be proven on a laptop with no phone.
2. **Dependencies point inward.** Screens depend on state, state on repositories,
   repositories on the domain. The domain depends on nothing.
3. **Platform code is behind an interface.** The camera, the text recogniser and
   file storage are each an interface in the domain with one real implementation
   in `data/`. Tests supply fakes, so no test needs a device.
4. **Nothing is faked.** There is no demo data in the product. An empty database
   shows empty states.

## Technology

| Concern             | Choice                                                         |
| ------------------- | -------------------------------------------------------------- |
| Framework           | Flutter 3.47 / Dart 3.13, Material 3 with a custom theme       |
| Navigation          | `go_router` 18 (`StatefulShellRoute` for the tabs)             |
| State management    | `flutter_riverpod` 3 (`Notifier`, `AsyncNotifier`, families)   |
| Camera and gallery  | `image_picker` 1.2                                             |
| OCR                 | `google_mlkit_text_recognition` 0.17 (on-device)               |
| Database            | SQLite via `sqflite` 2.4                                       |
| Files               | `path_provider`, `path`                                        |
| Formatting, ids     | `intl`, `uuid`                                                 |
| Tests               | `flutter_test`, `integration_test`, `sqflite_common_ffi` (dev) |

`sqflite_common_ffi` is a dev dependency only: it lets the real SQLite run on a
development machine so the repositories are tested for real rather than mocked.
Exact versions are pinned by `pubspec.lock`. No code generation is used, so there
is no `build_runner` step.

## Directory structure

```
lib/
  main.dart                 opens the database, runs the app
  app/
    app.dart                MaterialApp.router, theme mode, status bar style
    router/                 route table, route constants, navigation helpers
    shell/                  the tab frame and bottom bar
    theme/                  colour roles and the Material 3 theme
  core/
    constants/              spacing and radii, app info
    errors/                 DomainError
    utils/                  currency formatting, dates, decimal input, ids
    widgets/                shared widgets (button, card, avatar, notice, ...)
  data/
    database/               schema, migrations, AppDatabase
    repositories/           SQLite repositories, local receipt storage
  features/
    bills/                  the engine, the draft, saving, detail, the create flow
      domain/engine/        money, split, apportion, settle (pure Dart)
      domain/models/        Bill, Settlement, BillRecord (pure Dart)
      application/          draft notifier, BillService
      presentation/         create/ (5 steps) and detail/
    receipt_scanning/       recognition, the parser, photo capture
    people/                 saved people and the rules for names
    history/                bill list rows, search and filters
    home/                   the home screen
    account/                settings, privacy, about
  shared/providers/         wiring: repositories, services, data providers
test/                       unit, data, widget tests and fixtures
integration_test/           the main journey, for a device
tool/                       generate_app_icons.dart
```

Each feature that has logic is split into `domain` (pure), `application` (state
and use cases), `data` (plugins) and `presentation` (screens), but only where a
layer has something in it. No empty folders exist for symmetry.

## Navigation

`lib/app/router/app_router.dart` defines every route; `routes.dart` holds the
paths as constants so no screen writes a path string.

- Four tabs, **Home, Bills, People, Account**, sit in a
  `StatefulShellRoute.indexedStack`. Each tab keeps its own navigation history,
  and tapping the active tab returns it to its first screen.
- The centre **New** button is an action, not a tab: it starts a bill and opens
  `/create` on the root navigator, covering the tab bar.
- The Create Bill flow is five nested routes (`/create`, `preview`, `review`,
  `people`, `split`, `summary`). State lives in a provider, not in the route, so
  going back never loses what was entered.
- A bill (`/bills/:billId`) and a person (`/people/:personId`) are root routes,
  reachable from Home, the lists and each other.
- After saving, the app goes to Bills and pushes the saved bill on top, so Back
  returns to the list. An unknown address shows a "Page not found" screen with a
  way home.

## State management

Riverpod, without code generation. Three kinds of provider:

- **Infrastructure** (`shared/providers/app_providers.dart`): the database, the
  receipt folder, the clock and id generator, the repositories, `BillService`, the
  photo source, the text recogniser and the parser. `main` overrides the database
  and receipt folder with the real ones; tests override everything.
- **Data** (`shared/providers/data_providers.dart`): the people, bills, balances,
  settings, recent activity and per-bill/per-person lookups. Every one of them
  watches a single **data revision** counter. Any write (`BillActions`,
  `PeopleActions`) bumps it, so one save refreshes Home, History, the balances and
  every open page. No screen refreshes anything by hand.
- **Flow state**: `billDraftProvider` is the bill being built (a `BillDraft`),
  `scanProvider` is the state of reading a photo, and `photoCaptureProvider` is
  camera/gallery busy and problem state.

`ProviderScope` is created with `retry` disabled. Riverpod 3 retries a failed
provider by default, which for a local database error would hide the problem
behind endless re-reads.

## The Create Bill flow

```
Source ──► Preview ──► Review ──► People ──► Split ──► Summary ──► save
(camera,   (retake,    (edit     (add,       (equal,   (final       (BillService)
 gallery,   replace,    items,    saved       by item,  numbers)
 manual)    read)       charges)  people)     amounts)
```

Every step edits the same `BillDraft` through `BillDraftNotifier`. The draft is
pure data that can convert itself to the engine's `Bill`
(`toEngineBill`), compute live totals, and list exactly what stops it being saved
(`problems`): no items, fewer than two people, an unassigned item, no payer,
custom amounts that do not add up. The screens only show what the draft says.

**Saving** (`BillService.save`): refuse an incomplete draft; copy the photo into
app storage; write the whole bill in one SQLite transaction; if that fails,
remove the copied photo. The database and the file system cannot share a
transaction, so the order is chosen to fail safe.

## Database

SQLite, schema version 1, in `lib/data/database/schema.dart`. Money columns are
`INTEGER` minor units; dates are text; foreign keys are on.

```
people(id, name, color_index, is_self, created_at, archived_at)
bills(id, title, merchant, bill_date, created_at, currency, split_mode,
      receipt_path, ocr_text, payer_participant_id,
      items_subtotal, grand_total, unassigned_total)
bill_participants(id, bill_id, person_id, name, initials, color_index,
                  position, subtotal, total, settled_at)
bill_items(id, bill_id, name, quantity, unit_price, line_total, source,
           ocr_confidence, raw_text, position)
item_allocations(item_id, participant_id)
bill_adjustments(id, bill_id, label, kind, mode, value, position, base,
                 is_negative)
settings(key, value)
```

Design decisions that protect data:

- **Participants are per-bill snapshots.** A bill stores each person's name,
  initials and totals itself; `person_id` is only a link back (set to NULL if the
  person is hard-deleted). Renaming a person never changes a past bill.
- **People with history are archived, not deleted.** A person on any bill is
  hidden from pickers but kept, so history and balances stay intact. A person on
  no bills is deleted outright. The account holder (`is_self`, enforced unique by
  a partial index) cannot be removed.
- **A bill is written atomically.** A failure part-way leaves zero rows in all
  five bill tables (tested).
- **Receipt paths are relative** (`receipts/<billId>.jpg`), resolved against the
  documents directory at read time. The absolute path of an iOS app container
  changes between installs and updates; an absolute path would orphan every
  stored receipt. Paths are validated before use and cannot climb out of the
  receipts folder.
- **Shares are snapshotted, and also recomputed.** Totals are stored when a bill
  is saved (for lists and balances). The detail screen recomputes from the stored
  inputs and shows a warning if they ever disagree.
- **Migrations are ordered and transactional.** `AppDatabase.runMigrations` runs
  each version in turn inside the upgrade transaction and throws if a step is
  missing, so an upgrade can never be half-applied. Version 1 is the first
  schema, so there are no migrations yet; the mechanism is tested with synthetic
  migrations, including one that fails part-way and must roll back.

### Outstanding balances

Each bill records who paid. Everyone else on it owes the payer their total until
marked paid. A person's balance is the net, from the account holder's side, of
what they owe the holder minus what the holder owes them, **kept per currency and
never added across currencies**. Only people saved in the People list appear in
balances.

## Design system

`lib/app/theme/` holds the single source of visual truth; `lib/core/widgets/`
holds the components built on it. Screens do not style themselves.

- **Monochrome.** Ink on near-white, or the inverse in dark mode, separated by
  hairline borders instead of shadows. The only hues are a muted red for errors
  and destructive actions and an amber for things to double-check, and neither
  carries meaning alone: warnings always have an icon and words.
- **Type.** Inter (bundled, SIL Open Font Licence, shown in the About screen's
  licences) with tabular figures for every amount so digits stay aligned.
- **Avatars** are initials on one of eight neutral tones, so identity never
  depends on colour.
- **Large text and small screens.** Layouts reflow rather than clip: list rows
  stack at large text sizes, the tab bar caps its own label scale, and chips
  shrink with an ellipsis. A test lays out 13 screens at 5 sizes and 3 text
  scales to keep it that way.
