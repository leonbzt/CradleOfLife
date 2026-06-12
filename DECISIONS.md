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

## 2026-06-11 — Phase 2 designed and signed; handed off as PHASE2.md

**What.** Phase 2 (splicing + the orthogonal affix set, IMPLEMENTATION.md §4)
was designed in full and signed by Leon; the executable work order lives in
`PHASE2.md` (a temporary doc, deleted when the phase closes). Build start waits
on the Phase 1 gate call. The signed decisions:

### Resolve-math expansion — full 7-term model with a `danger` stat

Each orthogonal role gets its own term in the one resolve function: penetration
reduces effective defense; dot raises the losing-matchup yield floor on fight
nodes; control multiplies splice rate; mitigation (with the so-far-unused
`resilience` attribute) reduces a new fight-node `danger` tax on material rate;
uptime multiplies material rate; find multiplies gene rate; stealth opens the
gene/splice gate at a fraction below the power check. **What it replaced:**
affixes as data with no mechanical existence (Phase 1's resolve() never read
them) and a single margin lever. This is the "bigger growth moments come from
new math terms, not bigger margins" plan (2026-06-11 entry above) made real.
Exact formulas: PHASE2.md §2.

### Splice rolls are now power-gated, like gene rolls

Stealth's ambush fraction opens both. Phase 1 left splice ungated — but also
never banked the offers, so nothing felt changes. **Drift recorded:** the
2026-06-10 Phase 1 entry said gene/splice drops were "banked"; in fact only
genes were — `Commands.forage()` dropped splice offers on the floor, and
`accrue()` never sampled them offline. Both fixed in Phase 2.

### Gene economy — counts, stack tiers, grafting; dupes are progression

Gene drops and claimed splice offers add copies to `genes_known` (id → count;
no separate claim step for mutation drops — the graft is the check-in
decision). Grafting sockets a known affix onto an equipped adaptation for
materials (`graft_cost` per affix row); copies cap the graft tier, so
duplicate genes are the cozy stream's meaning (VISION.md §9b stacking), not
dead drops. Copies are a cap, not a currency — never consumed. Save schema
goes to v2 (`genes_known` counts, `splice_offers`; `inventory_genes` folded
in, unused `niches_unlocked` removed) — the Phase 0 migration hook's first
real step.

### Graft rarity escalation — the chase becomes visible on the doll

A grafted adaptation turns epic; an affix unlocked by a legendary gene turns
it legendary. **What it replaced:** crafted gear hard-capped at rare
(2026-06-10). The cap still holds for *pure* crafting; epic/legendary remain
reachable only via the gene chase, which is the §9 colour reservation's
intent.

### Two full-size niches, keyed by role

Pelagic (key: `uptime` — sustained swimming demands gill capacity) and Reef
Edge (key: `stealth` — ambush country; the stealth role's first content),
4 nodes each, fresh drop tables (§9a breadth), real-Cambrian roster plus two
invented stylized gap-fillers per the chronology rule. Affix-keys are checked
against the lineage's **equipped** grafts (the build survives the niche, not
the codex); keys are role strings for now, taxonomy tags can refine later.
Anomalocaris stays the age's chase ceiling. Leon chose both-full-size over the
proposed pelagic-plus-small-reef.

---

## 2026-06-11 — Phase 2 complete; WP6 chase curve re-proven

### Economy harness — 6-week model rebuilt for Phase 2 policy

The harness (`tests/economy_test.gd`) was rewritten for Phase 2: two lineages
(`hunter`, `stinger`), deterministic player policy (claim splices, metabolize,
graft best, migrate on key), and new CSV columns (`splices_claimed`,
`grafts_applied`, `hunter_niche`, `stinger_niche`). Final result: **p50=11
check-ins between legendaries** — in target band [10,25]. ✓

### Drop table tuning — `apex_lurker` weight 5 → 1

`gene_great_appendage` was at weight 5/95 ≈ 5.26% in the `apex_lurker` table
(vs 1% in all other legendary slots). Combined with the stinger lineage
reaching `reef_lurker` in week 2 and the `eyes_minor` find_bonus, the combined
legendary rate reached ~0.4/check-in → p50 ≈ 2. Corrected to weight 1/91 ≈
1.1%, bringing `apex_lurker` in line with every other apex table. **What it
replaced:** weight 5 (a Phase 2 authoring oversight — the 5.26% was not
intentional).

