# Divvy — submission materials

| File | What it is |
| --- | --- |
| `Divvy_Project_Presentation.pptx` | 15-slide deck, 16:9, fully editable (diagrams are native shapes) |
| `Divvy_Project_Presentation.pdf` | PDF export of the deck |
| `Divvy_A3_Project_Poster.pptx` | Editable poster, page set to A3 portrait (297 × 420 mm) |
| `Divvy_A3_Project_Poster.pdf` | Print-ready poster PDF, 297 × 420 mm, fonts embedded |

## Visual identity

- **Palette** (from `src/ui/theme/tokens.ts`): navy `#0B1220` · raised `#131C2E` ·
  indigo accent `#6B4EEA` · light canvas `#F4F6FA` · success mint `#34D399` /
  `#0E9F6E` · avatar colours orange `#FB923C`, amber `#FBBF24`, mint `#34D399`
- **Type:** Segoe UI Semibold (headings), Segoe UI (body). Both ship with Windows
  and Office for Windows. On a Mac, present the **PDF**.
- **Status key:** filled/solid = implemented in the app today; outlined/dashed =
  part of the final release.

## Honesty notes

- Phone screens marked **App screenshot** are real captures of the running app
  (Expo web build at 390 × 844, iPhone-sized), taken on 4 Nov 2026.
- Screens marked **Concept design** (receipt scanning, item assignment) are
  mockups for the final release, built from the app's own design tokens.
- The Spice Table receipt is a **sample bill** made for the demo.
- Every money figure comes from the project's own engine (`computeSettlement`);
  the item-wise example is the one in `docs/money-model.md`.

## Folders

- `assets/screenshots/` raw app screenshots · `assets/mockups/` the same in phone frames
- `assets/concepts/` concept screens · `assets/brand/` logo and sample receipt
- `assets/icons/` Lucide icons (ISC licence) in brand colours
- `assets/diagrams/` high-resolution renders of the diagram slides
- `assets/previews/` PNG preview of every slide and the poster

## Regenerating

```bash
cd submission/source
python build_presentation.py
python build_poster.py
```

`source/asset-pipeline/` holds the scripts that captured the screenshots
(`flow.js`), produced the mockups, concepts and icons (`assets.js`) and checked
the worked example against the engine (`example.js`). They need Node,
`puppeteer-core` and `lucide-static`, plus Chrome installed.
