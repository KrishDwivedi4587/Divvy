# Spikes

## Purpose

Spikes answer a technical feasibility question **before** we commit to a
production architecture. The output of a spike is a **decision**, not code.

Each spike asks one question that could change the plan if the answer is "no",
and each has a hard time limit. When the limit is reached, we take the
documented fallback and move on the same day.

## Rules

- Spikes are **disposable**.
- Spikes are **not** production features.
- **Production code under `src/` must never import from `spikes/`.**
- Spike results are **documented** — findings outlive the code.
- A successful spike **informs** a later production implementation; the
  production version is written fresh in `src/`, not promoted from here.
- A failed spike **prevents wasted implementation effort**. That is a success.
- Spike code may be **deleted** once its findings are captured.

Findings are recorded in `docs/spike-log.md`: what was attempted, the exact
environment, the result, the evidence, the decision, and any fallback adopted.

## Planned spikes

| Spike | Question | Directory |
|---|---|---|
| **Spike 0** | Can a native module run in an Expo development build on a physical Android device? Does on-device OCR return usable text? | `spikes/native/` |
| **Spike 1** | Can an item chip be dragged out of a scrolling list and reliably hit-tested against avatar drop targets? | `spikes/drag/` |

Neither spike is implemented yet. Both require validation on a **physical
Android device** — an emulator is acceptable for interim functional development
but is never final evidence for gesture feel, haptics, camera capture, or frame
rate.

See `DIVVY_ROADMAP.md` §4 for each spike's success criteria, time limit, and
fallback.