### Harness graft cap — `POLICY_MAX_GRAFT_TIER = 3`

The policy model had no cap on how many times it would re-graft the same
affix. With a shared material pool and two lineages both accumulating
`gene_great_appendage` copies (copies are a cap, not consumed), the model
stacked `splice_mult` affixes to tier ~20, producing 60× splice bonuses that
were impossible in real play (legendary copies are gated by drop rarity). A
model constraint `POLICY_MAX_GRAFT_TIER = 3` was added to the harness only —
it does **not** touch the engine or any game rule. Three tiers is the realistic
ceiling for a 6-week arc given the 1% legendary drop rate. **What it
replaced:** unbounded tier accumulation in the model (not a game rule change).

---

## 2026-06-11 — Notifications demoted to optional; equipment-swap & naming pass opened

### Notifications are an optional convenience, not a re-engagement engine

**Decision (Leon).** Notifications drop from "the primary re-engagement engine,
as load-bearing as the loot loop" to an **optional, opt-in convenience** the game
never depends on. The re-engagement pillar is the chase + climb + idle accrual
(VISION §5, §9a); the game must be complete and retainable for a player who never
enables notifications.

**Why.** A notification-driven re-engagement *engine* sits one step from the
loss-aversion / babysitting anti-patterns this design bans (VISION §12, §18).
Making notifications non-load-bearing removes the temptation and keeps the no-nag
ethic honest. **What it replaced:** VISION §16's "primary re-engagement engine"
stance and the "Dev-voice notifications as product shape" lock line. Canonized in
VISION §16, §19 table, "What's locked"; IMPLEMENTATION §4, §5, §7.

**Honest caveat (assistant).** Opt-in notifications have low adoption on mobile,
so this is a retention bet — re-engagement now leans entirely on the chase and the
player's own habit. Measurable at soft launch (D1/D7) and reversible (an opt-in
prompt can be added later). The closed-form-accrual / event-prediction work keeps
its independent justification (no battery drain, reproducibility, offline
correctness); only its notification payoff is now an optional bonus.

### Equipment swapping + mechanically-distinct slots — direction set, build deferred

**Direction (Leon).** The equipment doll should become a real RPG surface, two
ways, both built **later** (not this phase):

- **Distinct slots (Option A).** Each doll slot gains its own mechanical identity
  — potentially via attribute subsystems (e.g. integument→resilience,
  metabolic_core→metabolism, sensory→instinct) — so *which organ you invest in* is
  a build choice, not a uniform +Power. Today every slot adds +1 Power/tier
  identically (`Resolve.effective_power`); differentiation lives only in grafts.
