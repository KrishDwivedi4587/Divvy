# OCR fixtures — NOT YET SUPPLIED

This directory is **empty on purpose**. Spike 0 cannot measure OCR quality
without real receipts, and fabricating them would produce a falsely optimistic
result — the exact failure the roadmap warns about (§1 D1: "thermal-printed
Indian restaurant bills OCR badly").

## What is needed

Eight photographs, `r1.jpg` … `r8.jpg`, dropped in this directory:

| File     | Should be                                                 |
| -------- | --------------------------------------------------------- |
| `r1.jpg` | Clean thermal print                                       |
| `r2.jpg` | Clean thermal print, a different restaurant/format        |
| `r3.jpg` | Faded or low-contrast                                     |
| `r4.jpg` | Visible quantities (`2 x Butter Naan`)                    |
| `r5.jpg` | Service charge **and** GST/CGST/SGST shown separately     |
| `r6.jpg` | Contains a discount line                                  |
| `r7.jpg` | Contains a non-Latin script line (Devanagari or Gujarati) |
| `r8.jpg` | Genuinely messy — crumpled, angled, or poorly lit         |

Roadmap §4 Spike 2 defines this corpus and its per-receipt targets. Collecting
it is listed as on the critical path and takes about twenty minutes.

## Rules

- **Real receipts only.** Photograph what you actually have; ask friends and
  family. Do not use stock or synthetic images — they are cleaner than reality
  and would make OCR look better than it is.
- **Shoot them the way a user would:** handheld, indoor lighting, whatever angle
  you naturally hold a phone at. A perfectly flat, evenly lit scan is not the
  input this app receives.
- **Redact personal data** before committing: card digits, phone numbers, names,
  any UPI/QR block. A black rectangle over them is fine and does not affect the
  line items OCR needs to read.
- These are **test fixtures**, not production assets. They stay under `spikes/`
  and are never imported by `src/`.

## Why the same eight are reused later

Once these exist, Spike 2 runs ML Kit over each and saves the **raw recognition
output** as JSON. That JSON becomes the permanent fixture set for
`parseReceipt`, so the parser can be developed and regression-tested on a
laptop with no camera, no device and no build — and so a parser change can
never silently fix one receipt while breaking another.
