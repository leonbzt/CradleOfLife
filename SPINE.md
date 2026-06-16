# SPINE.md — the clean base

> The one-page source of truth for **what the code actually is** after the
> reset-to-spine (DECISIONS.md 2026-06-15). This is the *trailhead*: a small,
> legible, vision-agnostic base the rebuild climbs from. For *what the game is*
> see VISION.md; for *what we build next* see ROADMAP.md "Next"; for *why* see
> DECISIONS.md. If this doc and the code disagree, the code is the bug or this
> doc is stale — fix whichever is wrong in the same session.

## The architecture (kept — vision-agnostic, do not erode)

- **Node-free `sim/`.** State, `resolve()`, `accrue()` are plain `RefCounted`
  GDScript with no `Node` dependency, so they run headless and unit-test without
  a window. `ui/` only observes the state. (IMPLEMENTATION.md §2.)
- **One state object.** `GameState` (RefCounted) is the whole save; it serializes
  to `user://save.json`. All mutations go through named commands in `sim/commands.gd`
  (wrapped by the `Store` autoload), so every change is replayable and testable.
- **One `resolve()`.** Eat and Fight are the *same call* against different node
  kinds — two engines would be two balancing burdens. `resolve(lineage, node, dt,
  rng, content)`.
- **Closed-form accrual.** `accrue()` integrates materials as `rate · Δt` and
  samples rare events (genes, splices) as a **Poisson process** from seeded RNG
  streams — O(events), never frame-ticked. The same rate helpers back both a live
  tick and an offline batch, so there is exactly one economy.
- **Seeded RNG** (`sim/rng.gd`) — deterministic; tests and offline batches reproduce.
- **Data + three gates.** Content is JSON in `data/`; the engine is small and
  hand-written. Gate 1 (orthogonality) is automated in `sim/validation.gd` +
  `tests/validate_data.gd`; gates 2 (science) and 3 (voice) are review steps.
- **The harness — `tests/economy_test.gd`.** The #1 tool. It runs the real
  `resolve()`/`accrue()` headless and proves the chase shape. **Re-green it on
  every economy change.**

## The one loop

**Work a node**, RuneScape-style: **Forage** materials → **Metabolize** them into
**adaptations**. It resolves as an RPG check: roll **effective Power vs the node's
defense** → a margin that scales the material yield and opens a **gene** jackpot
(the chase). **Penetration** reduces a node's defense first ("defense values are
advisory"). Eat = passive nodes (reliable materials); Fight = defended nodes
(materials + the best genes + a splice chance). Same call, two node kinds.

## The doll

Six body-part slots — `mouthparts · integument · locomotion · sensory ·
metabolic_core · gland` — each holding one **adaptation** (tier 1→3, a rarity
colour, and grafted **affixes**). Each adaptation declares which attribute its
tier `feeds` (power / resilience / metabolism / instinct; the gland feeds none —
it's a pure affix host). **Expressed genes feed attributes too** (an affix may carry
a `feeds`, added at a smaller per-tier weight) — so the doll *and* its genes build the
niche's throughput stat. `effective_attributes` = base + per-slot doll contributions +
expressed-gene feeds; `effective_power` soft-caps the result (diminishing returns above
the knee).
**Role is derived from the doll** (`Resolve.derived_role`, a display-only read of
the dominant fed attribute) — there is no class system. Affixes have **slot
affinity** (a gene only expresses on anatomically valid organs) and a **per-organ
expression cap** (an organ is venomous *or* armoured, not everything).

## Skills (the proficiency layer — VISION §7)

Three skills — **Foraging** (eat nodes), **Hunting** (fight nodes), **Fortitude**
(fight danger) — train by working a node (XP integrates closed-form like materials,
banked per lineage in `lineage.skills`). A skill **gates access** and **scales activity
throughput**, never power: the doll is the body (power → access & the chase), the skill
is how well you work it — `performance = body × skill`. Yield-skills multiply their node
kind's **material** rate (NOT gene rate — the chase stays doll + genes); Fortitude blunts
the danger tax. **Skills are *activities*, a distinct axis from the 7 capability-roles** —
a skill never re-implements a role term, so they layer, never double-count. Nodes and
organs declare `requires {skill, level}`; **unlock is derived** from skill level (no saved
state). Within a niche, nodes form a **sequential ladder** (`ladder_order`) showing only
the next couple of locked rungs (show-next-few). Data-driven from `data/skills.json` (no
skill ids in the engine). Curve / XP rate / yield K / Fortitude K are placeholders, tuned
at the harness. The three starters are umbrella branch-roots — Horizon specialises them
into feeding guilds (Grazing/Filtration, Pursuit/Ambush/Parasitism, Thermo-/Osmoregulation
which double as the age affix-keys).

## Niches with teeth (VISION §11)

