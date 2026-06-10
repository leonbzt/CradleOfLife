# Cradle of Life

Evolution as an idle RPG. You don't play one creature — you play its whole **Tree
of Life**, a clade you grow, gear, and class up over deep time, while the Devs
(natural selection) ship patches that reshape the world. Mobile-first, idle ·
RPG · growth, built for long-term live operation.

> **Read the docs first.** `VISION.md` (what the game is), `IMPLEMENTATION.md`
> (how/when we build), `CLAUDE.md` (how we work), `DECISIONS.md` (why things
> changed). The docs are the source of truth; the code must match them.

## Status — Phase 0: the economy harness + the bible

We validate the **chase curve in numbers before building any UI** — with no
completion endpoint, the chase is the entire long-game pull, so if it ever goes
flat the game dies (`VISION.md` §5, §9a). This repo currently holds the testable
economy core, the content pipeline with gate 1, and the starter bible.

## Layout

```
sim/        Pure GDScript, NO Node — the testable core (rng, state, resolve, accrual)
data/       All content as JSON — authored + AI-assisted, never engine
tests/      Headless scripts: validate_data (gate 1) + economy_test (chase model)
tools/      chart_chase.py — charts the harness output (analysis only, never the model)
bible/      Content ground truth: world spine, voice, per-niche science refs
data_loader.gd / state_store.gd   Thin autoload Node shells over sim/
```

## Architecture invariants (full detail in `IMPLEMENTATION.md` §1–2)

- The **simulation stays out of the scene tree**: `sim/` is `RefCounted`, runs
  headless, is unit-testable without a window.
- **One `resolve()`** for Eat and Fight — two engines would be two balance burdens.
- **Offline accrual is closed-form**, never frame-ticked: materials integrate in
  closed form; rare gene events are sampled as a Poisson process (reproducible
  and predictable, the basis for free local notifications).
- **Content is data; the engine is small and hand-written.** AI authors rows,
  never the engine. Every row passes three gates (orthogonality, science, voice).

## Running it

Requires **Godot 4.6** on your PATH (editor or headless build). From the repo root:

```bash
# First time, or after adding/renaming scripts — registers class_names:
godot --headless --import

# Content gate 1 — fails non-zero on a bad affix or dangling reference:
godot --headless --script res://tests/validate_data.gd

# The chase-curve model — prints the loot distribution and the 6-week arc,
# and writes a per-check-in CSV (path is printed at the end):
godot --headless --script res://tests/economy_test.gd

# Chart that CSV (the harness prints its absolute path under Godot's user:// dir):
python3 tools/chart_chase.py /path/to/chase.csv
```

CI (`.github/workflows/ci.yml`) runs the two headless scripts on every push.
