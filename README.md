# Cradle of Life

Evolution as an idle RPG. You don't play one creature — you play its whole **Tree
of Life**, a clade you grow, gear, and specialize over deep time, while the Devs
(natural selection) ship patches that reshape the world. Mobile-first, idle ·
RPG · growth, built for long-term live operation.

> **Read the docs first.** `VISION.md` (what the game is), `SPINE.md` (what the
> code is now), `IMPLEMENTATION.md` (architecture & process), `ROADMAP.md` (what
> we build next, in order), `CLAUDE.md` (how we work), `DECISIONS.md` (why things
> changed). The docs are the source of truth; the code must match them.

## Status — clean spine; rebuilding (2026-06-15)

A working prototype was built (chase harness, Power-vs-defense loop, equipment
doll, the 7-role affix set, splicing, offline accrual, a playable check-in).
Cohort feedback showed the *engine* is sound but the *feel* wasn't there yet —
dull, illegible progression, the chase not landing. So the project **reset to the
spine** (done 2026-06-15): the class tree is parked (role derives from the doll),
content is trimmed to a clean single-niche starter, and the never-flat chase is
re-proven on the clean core. **`SPINE.md`** describes the base; the rebuild — an
**active verb**, legible progression, the chase landing — is sequenced in
**`ROADMAP.md`** "Next", built from the vision, not the parked code. The *why* is
in `DECISIONS.md`.

## Layout

```
sim/        Pure GDScript, NO Node — the testable core (rng, state, resolve,
            accrual, commands = the named state mutations)
data/       All content as JSON — authored + AI-assisted, never engine
tests/      Headless scripts: validate_data (gate 1), sim_test (commands),
            economy_test (chase model)
tools/      chart_chase.py — charts the harness output (analysis only, never the model)
bible/      Content ground truth: world spine, voice, per-niche science refs
ui/         Control nodes only; a pure observer of state_store
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

# The named-command layer under the UI (forage / metabolize / assign):
godot --headless --script res://tests/sim_test.gd

# The chase-curve model — prints the loot distribution and the 6-week arc,
# and writes a per-check-in CSV (path is printed at the end):
godot --headless --script res://tests/economy_test.gd

# Chart that CSV (the harness prints its absolute path under Godot's user:// dir):
python3 tools/chart_chase.py /path/to/chase.csv

# Play the slice (or just press Play in the editor):
godot
```

CI (`.github/workflows/ci.yml`) runs the headless scripts plus a boot smoke of
the main scene on every push.
