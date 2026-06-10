# Decisions

Append-only, dated log of design/plan decisions: **what changed, why, what it
replaced** (`CLAUDE.md` §1, §4). The working docs hold only current truth; this
file holds the history so no one has to reconstruct "why did we do X?" from chat.

---

## 2026-06-10 — Phase 0 foundation laid

**What.** Scaffolded the testable economy core and the content pipeline per
`IMPLEMENTATION.md` §8 first-sprint: `sim/` (rng, game_state, lineage,
adaptation_instance, content, resolve, accrual, validation), `data/` (sea-age
shallow-benthos starter content), `tests/` (validate_data + economy_test, both
headless), `tools/chart_chase.py`, the `bible/`, the two autoload shells, and a
CI workflow.

**Why.** Prove the chase curve in numbers before building UI (the project's #1
risk). This is the foundation everything else hangs on.

### Engine — Godot 4.6 + typed GDScript (confirmed)

The human created the Godot project (Mobile renderer) during the session. We
stay on Godot + GDScript as `IMPLEMENTATION.md` locks; sim code is **typed**
GDScript for refactor safety. The human runs Godot locally (it is not in the
assistant's sandbox), so the assistant scaffolds everything to run headless and
lints GDScript with `gdtoolkit` instead.

### Chase variance — pure independent rolls, no pity ("true RPG")

**Decision.** The legendary chase uses pure independent rolls. No pity / no
pseudo-random-distribution safety net, for now.

**Why.** The target audience (OSRS, IdleOn) is used to and *likes* the
unprotected grind; it's the authentic RPG feel and the cheaper thing to build.
This is an **experiment**: `tests/economy_test.gd` reports the p10/p50/p90
dry-streak (check-ins between legendaries), so we measure the unlucky tail rather
than guess. Revisit a pity mechanism only if the unlucky decile is shown to
churn. Within `VISION.md` §20 dial #5 (drop-rate constants); the never-flat
*shape* (§9a) stays locked.

### Offline accrual of discrete events — Poisson process (approved)

**Decision.** `accrue()` integrates continuous yields (materials) in closed form
(`rate · Δt`), and samples discrete rare events (the gene chase) as a **Poisson
process** — exponential inter-arrivals from a dedicated per-lineage seeded RNG
stream — costing O(#events), not O(#ticks).

**What it replaced.** The plan's shorthand `earnings = f(node, lineage, Δt)`
(`IMPLEMENTATION.md` §1), which is only valid for continuous materials, not for
discrete jackpots. `IMPLEMENTATION.md` §1–2 updated to match. Buys reproducibility
(offline batch == what a notification predicted) and predictability (when the
next event lands) — the basis for free local notifications (§16, Phase 4).

### RNG — named seeded streams over one master seed

**Decision.** `sim/rng.gd` derives an independent stream per concern (gene rolls,
splice, accrual, gene-pick) from one stored `master_seed`. Realizes the plan's
"seeded RNG" intent so offline accrual is replayable and notification-predictable
(it can't be if all systems share one interleaved stream).

### Save versioning — schema_version + migration hook (partial)

**Decision.** `GameState` carries `SCHEMA_VERSION`; `state_store.gd` has a
near-passthrough `_migrate_and_load`. The save format needs *some* shape, and the
Tree must survive years of patches (`VISION.md` §14), so the field + hook go in
now. Real migration steps land when the first breaking change arrives (YAGNI).

### resolve() vs accrue()

`resolve()` models **one foraging action**; `accrue()` integrates **long offline
gaps** using the *same* rate helpers in `resolve.gd`. One economy, two evaluation
strategies — not two code paths to keep in sync.

### Title — Cradle of Life

**Decision.** The game is titled **Cradle of Life** (matches the repo/project
name). Replaces the prior working title *The Long Game*. Canonized in `VISION.md`
(header, §20 #1), `IMPLEMENTATION.md`, `CLAUDE.md`, and `README.md`. The
Tree-of-Life concept is unchanged.

### Clock-tampering — accepted for now

**Decision.** The offline-time exploit (set the phone clock forward, harvest, set
it back) is **accepted as a known risk for now**; no defense is built. Revisit
before offline accrual ships to real players. Closes review gap #3 for now.

### Phase 0 harness — verified on Godot 4.6.2

Ran the real engine headless (`/home/leon/Apps/godot`, Godot 4.6.2-stable): gate 1
PASS, and the economy harness runs end-to-end. With placeholder constants the
6-week / 2-lineage arc gives ~11.6 small-gene events per check-in (min 5 — never a
dead session) under a legendary every ~13 check-ins median (p90 18, max 33). The
two-tier shape holds and never flattens. The constants are **not** balanced — a
legendary every ~4 days is likely too generous for "brutal" — but the harness and
the never-flat shape are proven. Also fixed a bug where `chart_chase.py` read the
post-reset dry-streak column and reported zeros; it now computes streaks from the
`legendaries` column and matches the GDScript exactly.

---

## Open questions (current)

- **Phase-0 constant tuning.** The constants in `data/` are placeholders, not
  balance. The harness runs and the never-flat *shape* is proven (see above); the
  live Phase-0 work is tuning the legendary cadence toward "brutal" and confirming
  the curve across longer arcs — before any Phase-1 UI.
- **Clock-tampering** is accepted for now (above); must be revisited before
  offline accrual ships to players.
