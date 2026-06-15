# WORKORDER_<NAME>.md — <one-line goal>

> Temporary executable work order (CLAUDE.md §5a). Signed before code, deleted on
> close with decisions moved to DECISIONS.md. If this disagrees with VISION /
> ROADMAP / SPINE / DECISIONS, those win.
> **Status: DESIGN — awaiting sign-off before any code.**

## Precondition
- [ ] The prior increment's validation gate passed (or this is the first).
- [ ] Harness green on `main` before starting.
- [ ] This design signed.

## Grounding contract (cite the sources; verify the code by reading it)
- **Vision:** §§ … — the locked truth this serves.
- **Roadmap item:** "Next" → … .
- **Decisions:** … — the dated entries this derives from.
- **Code it touches (verified by reading):** `file:symbol` — current behavior … .
- **[NEW — needs sign-off]:** … — anything not traceable to a doc or the code.

## Keep-list (must survive)
- … — locked concepts from VISION "What's locked" this must not break.

## Kill-list (must NOT reappear — build from the vision, not the parked code)
- … — parked/overthrown concepts (the class tree, `niche_mult`, loot-as-gear, …).

## Design (sign before any code)
… the mechanic, the data shape, the math, the UI — concrete enough to sign.
Flag every open fork explicitly.

Signed by: __________

## Work packages (small, one concern each)
- **WP1 — …** (sim / data / ui). Tests: … . Re-prove harness? Y/N.
- **WP2 — …**

## Validation
- **Harness (§9a):** the re-prove expectation if the economy changes.
- **Gates:** which content gates apply (orthogonality / science / voice).
- **Gate question:** the fun/quality question real play must answer.

## Canonize-on-close checklist
- [ ] Owning docs updated in place; superseded concepts deleted.
- [ ] DECISIONS.md entry appended (what / why / what it replaced).
- [ ] SPINE.md refreshed to match the new code.
- [ ] This file deleted.