A niche declares a **signature attribute** = its throughput multiplier (`material_rate`
multiplies by the worked node's-niche signature). **Power stays universal access** (the
power-vs-defense margin/gate); the signature is one of the non-power attributes, and — since
genes feed attributes — your doll + genes + skills all drive how hard you lap your home
niche. **Off-home floors at 1.0, so it is the baseline, never a penalty.** Only **resilience**
and **metabolism** are clean signatures (power = access, instinct = the chase, both excluded —
instinct would double-dip the gene rate). Some niches are **affix-key-gated** (`meets_niche_keys`
requires an expressed gene of a role) — the cost of admission, which is itself the build that
then dominates inside. Two niches ship: **The Shallow Benthos** (signature resilience, no key —
the tank/armour home) and **The Open Water** (signature metabolism, key `sustain` — the
filter-feeder's farm, where the efficient build laps everything).

## The chase (VISION §9a — the locked shape, protected above almost everything)

Two reward tiers, both rarity-coloured:
- **Materials** common→rare — the reliable crafting economy.
- **Genes** common→legendary — the accumulating genome; each gene unlocks an
  affix. A **frequent cozy stream** keeps every check-in eventful, under a
  **brutal legendary chase** (1-in-many). **The curve never flattens** — expected
  interesting events per check-in stays roughly constant; a legendary is always
  *reachable-but-never-given*.

**The first gene is guaranteed** — the very first action on an empty codex always drops a
gene (`first_gene`), presented as an emphatic **"First mutation!"** beat, so the #1 system is
felt in the first minute. One-time onboarding only (keyed off an empty codex), **not pity** —
the ongoing legendary chase stays pure independent rolls.

Current harness shape (single representative lineage, 6-week arc): never-flat
week means ~20→28 (no decay); ~25 events/check-in; legendary dry-streak **p50≈14**
check-ins (target band [10,25]). The constants are placeholders.

## What ships now (the clean base + the first rebuild increments)

**Two niches.** **The Shallow Benthos** (signature resilience, no key) — **5 nodes on a
skill-gated ladder**: `microbial_mat` eat → `sea_anemone` fight DEF 2 → `detrital_ooze` eat
(Foraging 4) → `trilobite` "Olenoides" fight DEF 5 (Hunting 4) → `anomalocaris` apex fight
DEF 9 (Hunting 10). **The Open Water** (`pelagic`, signature metabolism, key `sustain`) —
2 nodes: `plankton_bloom` eat (Foraging 1, the filter farm) → `glass_drifter` fight DEF 3
(Hunting 3, splices the stealth gene). **3 skills** (Foraging / Hunting / Fortitude) · **one
affix per orthogonal role (7)** + their 7 genes (common→legendary), two of which now carry a
`feeds` (gill→metabolism, plating→resilience) · 6 adaptations (one per slot; Calcite Carapace =
Fortitude 2, Nematocyst Gland = Hunting 3 are skill-gated organs) · 3 materials (`biofilm`,
`soft_tissue`, `flesh`) · 4 drop tables. The session frame (offline dispatch, do-now agenda,
the Home/Body/World shell with the skill readout, show-next-few ladder, per-niche
signature/key line, and the Body-tab EFFECTIVE STATS stat-block) is intact. Cladogenesis
(branching) is the respec valve. Pelagic content traces to `bible/refs/pelagic.md`; the rest
is still a starter set — more nodes/creatures + material diversity grow from here.

## What is parked (recoverable via tag `prototype-v3.5`)

- **The class tree, in full** — `class_tree.json`, class math (`niche_mult`,
  `stat_mods`), category gating, the Class tab. Role derives from the doll instead.
- **The `reef_edge` niche** + its creatures (and the pelagic *build tree* — `filter_combs`,
  `notochord_flick`, `lucent_flesh`, documented in `bible/refs/pelagic.md` but not yet built;
  YAGNI). The **7-role framework** stays; pelagic itself is now un-parked (above).
- **The soft cap** — correct, but builds at this scale don't reach the knee. (The affix-key
  gate `meets_niche_keys` is no longer a dormant seam — The Open Water exercises it.)

## What is NOT built yet

The rest of ROADMAP "Next", in dependency order: **(1) selection-as-a-draft** (the §9d
decision), **(2) splice made distinct**, **(3) the active verb's Axis 1** (Axis 2 ships with
combat depth, Horizon). **Build each from the vision, not from the parked code**, as a signed
work order (CLAUDE.md §5a): propose → Leon signs → build the smallest version → re-prove the
harness → validate the feel → next.

**Done (2026-06-15):** the progression spine — skills + the skill-gated ladder + organ-gating.
**Done (2026-06-16):** chase-lands-early (guaranteed, emphatic first gene) · niches-with-teeth
(signature attribute = throughput; genes feed attributes; The Open Water un-parked; the
niche-info line + the Body stat-block). Each re-proved §9a (p50=14, never-flat).
