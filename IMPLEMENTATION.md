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
# sim/game_state.gd
class_name GameState extends RefCounted

var lineages: Array          # Array[Lineage]
var slots_active: int = 2
var slots_max: int = 2
var inventory_materials: Dictionary = {}   # material_id -> qty
var inventory_genes: Array = []
var genes_known: Array = []
var niches_unlocked: Array = []
var last_seen_unix: int = 0

# Lineage (own RefCounted): id, display_name, kingdom ("animal" in v1),
#   attributes {vitality, power, resilience, metabolism, instinct},
#   doll {slot_id -> AdaptationInstance}, skills {skill_id -> xp},
#   class_node, assigned_node, graduated.
# AdaptationInstance: {def_id, tier, affixes, rarity}
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
  "orthogonal_role": "dot",
  "math_term": "dot_stacks",
  "params": { "stacks": 1, "tick_pct": 0.03 },
  "flavor": "A thin toxin that lingers in the wound.",
  "source": "bible/refs/venom.md#delivery-vs-potency"
}
```

**Gate 1 — Orthogonality (automated, CI).** `tests/validate_data.gd` rejects any row missing `orthogonal_role` (must be one of `dot`, `control`, `mitigation`, `uptime`, `find`, `penetration`, `stealth`) or `math_term`, and flags two affixes sharing a `math_term` with no distinguishing `params` as suspected synonyms. Keeps "does this change *how I play* or just *the number*?" a build check, not a vibe.

**Gate 2 — Scientific accuracy (human review, sourced).** Every substantive biological claim must be backed by a reference in `bible/refs/`. AI is strong at flavor and unreliable at facts, so a human verifies against sources before merge. The `source` field is mandatory on rows that assert a real capability. This gate is what makes the TierZoo backing real rather than decorative.

**Gate 3 — Voice & world coherence (review against the bible).** The row reads in the §2a register and fits the mythic-Earth saga.

The **science + voice bible** (`bible/`) is a Phase-0 deliverable: the world's spine (ages, niches), the voice do/don't list with example patch notes and creature blurbs, and a starter `refs/` set per niche. It is the single source of truth all three gates check against.

---

## 4. Production phases, gated on validation

### Phase 0 — Model & bible (1–2 weeks)

No UI. Two deliverables.

1. **The chase-curve model.** `tests/economy_test.gd`, run with `godot --headless --script res://tests/economy_test.gd`, simulating a 6-week arc across 2 then 4 lineages using the *real* `resolve()`/`accrue()` (this is why they're Node-free). Log per day: materials, mutations, sessions-since-last-legendary, interesting-events-per-check-in. Dump CSV; chart it.
2. **The science + voice bible** (§3): world spine, voice rules, starter references.

**Validation gate:** *Across 6 simulated weeks, does a check-in still produce a meaningful event most days, and is the next legendary always reachable-but-never-given?* This is the §9a never-flat property. If the curve decays at week 2, no UI saves it. Fix constants here, in numbers — the cheapest and most important milestone in the project.

### Phase 1 — Vertical slice: the thesis (3–4 weeks)

One **defended** node, Power-vs-defense roll, a rarity-coloured loot pop with juice, and an equipment doll with **three** slots where equipping measurably changes the next roll. No class tree, roster, or genes yet. This is the smallest build that tests the core thesis (vision §7–8).

**Validation gate:** *Does getting a drop and choosing to equip it feel good when there's a defended node to feel the difference against?* Put it in front of the playtest cohort; watch first-equip reactions. If it fails, the loop is wrong — content will not save it. Iterate here.

### Phase 2 — Splicing + the orthogonal affix set (3–4 weeks)

Gene drop stream, splicing ("eat the venom-toad → roll to gain Venom"), all seven orthogonal roles made mechanically real behind all three gates (§3), affix-key gating on two new niches (pelagic, reef edge). The signed, formula-exact work order for this phase is `PHASE2.md` (temporary; deleted when the phase closes — decisions recorded in DECISIONS.md 2026-06-11).

**Validation gate:** *Does "what should I fight" become a build decision players talk about?* The bar is the player story — "I spliced frost off the deep thing and now my grazer one-shots the tundra." If players aren't narrating splices, splicing isn't carrying its weight.

### Phase 3 — The portfolio + class tree (4–5 weeks)

Class/spec tree (now it comes online), cladogenesis-as-respec, a 2-slot roster, and a placeholder per-lineage **soft cap** (without it, breadth-led growth has no shape and the Phase-0 curve breaks at the top end).