- **Competing adaptations (Option B).** More than one candidate adaptation per
  slot, so equipping is a pick-between-items swap (VISION §7's "swapping
  adaptations *is* the build"), not just investment order.

The **metabolize → graft** pipeline with **genes as a bank** is confirmed clear
and stays. Equipment swapping layers on top, after the voice/naming pass. VISION
§7's equipment dial is **not** rewritten yet — the decision isn't finalized.

### Voice & naming pass — opened (terms under review, no canonization yet)

A naming/voice pass is underway. Player-facing labels may change; internal
`orthogonal_role` ids and math terms stay fixed (renaming them would touch
`sim/validation.gd`, `affixes.json`, the gate, and the docs — avoided). Terms
Leon flagged:

- **splice** — clear enough for "eat a creature, copy its trait"?
- **graft** vs **express** — Leon prefers "graft"; the "expressing a gene" framing
  is dropped from player-facing copy.
- affix **role labels** — `mitigation` / `uptime` / `find` unclear as player labels.
- **metabolic_core** — "core" may get a better in-voice name; acceptable as-is.

Resolved calls get canonized in VISION §17 (role table) and the UI strings as
Leon signs off.

---

## 2026-06-11 — Naming pass resolved: Express chosen; role labels + ids canonized & aligned

Closes the voice/naming pass opened above. Leon's calls:

### Express (not Graft) for the gene-expression action

**Decision (Leon).** The player-facing verb for socketing a banked gene onto an
organ is **Express**. The signature pair is **Splice** (acquire foreign genetic
material from prey → gene bank) → **Express** (switch a banked gene on as a trait
on an organ) — the biologically correct acquisition→expression story.

**What it replaced.** The 2026-06-11 naming-pass entry's lean toward "Graft" (and
its note dropping "express"). Reversed: as a biologist Leon prefers the accurate
term, and the TierZoo brand (VISION §2) rewards true terminology used as game
balance. The small legibility cost is paid in UI (the action reads "Express Venom
→ Mouthparts"; the gene visibly snaps onto the organ). The internal command stays
`Commands.graft()` for now — engine name, not player-facing — renamable later.

### Affix role labels + ids canonized and aligned

**Decision (Leon).** The seven orthogonal roles get clear player labels, and the
internal `orthogonal_role` **ids are renamed to match** — done now, before content
multiplies, to kill the translation tax (Leon's call; cheap at 13 affixes).

| label = id | was | hosts |
|---|---|---|
| **Affliction** | `dot` | venom, bleed, disease, parasitism |
| **Control** | `control` (unchanged) | grip/pin now; slow/taunt/lure later |
| **Guard** | `mitigation` | plating, spines, toxin-resistance, aposematism |
| **Sustain** | `uptime` | gills, filter combs |
| **Perception** | `find` | eyes, lateral line |
| **Penetration** | `penetration` (unchanged) | gnathobase, enzymes |
| **Stealth** | `stealth` (unchanged) | crypsis, transparency, ambush |

**Scope (behaviour-neutral).** Renamed: `ROLES` + the *values* of `CANONICAL_TERMS`
in `sim/validation.gd`, `orthogonal_role` in `data/affixes.json`, `affix_keys` in
`data/niches.json`, and role references in VISION §17, IMPLEMENTATION §3, and the
bible. **Deliberately unchanged:** the `math_term` lever names (`dot_floor`,
`uptime_mult`, `find_mult`, `danger_guard`) and **`sim/resolve.gd` entirely** —
`resolve()` matches on `math_term`, so the economy math is provably identical and
the gate's term→role registry keeps the layers linked. `resolve.gd`'s internal
accumulator names (`dot`, `uptime_bonus`, `find_bonus`), the `sim_test.gd` /
`economy_test.gd` `_check` label strings, and the throwaway `PHASE2.md` still carry
old tokens — cosmetic, left for a pass where the headless sim tests are run.

### Roles vs affixes — the two-layer growth rule (canonized in VISION §17)

**Decision (Leon, confirmed).** Roles are the **fixed** orthogonal axis (~7, the
moat); affixes are the **open, growing** set within them. Add affixes freely; add
roles almost never (a new role = a new `resolve()` term, rare and expensive).
Within a role, magnitude-only variants are a legitimate power ladder; genuinely
distinct *play* needs a distinguishing param — Gate 1's synonym check enforces it.
Answers Leon's "big set vs strong core" question: **strong core of roles, big open
set of affixes.** Written into VISION §17.

---

## 2026-06-11 — Phase 3 designed and signed; handed off as PHASE3.md

**What.** Phase 3 (the portfolio + the class tree, IMPLEMENTATION.md §4) was
designed in full and signed by Leon; the executable work order lives in
`PHASE3.md` (temporary, deleted when the phase closes). Build start waits on the
**Phase 2 gate** being called a pass (PHASE3.md precondition checkbox). The signed
decisions:

### A class is three things — stat mods + category access + an in-niche buff

**Decision (Leon).** A class node carries (1) **multiplicative stat modifiers** on
the five attributes, (2) **equipment + gene access by `category`**, and (3) a
**light in-niche multiplier** (material/gene buff in the class's `home_niches`,
×1.0 elsewhere — a buff, never a penalty, per VISION §12). This is the richer
RPG-class model Leon chose over a pure-multiplier class; it realizes VISION §7's
"trades flexibility for in-niche power" by making the *flexibility* literal — what
gear you may build. **What it replaced:** the bare `class_node` field that existed
but did nothing. The in-niche multiplier is **new engine surface** (one term in
`resolve()`), signed.

### Monotonic-safe access — specializing never strands gear

**Decision (Leon).** The basic `generalist` category is buildable by all classes;
specialist-exclusive categories are buildable only by the class that unlocks them
(and its descendants). Combined with **sticky** classes (you only descend), a
lineage's allowed set only ever *grows*, so specializing can never strand equipped
gear — no save-stranding, no feel-bad, no loss-aversion. The traded flexibility is
the ability to ever build a *rival* specialist's exclusive kit; to get it you
branch a fresh lineage. A side effect: a specialist gains a second candidate per
slot (generalist piece vs. exclusive piece), so **pick-between-items (deferred
Option B) emerges for free** — not built as a system.

### Option A — doll slots become attribute subsystems

**Decision (Leon).** Each slot's tier feeds a *specific* attribute (proposed map:
mouthparts+locomotion→power, integument→resilience, metabolic_core→metabolism,
sensory→instinct; gland = affix host; **vitality unused this phase**), replacing
Phase 1's uniform `effective_power = power + Σ tiers`. **What it replaced:** the
deferred-direction status of Option A (DECISIONS 2026-06-11, "Equipment swapping +
distinct slots") — Option A is now **in**, Option B stays deferred (and emerges
free, above). This is an **economy change**, re-proven by the WP6 harness. The
exact slot→attribute map is mechanical and flagged for sign-off at WP6.

### Cladogenesis = fresh respec; classes are sticky

**Decision (Leon).** Branching a lineage yields an empty doll + Generalist class,
sharing the account-wide gene bank (`genes_known` is already global — nothing
copied). Classes are sticky (descend only); the respec valve is to branch
(VISION §4). Roster stays **exactly 2 active slots** this phase; the unlock
schedule and graduation-frees-a-slot are Phase 4+ (§20.7 dial).

### Minimal v1 tree + the no-trap-build gate

**Decision (Leon).** Generalist (root) → three tier-1 classes — **Predator**
(home reef_edge, key `penetration`, unlocks `raptorial`), **Armored Grazer**
(home shallow_benthos, key `guard`, unlocks `heavy_armor`), **Filter Feeder**
(home pelagic, key `sustain`, unlocks `filter_apparatus`) — grounded in the
`bible/world_spine.md` archetype table. Tier-2 hyper-specialists deferred.
Gate 1 gains a **no-trap-build check** (VISION §11): every leaf class's allowed
categories must cover every essential slot, so no class is barred from a viable
full doll.

### Placeholder soft cap; schema unchanged

**Decision (Leon).** Diminishing returns on effective Power past a knee (§2.2 of
PHASE3.md), placeholder constants tuned at WP6 (Leon signs), with the hard
constraint that **Age-I content stays beatable** (Anomalocaris DEF 9). Gives
breadth-led growth its shape (VISION §14). **Save schema stays v2** — Option A,
the class system, and cladogenesis add no new save fields (the migration hook
sleeps another phase).

---

## 2026-06-12 — Phase 3 WP1–WP5 implemented

**What shipped:**
- **WP1 (engine):** Option A — each doll slot feeds a specific attribute (mouthparts/locomotion→power, integument→resilience, metabolic_core→metabolism, sensory→instinct, gland→none). `effective_attributes()` replaces direct `lineage.attributes` reads. Soft cap on Power (knee 12.0, k=0.15, asymptote≈18.67). In-niche class multiplier (+20% material/gene when working the class's home niche; ×1.0 elsewhere — no penalty).
- **WP2 (commands):** `pick_class` (sticky descent, requirement checks), `branch_lineage` (cladogenesis — empty doll, Generalist class, starter node, shared gene bank), category eligibility gates on `metabolize()` and `graft()`.
- **WP3 (validation):** `validate_class_tree` (structure, stat_mods keys, niche refs, buff ≥ 1.0, no cycles), `validate_categories` (no unreachable unlocks, no unbuildable categories), no-trap-build gate (every class must be able to fill all 5 essential slots from its allowed categories).
- **WP4 (content):** `data/class_tree.json` — Generalist (root) → Predator (reef_edge, power↑, unlocks raptorial), Armored Grazer (shallow_benthos, resilience↑, unlocks heavy_armor), Filter Feeder (pelagic, metabolism↑, unlocks filter_apparatus). All existing gear tagged `"category": "generalist"`. Three specialist adaptations (raptorial_claw, fused_dorsal_plating, ciliary_fan) and affixes (strike_momentum, mineralized_spine, laminar_current) with genes. `bible/refs/classes.md` with sourced citations — **gate 2–3 pending Leon review**.
- **WP5 (UI):** Roster bar (2 chips, Branch button), header updates on lineage switch, class panel (current class summary, pickable children with requirements and two-tap commit confirm), doll slots show attribute hint `[power]` / `[resilience]` etc., metabolize buttons grey out locked-category gear with "requires X" hint, graft sheet dims locked-category affixes, power readout shows `~N` when soft cap is active. `forage_all()` ticks both lineages on each timer event.

**What it replaced:** Phase 2 single-lineage UI, uniform `+power` per tier, no class system.

**Open for WP6:** Economy harness re-run with two diverging lineages committing different classes. Soft-cap constants (SOFT_CAP_KNEE/K) and niche_mult values are placeholders — WP6 tunes them and Leon signs the numbers.

**Open for gate 2–3:** `bible/refs/classes.md` and all specialist gear rows require Leon's scientific accuracy and voice review before merge to production.

---

## 2026-06-12 — WP6: Chase curve re-proven under Phase 3 economy

**What.** Re-ran the 6-week economy harness with two diverging lineages under Option A + class system + soft cap. All Phase 3 acceptance criteria pass:

- **Never-flat:** week means 47.8 → 161 → 179 → 182 → 185 → 181 (ramp from cold start, stable weeks 2–6; week 6 ≥ 80% week 1 ✓).
- **p50 dry streak = 11 check-ins** (in [10,25] ✓; p90 = 25, max = 43).
- **Soft cap bites:** hunter eff_power plateaus at 11.25, grazer at 9.0 (both below asymptote 18.7 ✓).
- **No stranded content:** hunter (predator, power×1.25) reaches eff_power 11.25 > Anomalocaris DEF 9 ✓.
- **Lineages diverged:** hunter = predator / shallow_benthos; grazer = filter_feeder / pelagic ✓.

**Numbers needing Leon sign-off (all placeholder):** `SOFT_CAP_KNEE=12.0`, `SOFT_CAP_K=0.15`, `niche_mult material/gene=1.2`. Drop table tuning: `gene_great_appendage` weight in `benthos_fight` reduced from 1 to 0.1 (legendaries were 75/126 check-ins; now 9/126 for p50=11).

**Model policy note:** The divergence is hunter progressing through benthos fight nodes (microbial_mat → sea_anemone → trilobite_grazer, unlocking predator via gnathobase_minor/penetration) while grazer commits filter_feeder via gill_minor/sustain from benthos_eat and migrates to pelagic. This is the intended class-identity split; `armored_grazer` was dropped from the model because `heavy_armor` specialist gear (fused_dorsal_plating) requires `calcite_lattice` from reef_edge — unreachable in the 6-week model without stealth. The `armored_grazer` path remains correct game design; the model simply doesn't exercise it.

**What it replaced:** WP5 open item "re-run with two diverging lineages."

**Open for WP7:** Web export playtest; gate question: "with two animal lineages, does each feel like a different character to check in on?"

---

## 2026-06-12 — Phase 3 polish: progression legibility, slot affinity, per-organ caps, evolving names

**What.** A coherence/polish pass on the built Phase 3 state, driven by Leon's
self-playtest and the Phase-2 cohort feedback ("loved it, played the whole first
map, but couldn't progress"). Five changes, all signed by Leon (answers in
session):

### Progression legibility — the affix-key wall now shows its key (VISION §11)

**Decision (Leon).** The niche-key gates were well-designed but **invisible**: the
only hint for how to unlock pelagic/reef was in a hover `tooltip_text`, which does
not exist on touch (VISION §16) — the literal cause of the cohort's "couldn't
progress." Added a visible, tap-legible **niche-key guidance panel** under the
niche selector: when the active niche is locked it names the role, the generalist
gene(s) that satisfy it (easiest rarity first), **where each gene drops/splices**
(new `Content.sources_for_gene`), and the player's live status — owning the gene
but not expressing it gets an **Express →** shortcut. The gene codex now carries a
static source hint per gene, and locked niches show a 🔒 marker. **What it
replaced:** touch-invisible tooltip-only lock reasons; no map from "I need a
sustain gene" to "grind the Microbial Mat for Branched Gill, then express it." The
gates and the benthos→pelagic→reef chain are unchanged — only made visible.

### Slot affinity — genes express only on anatomically valid organs

**Decision (Leon).** Each affix declares a `slots` list (1–2 organs to start, a
data field widened freely later — Leon's "start simple, expand" call). `graft()`
and the harness policy enforce it; the express sheet filters to the tapped organ.
**What it replaced:** any affix onto any slot (the open "Graft slot freedom"
question, resolved). Canonized in VISION §7. New gate-1 rule: every affix must
declare valid `slots`.

### Per-organ expression cap — the doll becomes a body with trade-offs

**Decision (Leon).** Each organ holds a bounded number of expressed genes
(`Lineage.SLOT_GRAFT_CAP`: integument/locomotion 3, mouthparts/metabolic_core/
gland 2, sensory 1 — "legs hold many, mouthparts/sensory fewer"). A new affix
needs a free expression slot; tiering up one already present never does.
Expression is a commitment (no un-express; the respec valve is to branch, §4).
**What it replaced:** unlimited stacking on a single organ. Stacking still drives
depth (§9b) across the six organs and via tiers — it just can't all pile on one
part. Canonized in VISION §7.

### Evolving organ names + Express applied to the UI

**Decision (Leon).** An organ's name now composes from its build via the new pure
`sim/naming.gd`: affix adjectives + a tier-graded prefix + the base name (e.g.
*Toothed Great Frontal Appendage*), with the precise `T3 · Gnathobase I · epic`
read kept beneath (Leon: evolved name on top, technical info still below). Affixes
gained an `adjective`; adaptations gained a `tier_prefix` ladder (gate 2/3 flavor —
Leon's review). Also finally applied the **Express** verb (DECISIONS 2026-06-11)
to all player-facing UI strings, which still said "Graft." **What it replaced:**
static `Name · T{n}` organ labels; "Graft" UI copy.

### Economy harness made affinity-aware; chase curve re-proven, p50 drifted

The harness policy now grafts by slot affinity + cap (mirrors `graft()`), so the
model plays by the real rules. Re-ran the 6-week arc: **never-flat holds** (week
means 59.9→72.5→76.2→74.3→74.7→75.0), **no stranded content** (hunter eff_power
11.25 > DEF 9), soft cap bites, lineages diverge. **One drift, resolved:**
constraining the doll lowered aggregate gene-find, so the legendary dry-streak
**p50 moved 11 → 26 check-ins** — just past the agreed [10,25] band. This is a
§20.5 drop-rate **constant**, not a shape break. **Leon chose "recenter":** raised
`benthos_fight` `gene_great_appendage` weight **0.1 → 0.16**, bringing p50 back to
**10** (in band, ≈ the WP6-signed cadence of 11). The other tables' legendary
weights are unchanged. p50 is bimodal on the harness seed (snaps 10↔26 around the
legendary count), so the band check is a coarse single-seed proxy — the locked
never-flat *shape* is what's actually guaranteed.

---

## 2026-06-12 — Polish round 2: UI legibility fixes, internal Express rename, dev tools

**What.** A second same-day pass on Leon's self-playtest notes.

### Internal `graft` → `express` rename (reverses the 2026-06-11 "stays graft")

**Decision (Leon).** Renamed the action throughout the code and content to match
the player-facing verb: `Commands.express()`, `Store.express()`, `express_tier()`,
`SLOT_EXPRESS_CAP`/`slot_express_cap`, the `express_cost` data field (affixes.json),
and all UI handlers. **What it replaced:** the 2026-06-11 call to keep
`Commands.graft()` as an internal-only name "renamable later" — Leon called it now
so the codebase speaks one language. Behaviour-neutral; all tests + the chase curve
identical after the rename.

### UI legibility fixes (self-playtest)

- **Horizontal overflow on the main lineage** (regression): the evolved organ-name
  label had no autowrap, so a long composed name forced the doll row past the
  720px screen (empty branch dolls fit, hence main-only). Fixed with WORD_SMART
  autowrap on the doll name + tech labels.
- **Font floor raised to 16** (was 14/15) across detail/flavor text for phone
  readability, keeping the 18 body / 20+ header hierarchy.
- **Organ-cap count removed from the doll slot button** (it read `[power ·2]`); the
  capacity now shows only in the Express sheet title (`used/cap`), per Leon.
- **Gene codex is now tap-to-open** (VISION §16 inspect grammar): each gene's
  description + source is hidden until you tap the gene, instead of always-on.

### Dev tools (testing only — remove before release)

A "DEV" bar at the bottom of the screen: **↺ Reset save** (`Store.reset_save`) and
**⏩ +8h** (`Store.dev_fast_forward`, applies a closed-form `Accrual` batch). For
fast iteration on progression during playtests. Flagged in code for removal.

---

## Open questions (current)

- **Metabolize screen feels unintuitive — REVISIT (Leon, 2026-06-12).** Each doll
  slot builds exactly one fixed adaptation (e.g. `sensory` → only "Stalked Eyes"),
  which reads oddly — you "craft" one specific thing with no alternative. Leon
  wants this reconsidered: a crafting menu with real per-slot options, or a
  different framing, so building an organ is a choice rather than a single button.
  Note: Option B (competing adaptations per slot) was deferred but "emerges free"
  from class-category access (DECISIONS 2026-06-11) — that may be the seed of the
  answer. Not scoped yet; design discussion next.

- **Phase 2 validation gate (WP7).** Web export to friend cohort; gate
  question: "does 'what should I fight' become a build decision players talk
  about?" Run it and report honestly. **Blocks Phase 3 build** — PHASE3.md WP1  does not start until this is a pass (its precondition checkbox). *Leon, 11.6.* Pass
- **UI gate 3 (voice).** Leon reviews all Phase 2 UI strings in `ui/main.gd`
  against `bible/voice.md`. Slot names, niche labels, and splice copy are
  pending explicit sign-off. Leon, 11.6.: Pass
- **Yield growth feel.** Accepted for early game (2026-06-11, above); Phase 2's
  affix terms are the planned answer — re-evaluate at the Phase 2 gate.
  Leon 11.6. : pass for now, reevaluate after phase 4
- **Equip choice depth.** Phase 2's grafting is the planned answer (real
  alternatives per slot via affixes); re-evaluate at the Phase 2 gate. **Leon, 11.6.: good with p3 new changes**
- **Graft slot freedom — RESOLVED 2026-06-12.** Slot affinity (`affix.slots`,
  1–2 organs) + per-organ caps (`Lineage.SLOT_GRAFT_CAP`) shipped; venom no
  longer goes on swimming flaps. See the 2026-06-12 polish entry.
- **Per-class doll specialization — DEFERRED (direction set, 2026-06-12).** Leon's
  "specialized slots per class" was partly the gear-naming gap (now fixed) and
  partly a future want: a strong class identity via *emphasizing/restricting*
  themed genes and exclusive gear per organ. Build none of it now (YAGNI); the
  affinity + caps + naming pass was the body-coherence layer he was after.
- **Chase p50 drift — RESOLVED 2026-06-12.** Leon chose "recenter";
  `benthos_fight` `gene_great_appendage` weight 0.1→0.16, p50 back to 10 (in
  band). See the 2026-06-12 polish entry.
- **Clock-tampering** is accepted for now (2026-06-10, above); must be revisited
  before offline accrual ships to players.
- **Equipment swapping + distinct slots — scheduled into Phase 3.** Option A
  (mechanically distinct slots) is now **in** (signed 2026-06-11, PHASE3.md).
  Option B (competing adaptations per slot) stays deferred but **emerges for
  free** from the class-category access model (a specialist gets a 2nd candidate
  per slot) — not built as a system. Metabolize→graft with genes-as-bank stays.
- **Voice & naming pass — resolved** 2026-06-11 (above): Express chosen; role
  labels + ids canonized and aligned (Affliction / Control / Guard / Sustain /
  Perception / Penetration / Stealth). Low-priority polish still open: a nicer
  in-voice name for `metabolic_core`, and clearer wording for `integument` —
  both fine as-is for now.
