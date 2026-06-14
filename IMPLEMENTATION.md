# Cradle of Life — Production Plan (Godot)

> Companion to the Game Vision Document. This is the production plan for a small independent team building on **Godot 4**, sequenced around **validating fun before scaling content**, with the process discipline (version control, CI, a gated content pipeline, soft launch, live ops) of a professional indie product.

---

## 0. What this plan optimizes for

**Validate the core loop before building the content cathedral.**

The vision is internally coherent, so the risk is not design contradiction — it is spending months on roster, ages, and class trees atop a loop that turns out flat. With no completion endpoint and no decision-scarcity, **the chase curve (vision §5, §9a) is the entire long-game pull**, which sharpens the risk list. The three assumptions most likely to be wrong, in order:

1. **The chase curve never goes flat.** No completion screen to coast toward — if expected-events-per-check-in decays, the game dies. The #1 risk by a wide margin.
2. **Equipping is dopamine *because there's a defended node to test it against*.** A passive-only wardrobe does not validate the thesis.
3. **The animal-only roster has enough real-biology role variety** to make a 2-lineage portfolio feel different, not redundant.

Every phase ends on an explicit **validation gate** — a fun/quality question answered by real players on real devices (or, for Phase 0, by a model). Do not start the next phase until the gate is a clear pass, or the loop has been changed to make it one.

---

## 1. Team, tools & toolchain

**Team shape: solo or small team.** Realistic division of labor for an indie of 1–3:

| Discipline | Who | Notes |
|---|---|---|
| Engineering + systems design | Core dev (you) | The engine, the gates, `resolve()`, the economy. Non-delegable. |
| Game/economy design | Core dev | Tuning the locked structure's dials (vision §20). |
| Pixel art + UI | Contract artist or curated asset packs | Retro-pixel is feasible; AI assists ideation, a human finalizes a coherent set. |
| Audio / SFX | Contract or licensed packs | Low priority until the vertical slice. |
| Science accuracy | Core dev + sourced references | Or a biology-literate collaborator; this is the TierZoo backbone (§3, gate 2). |
| QA / playtest | A small recruited cohort | 5–10 honest testers from the first vertical slice onward. |

**Engine: Godot 4, GDScript.** The game is ~95% UI and arithmetic; there is no real-time simulation. GDScript iterates fast, ships to Android + iOS from one project, gives cheap "juice" (tweens, particles, rarity theming), and is free with no royalties. Drop to C# only if profiling ever demands it — it won't.

**Toolchain & process (professional from day one):**

- **Version control:** git, with `data/` and `tests/` in-repo. Content is code; it gets reviewed and versioned like code.
- **CI:** on every push, run the headless economy test and the data-validation gates (§3). Content regressions and broken affixes fail the build, not the player.
- **Builds:** Godot export presets for Android + iOS; a closed test track (Google Play internal/closed testing, TestFlight) for the playtest cohort and soft launch.
- **Telemetry (added at soft launch):** lightweight, privacy-respecting event logging — session length, return cadence, where players stall, and the *real* chase-event cadence to compare against the Phase-0 model.

**The architectural rule that shapes everything:** keep the simulation *out of the scene tree*. State, `resolve()`, and accrual are plain GDScript with **no `Node` dependency**, so they run headless and are unit-testable without a window. Scenes/nodes are only the UI layer observing that state.

