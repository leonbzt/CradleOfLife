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
it's a pure affix host). `effective_attributes` = base + per-slot contributions;
`effective_power` soft-caps the result (diminishing returns above the knee).
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

## The chase (VISION §9a — the locked shape, protected above almost everything)

Two reward tiers, both rarity-coloured:
- **Materials** common→rare — the reliable crafting economy.
- **Genes** common→legendary — the accumulating genome; each gene unlocks an
  affix. A **frequent cozy stream** keeps every check-in eventful, under a
  **brutal legendary chase** (1-in-many). **The curve never flattens** — expected
  interesting events per check-in stays roughly constant; a legendary is always
  *reachable-but-never-given*.

Current harness shape (single representative lineage, 6-week arc): never-flat
week means ~20→28 (no decay); ~25 events/check-in; legendary dry-streak **p50≈14**
check-ins (target band [10,25]). The constants are placeholders.

## What ships in the base (the clean starter — throwaway scaffolding)

One niche **`shallow_benthos`** · **5 nodes on a skill-gated ladder** (`microbial_mat`
eat → `sea_anemone` fight DEF 2 → `detrital_ooze` eat (Foraging 4) → `trilobite`
"Olenoides" fight DEF 5 (Hunting 4) → `anomalocaris` apex fight DEF 9 (Hunting 10)) ·
**3 skills** (Foraging / Hunting / Fortitude) · **one affix per orthogonal role (7)** +
their 7 genes (common→legendary) · 6 adaptations (one per slot; Calcite Carapace =
Fortitude 2, Nematocyst Gland = Hunting 3 are skill-gated organs) · 3 materials
(`biofilm`, `soft_tissue`, `flesh`). The session frame (offline dispatch, do-now agenda,
the Home/Body/World shell with the skill readout + show-next-few ladder) is intact.
Cladogenesis (branching) is the respec valve. Content is still a *starter set* —
niches-with-teeth and material diversity arrive next (ROADMAP "Next").

## What is parked (recoverable via tag `prototype-v3.5`)

- **The class tree, in full** — `class_tree.json`, class math (`niche_mult`,
  `stat_mods`), category gating, the Class tab. Role derives from the doll instead.
- **Most affix/gene/niche/node/material DATA** — the `pelagic` and `reef_edge`
  niches and their creatures, and everything keyed to them, trimmed to the starter
  above. The **7-role framework** stays; only the data shrank.
- **Seams kept for the rebuild, intentionally unexercised:** the affix-key gate
  (`meets_niche_keys`) — no shipped niche has keys yet; it is what niches-with-teeth
  rebuilds on. The soft cap — correct, but builds at this scale don't reach the knee.

## What is NOT built yet

The rest of ROADMAP "Next", in dependency order: **(1) chase-lands-early** (first gene,
epic-flavored, in the first session — the natural next, tuned against the new skill
pacing), (2) niches-with-teeth (power = access, signature stat = throughput) + the
affix-key gate, (3) selection-as-a-draft (the §9d decision), (4) splice made distinct,
(5) the active verb's Axis 1 (Axis 2 ships with combat depth, Horizon). **Build each from
the vision, not from the parked code**, as a signed work order (CLAUDE.md §5a): propose →
Leon signs → build the smallest version → re-prove the harness → validate the feel → next.

**Done (2026-06-15):** the progression spine — skills (Foraging / Hunting / Fortitude) +
the skill-gated node ladder + organ-gating (WP1 engine, WP2 ladder/UI; §9a re-proven).