**Validation gate:** *With two animal lineages, does each feel like a different character to check in on, or is it tap-claim-twice?* If they feel identical, the v1 animal sub-roles aren't distinct enough — fix role variety (lean on real-biology differences) before adding slots.

### Phase 4 — The mobile product (5–7 weeks)

Closed-form offline accrual, the **Dev-dispatch** while-you-were-away summary, notifications (§5), and the **land-fall summit** beat (vision §15 calls it make-or-break — over-build it). Add telemetry.

**Validation gate:** *Do players return the next day without being nagged?* Measure D1/D7 on the cohort. This is the only retention test that counts pre-launch.

### Soft launch (limited region / closed track)

Release the vertical slice to a limited audience. Validate the Phase-0 chase model against *real* telemetry: does the in-the-wild event cadence match the prediction? Tune constants (vision §20), not structure. Hold the ethical line (vision §18) while reading retention honestly.

### Live ops — ages as expansion patches

Post-launch, the roadmap *is* the fiction: each new age ships as a Dev expansion patch on a sustainable cadence (a major age every few months, smaller content patches between). Kingdoms, apex bosses, dedicated Fight encounters, and the deferred depth (vision §19) become the patch pipeline. Build none of their scaffolding before launch.

---

## 5. Notifications in Godot (Phase 4)

The one place Godot needs help — no built-in mobile notification API.

- **Local scheduled notifications** cover the common case. Because accrual is closed-form, you can compute when the next notable event lands and schedule a local notification for it. Use a maintained community local-notification addon (Android + iOS) or a thin GDExtension/JNI bridge. Bounded, known work — flag it early so Phase 4 doesn't surprise you.
- **Server push** is *not needed in v1*: nearly every honest trigger is locally predictable. Don't stand up a backend until something genuinely requires it.
- Implement the vision §16 rules in code: Dev-voice good-news framing only, a hard daily cap, suppress if opened recently, never fire "chase ticked closer" unless the Phase-0 curve makes it true.

---

## 6. Quality, testing & telemetry

- **Headless unit tests** for `resolve()` and `accrue()` run in CI on every push — the economy is the riskiest system and the easiest to test deterministically (seeded RNG).
- **The three content gates** (§3) run on every content change; gate 1 in CI, gates 2–3 as a merge checklist.
- **Playtest cohort** from Phase 1 onward — 5–10 honest testers, not friends-who-love-you; watch sessions, don't just read survey scores.
- **Soft-launch telemetry** validates the Phase-0 model in the wild. The honest professional bar is real D1/D7 and session metrics, achieved *without* dark patterns — the design ethic (vision §18) forbids juicing them.

---

## 7. Definition of the vertical slice (first releasable build)

**Phase 1 + 2 + 3 + offline accrual + Dev-dispatch summary + notifications**, animals only, sea age only, ~6 affixes, ~15–25 nodes, 2 roster slots, a placeholder soft cap, all content through the three gates, and a chase curve that survived Phase 0. That is a complete, retainable idle RPG suitable for soft launch. Everything past it — ages, graduation polish, kingdoms, deferred depth — is live-ops expansion on a proven base.

---

## 8. First steps — first sprint

In order. The first three are roughly an afternoon each.

1. **Initialize the repo and Godot 4 project** matching §2: empty `sim/`, `data/`, `ui/`, `tests/`, `bible/`; autoloads `state_store.gd` and `data_loader.gd` (the loader fails loudly on malformed JSON). Commit. Set up the CI runner to call Godot headless.

2. **Write `sim/game_state.gd`, `sim/rng.gd` (seeded), and the `Resolve.resolve()` signature as stubs** — shapes only, with `resolve()` returning a hardcoded loot dict so the test runs.

3. **Write `tests/economy_test.gd` and run it headless:**
   ```bash
   godot --headless --script res://tests/economy_test.gd
   ```
   Loop `resolve()` 10,000× against one stub node, print the loot distribution. This script is the spine of the project — it's how you'll validate the chase curve in Phase 0 and every economy change after. Wire it into CI now.

4. **Draft the science + voice bible** (`bible/`): the age/niche spine, the voice do/don't list with a handful of example patch notes and creature blurbs, and a starter reference set for the first niche. This is gate 2 and gate 3's source of truth.

5. **Stub `affixes.json` with the §3 schema and write `tests/validate_data.gd`.** Even with two affixes, get gate 1 running in CI so no synonym ever sneaks in later.

6. **Build the Phase-0 chase model** on the test harness and answer its validation gate — *does the chase stay alive across 6 weeks?* — before opening the editor to build Phase 1's doll.

The order is deliberate: prove the engine of tension in numbers and pin the world's ground truth in the bible, *then* spend weeks on pixels.