**Offline accrual is closed-form, never frame-ticked.** On focus after N hours, compute the result directly from a stored `last_seen` — never simulate elapsed ticks. Continuous yields (materials) integrate in closed form, `materials = rate · Δt`. Discrete rare events (the gene chase) are *not* a smooth function of Δt, so they are sampled as a **Poisson process** — exponential inter-arrival times from a dedicated seeded RNG stream — costing O(#events), not O(#ticks). This is correct (no battery drain, no catch-up lag), keeps `resolve()` clean, stays reproducible, and lets you *predict the future* (when the next event lands) — which is what makes local notifications free (§5).

---

## 2. Architecture in Godot

### Layering

```
res://
  sim/                 # pure GDScript, NO Node — the testable core
    game_state.gd        # the whole save, one object (extends RefCounted)
    resolve.gd           # static func resolve(lineage, node, dt) -> Loot
    accrual.gd           # static func accrue(state, content, dt, rng) -> {materials, events}
    rng.gd               # seeded RNG wrapper (deterministic for tests)
  data/                # all content as JSON — authored + AI-assisted, never engine
    adaptations.json
    affixes.json         # each row: orthogonal_role + math_term + source ref (§3)
    genes.json
    niches.json
    nodes.json
    drop_tables.json
    class_tree.json
  data_loader.gd       # loads + VALIDATES json at boot (autoload)
  state_store.gd       # autoload singleton: holds live GameState, save/load
  ui/                  # Control nodes only; observe state_store
  tests/               # headless test + validation scripts
    economy_test.gd
    validate_data.gd
  bible/               # the science + voice bible (markdown + references)
```

### One state object

`GameState` is a `RefCounted` (not a `Node`) — pure data, serializes to JSON in `user://save.json`. UI is a pure function of it; all mutations go through named commands in `state_store.gd` so every change is replayable and testable.

```gdscript
# sim/game_state.gd  (SCHEMA_VERSION 2)
class_name GameState extends RefCounted

var lineages: Array[Lineage]
var slots_active: int = 2
var slots_max: int = 2
var inventory_materials: Dictionary = {}   # material_id -> qty (float)
var genes_known: Dictionary = {}           # gene_id -> int copy count
var splice_offers: Array[Dictionary] = []  # [{gene: String, node: String}]
var last_seen_unix: int = 0

# Lineage (own RefCounted): id, display_name, kingdom ("animal" in v1),
#   attributes {vitality, power, resilience, metabolism, instinct},
#   doll {slot_id -> AdaptationInstance}, skills {skill_id -> xp},
#   class_node, assigned_node, graduated.
# AdaptationInstance: {def_id, tier, affixes: [{id, tier}], rarity}
#   affix graft_tier(affix_id) -> int; rarity escalates to epic/legendary
#   when grafts are present (Commands._compute_rarity).
```

### One resolve function

Eat and Fight are the *same call* against different node types. Two engines = two balancing burdens; the moat depends on one.

```gdscript
# sim/resolve.gd
class_name Resolve

static func resolve(lineage, node, dt: float, rng) -> Dictionary:
    var power := _effective_power(lineage, node)      # affix/affinity mods folded in
    var margin := power - node.defense
    var loot := { "materials": _material_yield(node, margin, dt) }
    if rng.chance(_gene_odds(node, lineage, dt)):     # the chase, vision §9a
        loot["gene"] = _roll_gene(node, rng)
    if node.kind == "fight" and rng.chance(node.splice_chance):
        loot["splice_offer"] = node.spliceable_adaptation
    return loot
```

`resolve()` takes `dt`, so the *same function* runs a live tick and an 8-hour offline batch. No second offline code path to keep in sync.

---

## 3. The content pipeline & its three gates

The moat is combinatorics from a small, distinct, *true* primitive set (vision §17). AI assists authoring; three gates protect the build. Gate 1 is automated in CI; gates 2 and 3 are review steps.

Every affix/creature/adaptation row looks like:

```json
{
  "id": "venom_minor",
  "name": "Weak Venom",
  "orthogonal_role": "affliction",
  "math_term": "dot_floor",
  "params": { "stacks": 1, "tick_pct": 0.03 },
  "flavor": "A thin toxin that lingers in the wound.",
  "source": "bible/refs/venom.md#delivery-vs-potency"
}
```

**Gate 1 — Orthogonality (automated, CI).** `tests/validate_data.gd` rejects any row missing `orthogonal_role` (must be one of `affliction`, `control`, `guard`, `sustain`, `perception`, `penetration`, `stealth`) or `math_term`, and flags two affixes sharing a `math_term` with no distinguishing `params` as suspected synonyms. Keeps "does this change *how I play* or just *the number*?" a build check, not a vibe.

**Gate 2 — Scientific accuracy (human review, sourced).** Every substantive biological claim must be backed by a reference in `bible/refs/`. AI is strong at flavor and unreliable at facts, so a human verifies against sources before merge. The `source` field is mandatory on rows that assert a real capability. This gate is what makes the TierZoo backing real rather than decorative.

**Gate 3 — Voice & world coherence (review against the bible).** The row reads in the §2a register and fits the mythic-Earth saga.

The **science + voice bible** (`bible/`) is a Phase-0 deliverable: the world's spine (ages, niches), the voice do/don't list with example patch notes and creature blurbs, and a starter `refs/` set per niche. It is the single source of truth all three gates check against.

---

## 4. How we sequence — validation-gated; ordering owned by ROADMAP.md

The original Phase 0→4 ladder did its job: it delivered a working prototype — the chase harness, the Power-vs-defense loop, the equipment doll, the seven orthogonal affix roles, splicing, a class tree, offline accrual, and a playable check-in session. It also taught us the lesson recorded in DECISIONS (2026-06-14): **the feature surface outran the core *feeling*** (the cohort read it as dull, illegible, the chase not landing). So the sequence is no longer a fixed phase ladder. It is the **reset-to-spine rebuild**, ordered as a *living* list in **ROADMAP.md** (Now / Next / Horizon) and governed by one rule that does **not** change:

> **Every increment ends on a validation gate** — a fun/quality question answered by real players, or, for any economy change, by the headless chase harness. Don't start the next increment until its gate passes or the increment is reworked to pass. *The gate discipline is stable; the ordering is adaptable.*

**The current build approach (2026-06-14).** Keep the engine and the content pipeline; rebuild the loop's *feel* — an active verb, legible progression, and the chase landing — before re-accreting complexity. Each piece is a small, signed work order (the old PHASE2/PHASE3 style: propose → Leon signs → build → re-prove the harness → validate), and the work-order file is deleted on close with its decisions moved to DECISIONS.md. ROADMAP "Next" lists the pieces; the active verb leads.

**The standing validation gates** (apply whenever the relevant system is touched, not phase-locked):

- **The chase never goes flat** (the #1 gate) — the 6-week harness model still shows a meaningful event most check-ins and a legendary always reachable-but-never-given (vision §9a). Re-run on *every* economy change.
- **Equipping feels good** — against a node that pushes back, getting a drop and choosing to express it is a dopamine beat (vision §7–8).
- **Branches feel different** — two lineages read as different characters to check in on, not tap-claim-twice (niches need teeth, vision §11, §13).
- **Active play earns its place** — it is *more fun* than idling, and the idle floor stays complete without it (the §12 litmus test).
- **Returns happen without a nag** — D1/D7 hold on the cohort with no dark patterns (vision §16, §18).

**Soft launch & live ops (unchanged in spirit).** When the spine feels good and the gates hold, release to a limited audience, validate the chase model against real telemetry (tune *constants*, not structure — vision §20), then ship ages as Dev expansion patches on a sustainable cadence (vision §15). Build no scaffolding for deferred depth (vision §19) before launch.

---

## 5. Notifications in Godot (a pre-launch checklist item, not a goal)

Notifications are an **optional, opt-in convenience — never a re-engagement engine** (vision §16): build the game to retain without them, then layer these on near launch. The one place Godot needs help — no built-in mobile notification API.

- **Local scheduled notifications** cover the common case. Because accrual is closed-form, you can compute when the next notable event lands and schedule a local notification for it. Use a maintained community local-notification addon (Android + iOS) or a thin GDExtension/JNI bridge. Bounded, known work — flag it early.
- **Server push** is *not needed in v1*: nearly every honest trigger is locally predictable. Don't stand up a backend until something genuinely requires it.
- Implement the vision §16 rules in code: Dev-voice good-news framing only, a hard daily cap, suppress if opened recently, never fire "chase ticked closer" unless the harness curve makes it true.

---

## 6. Quality, testing & telemetry

- **Headless unit tests** for `resolve()` and `accrue()` run in CI on every push — the economy is the riskiest system and the easiest to test deterministically (seeded RNG).
- **The three content gates** (§3) run on every content change; gate 1 in CI, gates 2–3 as a merge checklist.
- **Playtest cohort** — 5–10 honest testers, not friends-who-love-you; watch sessions, don't just read survey scores. (Leon playtests first, then ships web exports to the cohort.)
- **Soft-launch telemetry** validates the harness model in the wild. The honest professional bar is real D1/D7 and session metrics, achieved *without* dark patterns — the design ethic (vision §18) forbids juicing them.

---

## 7. The first releasable build (the slice that ships)

The spine made to *feel* good, on the engine that already exists: the **active verb** (optimize-the-loop + light combat-babysit), **legible skill-level progression**, **niches with teeth + a sequential unlock ladder**, the **chase landing early**, and **selection as a draft against a budget** — animals only, sea age only, ~6 affixes, ~15–25 nodes, ~2 roster slots, a placeholder soft cap, all content through the three gates, and a chase curve that still survives the harness. That is a complete, retainable idle RPG suitable for soft launch. Everything past it — ages, the ability tree + combat depth, the ecosystem loop, kingdoms, the rest of vision §19 — is live-ops expansion on a proven base. The ordered list lives in ROADMAP.md.
