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

## 2026-06-10 — Phase 0 accepted; Phase 1 vertical slice built

**What.** The human reviewed the Phase-0 harness output, accepted the rough
balance, and green-lit Phase 1. Built the slice per `IMPLEMENTATION.md` §4:
`sim/commands.gd` (named state mutations), `data/materials.json`, Metabolize
costs on adaptations, the Store signal/command wrappers, `tests/sim_test.gd`,
and the one-screen UI (`ui/`) — the wild with visible DEF-vs-PWR matchups,
rarity-coloured loot pops, a three-slot doll, Metabolize, and the stash. CI
gained the sim test and a headless boot smoke. Verified end-to-end on Godot
4.6.2 (all tests pass; live screenshots confirm the loop).

**Why.** Phase 1's gate is the project's #2 risk: *does getting a drop and
choosing to equip it feel good when there's a defended node to feel the
difference against?* This is the smallest build that can ask real testers.

The defaults below were chosen by the assistant to be cheap to change; flag any
that clash with taste.

### Phase 1 obtain-loop — Forage → Metabolize, no direct gear drops

**Decision.** Adaptations are not loot. The slice's drop stream is **materials**
(rarity-coloured per VISION.md §9); Metabolize spends them to build/tier-up an
adaptation, which sockets straight into its doll slot. This is VISION.md §8/§10
verbatim (drops unlock options, Metabolize pays), applied to a genes-free slice.
The "equip choice" in Phase 1 is therefore *investment order* — which slot's
path to fund from which node's material — not pick-between-items; real
alternatives-per-slot arrive with affixes/splicing in Phase 2.

### Materials get rarities — capped at "rare"

**Decision.** New `data/materials.json` (biofilm common, soft tissue common,
chitin uncommon, apex flesh rare) and a gate-1 extension: material rarity must
not exceed "rare". Epic/legendary colours are *reserved for the gene chase* so
the jackpot tier keeps its colours scarce (VISION.md §9's two streams). Crafted
gear wears tier colours: T1 common / T2 uncommon / T3 rare, same cap.

### Phase 1 doll subset & cost arc

**Decision.** The three slice slots are **mouthparts / integument / locomotion**
(dial §20.3; the legible offense/defense/speed trio). Costs are data
(`build_cost`: base · growth^(tier−1), per-adaptation material), tuned so the
arc forces node progression: biofilm builds the appendage, anemone tissue the
flaps, trilobite chitin the carapace — and only a near-full doll (power 10)
finally beats Anomalocaris (DEF 9). First build lands ~1 minute into a fresh
session, so the playtest's first-equip moment happens in the first check-in.

### Live play earns at the accrual rate

**Decision.** While the app is open, one foraging action resolves every 2.5 s at
the same per-second rates accrue() uses — attention is *not* a yield multiplier
(VISION.md §12); presence only buys decisions. Any node may be worked with no
gate: a losing matchup just yields poorly (×0.1 floor) and keeps the gene chase
closed until Power exceeds DEF, so equipping visibly changes both.

### RNG stream positions persist in the save

**Decision.** `GameState.rng_streams` stores each named stream's position
(as strings — JSON would corrupt int64s); `Rng.export_state()/import_state()`.
Without this, every app relaunch would replay the same upcoming roll sequence
from the master seed. Also makes Phase-4 notification predictions hold across
restarts.

### UI is code-built placeholder, a pure observer

**Decision.** One portrait screen (720×1280, canvas_items stretch), all widgets
built in code from content data — no hand-authored scenes to drift when rows
change. UI mutates nothing directly; it calls Store's named commands and
re-reads state on `state_changed`. Look is deliberately placeholder; the
retro-pixel theme is a later art pass. Gene/splice drops are banked on the save
but surfaced nowhere — Phase 2's job.

---

## 2026-06-11 — First self-playtest feedback; bible seed canonized

**What.** Leon played the slice, called the loop and upgrade timeline okay, and
shipped a web export to the friend cohort (Phase 1's gate is now actually
running). Two balance findings and his sign-off on the bible seed's open
decisions, all canonized below.

### Material rates now descend with node difficulty (rarity = scarcity)

**Decision.** `material_rate` bases are now 1.8 (microbial mat) / 1.4 (anemone)
/ 1.1 (trilobite) / 0.8 (anomalocaris). **What it replaced:** ascending bases
(1.0/1.2/1.5/2.0), under which the *uncommon* chitin outflowed common biofilm
once Power passed the trilobite's DEF — Leon observed it at power 6, and the
math agrees (1.8 vs 1.6/s). The rarity ladder must read true in the loot stream:
a harder node's reward is its material *type* (and, later, its genes and
splices), never raw volume — common flows fastest at every power level now.

### Yield growth feel — accepted as-is for early game

**Observation, no change.** Equipping moves yield by ×0.1 per Power point
(margin slope), which Leon reads as "no big growth yet — okay for early game."
Logged as a tuning question, not fixed: bigger growth moments should come from
Phase 2's affixes (new math terms, not bigger margins) before we steepen the
efficiency curve. Revisit if the cohort echoes it.

### Bible seed canonized (Leon's decisions, CLAUDE.md §4)

The `leon_docs/bible_seed_sea_age.md` draft is folded into the bible:

- **Mass extinction = no-wipe Dev world-event.** Confirms the locked no-reset
  structure (VISION.md §14); world events reshape the meta, never the Tree.
- **Chronology (VISION.md §20.12 — default decided).** Strict for real-named
  creatures (they appear in their real eras); invented, clearly stylized
  creatures may fill gaps — the record is incomplete — so long as they
  contradict no known biology. Canonized in `bible/world_spine.md`.
- **Aposematism → mitigation flavor.** Deterrence reduces incoming pressure; no
  accidental 7th role.
- **Mimicry / crypsis → new `stealth` role.** A real term of its own. The role
  set is now 7: `sim/validation.gd` ROLES, IMPLEMENTATION.md §3, and VISION.md
  §17's table updated together (no doc/code drift). No stealth affixes exist
  yet; the first ones arrive with Phase 2 content.
- Archetypes, the signature-creature roster, the trait→role map, and the flavor
  vocabulary now live in `bible/world_spine.md` and `bible/voice.md`. The seed
  draft is marked historical in `leon_docs/` (Leon's personal folder, now
  gitignored along with his local test builds).

---

## Open questions (current)

- **Phase 1 validation gate is running.** The web build is with the friend
  cohort (since 2026-06-10). Gather first-equip reactions and an honest
  pass/fail before Phase 2 work starts.
- **Yield growth feel.** Accepted for early game (2026-06-11, above); revisit
  the efficiency slope only if Phase 2's affixes don't supply the bigger growth
  moments.
- **Slice copy is placeholder.** "Your Main", section labels, and matchup
  verdicts ("free farm", "outgeared") need a voice pass against `bible/voice.md`.
- **Equip choice depth.** If playtesters read Metabolize as a vending machine
  rather than a build choice, add competing adaptations per slot (data only) —
  but that needs a second math term (affixes) to avoid synonym gear, i.e.
  Phase 2.
- **Clock-tampering** is accepted for now (2026-06-10, above); must be revisited
  before offline accrual ships to players.
