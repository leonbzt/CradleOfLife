# PHASE2.md — Work order: Splicing + the orthogonal affix set

> **Temporary document.** This is the signed, detailed work order for Phase 2
> (IMPLEMENTATION.md §4). It is deleted when the phase closes; the decisions it
> contains are recorded in DECISIONS.md (2026-06-11). If this file and the
> canonical docs disagree, the canonical docs win — stop and flag it.

**Phase goal.** Make the seven orthogonal affix roles *mechanically real*, ship
splicing end-to-end (offer → claim → graft), and gate two new niches behind
affix-keys — so that *"what should I fight" becomes a build decision players
talk about* (the validation gate).

**Precondition.** Leon has called the Phase 1 playtest gate (the friend-cohort
web build, running since 2026-06-10) as a pass. **Do not start WP1 until this
box is checked:** ☐ *Phase 1 gate: pass (Leon, date: ____)*

---

## 0. Rules for the implementer

You are executing a signed design, not designing. Read `CLAUDE.md` first; it
governs everything here.

1. **Formulas are law.** Implement every formula in §2 *verbatim*. If a formula
   looks wrong, underspecified, or contradicts the code you find — **stop and
   flag it to Leon.** Never silently "fix" the design.
2. **No new mechanics.** No new `math_term` values, no new engine surface, no
   fields beyond those specified. A new term in data = engine work = not yours
   to invent (VISION.md §17: AI authors data, never the engine).
3. **One work package per commit.** Do them in order (WP1 → WP7). Every WP ends
   with all checks green (§9). Do not start WP *n+1* with WP *n* red.
4. **Content rows need sources.** Every biological claim gets a `source`
   pointing at a real section in `bible/refs/`, with a real citation in that
   section. Leon reviews gates 2–3 before any content row merges; your job is
   to make that review easy (list every claim you're asserting).
5. **Match the codebase.** Typed GDScript, the existing comment register (see
   `sim/resolve.gd`), code-built UI, no `Node` dependencies in `sim/`. Lint
   with `gdformat`/`gdparse` (installed).
6. **Escalate, don't assume**, on any of: save-migration edge cases beyond §3,
   relaxing any validation rule, editing VISION.md/IMPLEMENTATION.md/bible
   beyond what a WP names, adding files not listed here, adding dependencies,
   deleting anything not listed here.

Run commands (Godot 4.6.2 at `/home/leon/Apps/godot`):

```bash
godot --headless --import                                    # after any class/file change
godot --headless --script res://tests/validate_data.gd       # gate 1
godot --headless --script res://tests/sim_test.gd            # commands + math
godot --headless --script res://tests/economy_test.gd        # the chase harness
godot --headless --quit-after 20                             # boot smoke
```

---

## 1. Signed design decisions (Leon, 2026-06-11)

1. **Full 7-term resolve-math model.** Fight nodes gain a `danger` stat; each
   of the seven orthogonal roles maps to its own term in the math (§2).
2. **Duplicate genes are stack tiers.** Copies known of a gene cap how high its
   affix can be grafted. Dupes are the cozy stream's meaning (VISION.md §9b).
3. **Two full-size niches.** Pelagic (key: `uptime`) and Reef Edge (key:
   `stealth`), 4 nodes each, each with its own fresh drop tables (§9a breadth).
4. **Graft rarity escalation.** A grafted adaptation turns **epic**; an affix
   unlocked by a legendary-rarity gene turns it **legendary**. The reserved
   jackpot colours appear on the doll only via the gene chase.

Also decided (consequences of the above): splice rolls are now gated by the
power check exactly like gene rolls (stealth's ambush opens both); save schema
goes to v2; affix-keys are *role* strings checked against the lineage's
**equipped** grafts; genes go straight to `genes_known` as counts (no separate
claim step for mutation drops — the *graft* is the check-in decision).

---

## 2. WP1 — Engine: the resolve-math expansion

**Files:** `sim/resolve.gd`, `sim/accrual.gd`, `sim/adaptation_instance.gd`
(read-only here; schema change is WP2), call-site updates in `sim/commands.gd`,
`tests/economy_test.gd`, `tests/sim_test.gd`, `ui/main.gd`.

### 2.1 The term registry

Affix `params` are collected from every graft on every equipped adaptation.
A graft is `{id, tier}` (WP2); `row = content.affix(id)`. Implement:

```gdscript
## Sums every grafted affix's contribution per math_term. Returns all keys
## always present (zero/identity defaults), so callers never branch on has().
static func affix_totals(lineage: Lineage, content: Content) -> Dictionary
```

| math_term | role (fixed) | accumulate per graft | total |
|---|---|---|---|
| `pen_flat` | penetration | `amount * tier` | `pen` (sum) |
| `dot_floor` | dot | `tick_pct * tier` | `dot` (sum) |
| `danger_guard` | mitigation | `amount * tier` | `guard` (sum) |
| `ambush_frac` | stealth | `frac * tier` | `ambush` (sum, capped 0.75) |
| `splice_mult` | control | `(mult - 1.0) * tier` | `splice_bonus` (sum) |
| `uptime_mult` | uptime | `(mult - 1.0) * tier` | `uptime_bonus` (sum) |
| `find_mult` | find | `(mult - 1.0) * tier` | `find_bonus` (sum) |

### 2.2 The formulas (verbatim)

New named constants in `Resolve`: `MARGIN_SLOPE := 0.1`, `EFF_FLOOR := 0.1`,
`EFF_CAP := 5.0`, `DANGER_TAX_K := 0.15`, `DANGER_FACTOR_FLOOR := 0.2`,
`AMBUSH_CAP := 0.75`. (Existing magic numbers 0.1/5.0 move into these.)

```text
P       = effective_power(lineage)                        # unchanged: power + Σ tiers
D_eff   = max(0.0, node.defense - totals.pen)             # penetration enters here, only here
margin  = P - D_eff

floor   = EFF_FLOOR
if node.kind == "fight":                                  # dot makes OUTGEARED prey farmable
    floor = minf(EFF_FLOOR + totals.dot, 1.0)
eff     = clampf(1.0 + MARGIN_SLOPE * margin, floor, EFF_CAP)

danger_factor = 1.0                                       # eat nodes: no retaliation
if node.kind == "fight":
    tax = DANGER_TAX_K * maxf(0.0, node.danger - lineage.attributes.resilience - totals.guard)
    danger_factor = clampf(1.0 - tax, DANGER_FACTOR_FLOOR, 1.0)

material_rate = node.material_rate * metabolism * eff * (1.0 + totals.uptime_bonus) * danger_factor

gate    = 1.0 if P > D_eff else totals.ambush             # stealth cracks the gate open
gene_rate       = node.gene_rate   * instinct * (1.0 + totals.find_bonus)   * gate
splice_rate_eff = node.splice_rate * (1.0 + totals.splice_bonus)            * gate
```

Notes that are part of the spec:

- **`danger` taxes material rate only** — not gene rate. The chase is event-
  based; the tax is recovery time eating into gathering.
- **Splice is now gated** like genes (`gate` applies to both). Phase 1 left
  splice ungated, but offers were dropped on the floor, so nothing felt changes.
- `resilience` (so far unused) enters the danger tax. `vitality` stays unused
  until Phase 3 — do not invent a use.
- Signatures: `resolve(lineage, node, dt, rng, content)`,
  `yield_efficiency(lineage, node, content)`, `material_rate(lineage, node,
  content)`, `gene_rate(lineage, node, content)`, plus new
  `splice_rate_eff(lineage, node, content)` and
  `effective_defense(node, totals)`. Update every call site; no default args
  (force the compiler to find them all).

### 2.3 Accrual: sample splice offers offline

`Accrual.accrue()` gains a second Poisson stream per lineage, named
`"splice_accrue:" + lineage.id`, using `splice_rate_eff`. Events gain a
`kind` field: existing gene events `{kind: "gene", t, lineage, node, gene,
rarity}`, new `{kind: "splice", t, lineage, node, gene}`. (Accrual *application*
to the save is Phase 4; the harness only counts events — same as today.)

### 2.4 Tests (extend `tests/sim_test.gd`)

Exact-number assertions, one per term, each built from a hand-constructed
lineage + node so the expected value is computable on paper. Cover at minimum:

- pen: a graft of `gnathobase_minor` tier 1 (`amount 2`) vs DEF 9 → `D_eff 7`.
- dot: venom tier 1 (`tick_pct 0.15`) vs an outgeared fight node → `eff == 0.25`.
- mitigation+resilience: danger 4, resilience 1, guard 0 → `danger_factor 0.55`;
  with `plating_minor` tier 1 (`amount 2`) → `0.85`.
- uptime/find: multiplier identities (`1 + Σ(mult−1)·tier`).
- stealth: `P <= D_eff` and ambush 0.25 → `gene_rate == 0.25 ×` the open rate;
  without stealth → exactly `0.0`.
- control: splice rate multiplier; and that `gate` zeroes splice when outgeared
  with no stealth.
- determinism: two runs of `accrue()` over the same gap, same seed → identical
  event lists including splice events.

---

## 3. WP2 — State, migration, commands

**Files:** `sim/game_state.gd`, `sim/adaptation_instance.gd`,
`sim/commands.gd`, `state_store.gd`, `tests/sim_test.gd` (+ a v1 save fixture,
e.g. `tests/fixtures/save_v1.json`), and **IMPLEMENTATION.md §2's `GameState`
sketch** (it shows `inventory_genes`/`niches_unlocked`; update it in the same
commit so docs and code never drift — this edit is in-scope, nothing else in
that file is).

### 3.1 GameState → SCHEMA_VERSION 2

- `genes_known: Dictionary` — `gene_id -> int` copy count (was `Array[String]`).
- `splice_offers: Array[Dictionary]` — `[{gene: String, node: String}]`, new.
- **Remove** `inventory_genes` (folded into counts) and `niches_unlocked`
  (niche access is a per-lineage equipped-key check, not a global unlock —
  YAGNI, re-add if Phase 3 needs it).
- `to_dict()/from_dict()` updated to match.

Migration: `state_store.gd::_migrate_and_load` gets its first real step,
v1 → v2 on the raw dict: every entry of old `genes_known` and old
`inventory_genes` becomes `+1` in the new counts; `splice_offers: []`; removed
keys dropped. **Test it** against the committed v1 fixture (build the fixture
from the current `GameState.to_dict()` *before* changing the schema).

### 3.2 AdaptationInstance: grafts carry a tier

- `affixes` becomes `Array[Dictionary]` of `{id: String, tier: int}` (was
  `Array[String]`; live saves only ever wrote `[]`, but `from_dict` must still
  tolerate a bare string entry → `{id, tier: 1}`).
- Helper: `graft_tier(affix_id: String) -> int` (0 if absent).

### 3.3 Commands

- **`forage()`** — gene drops now do `genes_known[id] += 1` (keep returning the
  loot dict; UI pops from it). Splice offers now **bank**:
  `state.splice_offers.append({gene, node})`. *(This fixes a recorded drift:
  Phase 1 rolled offers and dropped them on the floor.)*
- **`claim_splice(state, index) -> {ok, gene}`** — pop the offer,
  `genes_known[gene] += 1`.
- **`graft(state, content, lineage_id, slot, affix_id) -> {ok, reason}`**:
  1. Lineage exists; an `AdaptationInstance` is equipped in `slot`. (Any affix
     may go on any slot — stated assumption, revisit after playtest.)
  2. `affix` row exists; find the **unique** gene with `unlocks.id == affix_id`
     (uniqueness is enforced by WP3). `copies = genes_known.get(gene_id, 0)`.
  3. `target = instance.graft_tier(affix_id) + 1`; require `copies >= target`
     (reason: `"need another <gene name> copy"`). Copies are a cap, not a
     currency — they are **not** consumed.
  4. Cost: `graft_cost.base * graft_cost.growth^(target-1)`, rounded, in
     `graft_cost.material` (same pattern as `metabolize_cost`). Require, deduct.
  5. Set the graft tier; recompute rarity (§3.4).
- **`assign_node()`** — add the key check. New helper
  `meets_niche_keys(lineage, content, niche_id) -> bool`: for every role string
  in `niche.affix_keys`, the lineage has ≥1 equipped graft whose affix's
  `orthogonal_role` equals it. `assign_node` returns false when unmet; UI uses
  the helper for lock display.

### 3.4 Rarity escalation (one shared helper)

```text
rarity(instance) = "legendary"  if any graft's unlocking gene has rarity "legendary"
                   "epic"       else if instance has any graft
                   TIER_RARITY[min(tier,3)-1]  otherwise   # unchanged Phase 1 rule
```

Extract this as one helper used by **both** `graft()` and `metabolize()`.
**Bug-trap (spec'd on purpose):** tier-upping a grafted adaptation via
Metabolize must *preserve* its grafts and recompute rarity through the helper —
the Phase 1 code would silently demote an epic back to a tier colour.

### 3.5 Tests

Graft paths (unknown affix, zero copies, copies < target tier, insufficient
materials, success, tier 2 needs 2 copies); claim_splice; rarity escalation
incl. the metabolize-preserves-grafts trap; key gating on `assign_node` (unmet
→ false, equip the key affix → true); migration fixture round-trip.

---

## 4. WP3 — Validation gate extensions

**File:** `sim/validation.gd`, `tests/` (validate runs in CI already).

Add, keeping every existing check:

1. **Canonical term→role map** (this locks the engine vocabulary — a new term
   in data must fail loudly):
   `{pen_flat: penetration, dot_floor: dot, danger_guard: mitigation,
   splice_mult: control, uptime_mult: uptime, find_mult: find,
   ambush_frac: stealth}`. An affix's `math_term` must be in this map **and**
   its `orthogonal_role` must equal the mapped role. (Replaces the looser
   inferred term→role consistency check.)
2. **Term param shapes:** required numeric keys per term — `pen_flat:[amount]`,
   `dot_floor:[tick_pct]`, `danger_guard:[amount]`, `splice_mult:[mult]`,
   `uptime_mult:[mult]`, `find_mult:[mult]`, `ambush_frac:[frac]`.
3. **`graft_cost`** on every affix: material exists, `base > 0`, `growth >= 1`
   (mirror the `build_cost` checks).
4. **Genes:** `rarity` required and in `RARITIES`; `unlocks.kind == "affix"`;
   `unlocks.id` exists in affixes; **no two genes unlock the same affix**.
5. **Drop tables:** each row's `rarity` must equal the gene def's `rarity`
   (one source of truth; WP4 normalizes current mismatches).
6. **Niches:** `affix_keys ⊆ ROLES`. **Nodes:** `niche` references an existing
   niche row; `danger >= 0` and only on `kind == "fight"`; `spliceable`
   references an existing gene; `splice_rate > 0` requires `spliceable`.

---

## 5. WP4 — Content: two niches, through all three gates

**Files:** everything under `data/`, `bible/refs/pelagic.md` (new),
`bible/refs/reef-edge.md` (new), `bible/world_spine.md` (niche table status
flips to v1), `bible/refs/shallow-benthos.md` (only if a new claim needs it).

**Process:** you draft rows + the two refs files with real citations; **every
row stops at Leon for gates 2–3** (scientific accuracy, voice per
`bible/voice.md`) before merge. List each biological claim explicitly in the PR
description. All numbers below are **placeholders — WP6 retunes them**; the
*structure* (which creature, which role, which key) is the signed part.

### 5.1 Affix re-shape (existing 6 rows) + new rows

Existing rows keep ids, get new `math_term`/`params` per §2.1, and each gains a
`graft_cost`:

| id | role | term | params (placeholder) |
|---|---|---|---|
| `venom_minor` | dot | `dot_floor` | `{tick_pct: 0.15}` |
| `plating_minor` | mitigation | `danger_guard` | `{amount: 2}` |
| `grasp_minor` | control | `splice_mult` | `{mult: 1.5}` |
| `gill_minor` | uptime | `uptime_mult` | `{mult: 1.15}` |
| `eyes_minor` | find | `find_mult` | `{mult: 1.2}` |
| `gnathobase_minor` | penetration | `pen_flat` | `{amount: 2}` |

New affixes (each needs flavor in-voice + source):

| id | role | term | params | unlocked by |
|---|---|---|---|---|
| `glassy_tissue` | stealth | `ambush_frac` | `{frac: 0.25}` | `gene_glassy_tissue` (rare) |
| `ambush_instinct` | stealth | `ambush_frac` | `{frac: 0.4}` | `gene_ambush_instinct` (epic) |
| `filter_combs` | uptime | `uptime_mult` | `{mult: 1.35}` | `gene_filter_combs` (uncommon) |
| `notochord_flick` | mitigation | `danger_guard` | `{amount: 1}` | `gene_notochord` (common) |
| `spine_rows` | mitigation | `danger_guard` | `{amount: 3}` | `gene_spine_rows` (uncommon) |
| `eversible_proboscis` | control | `splice_mult` | `{mult: 2.0}` | `gene_proboscis` (uncommon) |
| `great_appendage` | control | `splice_mult` | `{mult: 2.5}` | `gene_great_appendage` (**legendary** — re-pointed off `grasp_minor` so the pinnacle unlocks its own affix and the legendary doll colour) |

(Same-term rows at different magnitudes are an accepted ladder within a role,
not synonyms — gate 1 passes them because params differ.)

### 5.2 Genes

Every gene def (old and new) gains a canonical `rarity`. Canonical set for the
existing six: `gill` common, `compound_eye` common, `sclerite` uncommon,
`gnathobase` uncommon, `nematocyst` rare, `raptorial` rare, `great_appendage`
legendary. Normalize the existing drop-table rows to match (WP3 check 5).

New genes: `gene_notochord` (common), `gene_filter_combs` (uncommon),
`gene_proboscis` (uncommon), `gene_spine_rows` (uncommon), `gene_glassy_tissue`
(rare), `gene_ambush_instinct` (epic). Flavor in-voice, sources real.

### 5.3 Niches & nodes

`data/niches.json` adds:

- `pelagic` — "The Open Water", `affix_keys: ["uptime"]`. *Science hook:
  sustained swimming demands respiratory throughput (gill capacity).*
- `reef_edge` — "The Reef Edge", `affix_keys: ["stealth"]`. *Ambush country:
  you don't enter without crypsis.*

UI copy for a lock: `Requires: an equipped <Role> adaptation.`

Nodes (placeholder numbers; `danger` is new on fight nodes — also add it to
the existing benthos fight nodes: anemone 2, trilobite 0, anomalocaris 4;
benthos defenses unchanged — **Anomalocaris stays the age's chase ceiling**):

| id | niche | kind | DEF | danger | material (rate) | splice → gene |
|---|---|---|---|---|---|---|
| `plankton_bloom` | pelagic | eat | 0 | — | `plankton` 1.6 | — |
| `haikouichthys` | pelagic | fight | 3 | 1 | `soft_tissue` 1.2 | `gene_notochord` |
| `tamisiocaris` | pelagic | fight | 5 | 1 | `soft_tissue` 1.0 | `gene_filter_combs` |
| `glass_drifter` | pelagic | fight | 7 | 2 | `lucent_flesh` 0.7 | `gene_glassy_tissue` |
| `archaeocyathid_grove` | reef_edge | eat | 3 | — | `calcite_lattice` 1.2 | — |
| `wiwaxia` | reef_edge | fight | 5 | 1 | `chitin` 1.0 | `gene_spine_rows` |
| `ottoia` | reef_edge | fight | 6 | 3 | `soft_tissue` 0.9 | `gene_proboscis` |
| `reef_lurker` | reef_edge | fight | 8 | 4 | `flesh` 0.6 | `gene_ambush_instinct` |

Real creatures (Haikouichthys, Tamisiocaris, archaeocyathids, Wiwaxia, Ottoia)
are Cambrian — chronology-clean. `glass_drifter` and `reef_lurker` are
**invented, clearly stylized** gap-fillers (allowed per the chronology rule):
transparency is a real open-water crypsis strategy, ambush lurking a real reef
strategy — neither contradicts known biology; gate 2 still checks every
asserted capability. Note for gate 2: Wiwaxia's sclerites are unmineralized —
it yields `chitin`, not calcite. Eat nodes may carry DEF (grazing armored food
is what `penetration` is for).

New materials (rarity cap "rare" still enforced): `plankton` (common),
`calcite_lattice` (uncommon), `lucent_flesh` (rare). Graft costs draw on the
new materials so the new economy has sinks (minor affixes ~`{base: 40,
growth: 2.5}` in a niche-appropriate material; epic/legendary affixes in
`flesh`/`lucent_flesh` ~`{base: 80, growth: 2.5}`).

### 5.4 Drop tables

Four new tables — `pelagic_eat`, `pelagic_fight`, `reef_eat`, `reef_fight` —
plus `apex_lurker` for the reef apex. Draft weights freely (rarity must match
the gene def; weight ladder ~ Phase 1 tables); **`gene_great_appendage` at
weight 1 in both new `_fight` tables** (precedent: `benthos_fight`) — one age
pinnacle, reachable everywhere, hunted fastest at the apex. Fresh tables are
the §9a "breadth opens fresh chases" mechanism — keep each niche's gene mix
mostly niche-local.

---

## 6. WP5 — UI (placeholder look, observer-only, code-built)

**File:** `ui/main.gd` (+ `ui/loot_pop.gd`, `ui/colors.gd` as needed). Same
pattern as Phase 1: every widget from content data, mutations only via Store
commands (Store gains thin wrappers for `claim_splice`/`graft` with signals).

1. **Niche selector** above the wild list (tabs or segmented control). Locked
   niche shows the key requirement line; nodes of the active niche only.
2. **Node cards** gain a DANGER readout on fight nodes (next to DEF).
3. **Doll** gains all six slots (Phase 1 shipped three; the data has always had
   six). Each slot shows grafted affix chips — name + tier roman numeral — and
   the instance rarity colour (epic/legendary now reachable).
4. **Gene codex** section: each known gene, its count, what it unlocks, its
   rarity colour.
5. **Splice offers**: a claim row/banner per pending offer, Dev-voice copy.
6. **Graft flow**: tap a doll slot → sheet of graftable affixes (known genes
   only) with copies, current→next tier, cost; confirm calls `Store.graft`.
7. **Loot pops** for gene drops in the gene's rarity colour, and for splice
   offers.
8. **Voice pass** on *all* UI strings (new and the Phase 1 placeholders —
   closes the open question in DECISIONS.md) against `bible/voice.md`. Leon
   reviews as gate 3.

---

## 7. WP6 — Harness: re-prove the chase curve

**Files:** `tests/economy_test.gd`, `tools/chart_chase.py` (only if columns
change — append columns, never rename, the chart reads by header name).

1. Part A: update call sites; print splice offers banked.
2. Part B: the simulated player gets a deterministic check-in **policy** (keep
   it dumb and explicit — it's a model, not an AI): claim all pending splice
   events; graft the affordable affix with the most copies (ties: data order);
   lineage "hunter" migrates benthos → pelagic when it meets the uptime key,
   then to the drifter; lineage "stinger" migrates to reef_edge when it meets
   the stealth key. Log per check-in: events, legendaries, splices, grafts,
   active niche per lineage (new CSV columns).
3. Re-run the 6-week arc. **Acceptance (the §9a never-flat property):** mean
   interesting events/check-in does not decay week-over-week (week 6 ≥ ~80% of
   week 1), no dead check-ins (min ≥ 1), a legendary dry-streak p50 in the
   "brutal but reachable" band (~10–25 check-ins; p90 reported, not gated —
   the no-pity experiment continues), and the niche migrations actually happen
   inside the window (else the keys are mistuned).
4. Tune the placeholder constants (§5 numbers, `DANGER_TAX_K`, affix params)
   until acceptance holds. **Leon eyeballs the chart and signs the numbers.**

---

## 8. WP7 — Playtest build & the gate

Leon's job, with your support: web export to the friend cohort (his existing
flow). The gate question (IMPLEMENTATION.md §4): *does "what should I fight"
become a build decision players talk about?* Evidence we want: players
narrating splice/graft stories unprompted ("I spliced X off Y and now…").
Watch for: splice offers ignored, grafts read as a vending machine, keys read
as chores. Honest pass/fail goes in DECISIONS.md and closes this phase — at
which point **this file is deleted**.

---

## 9. Definition of done (every WP)

```bash
godot --headless --import
godot --headless --script res://tests/validate_data.gd   # exit 0
godot --headless --script res://tests/sim_test.gd        # exit 0
godot --headless --script res://tests/economy_test.gd    # exit 0
godot --headless --quit-after 20                         # boots clean
gdparse <touched .gd files>                              # parses
gdformat --check <touched .gd files>                     # formatted
```

CI (`.github/workflows/ci.yml`) runs the same scripts — it must stay green on
every push. No dead code, no commented-out experiments, no doc/code drift left
behind (CLAUDE.md §2.7).

**Out of scope for this phase (do not build, stub, or scaffold):** class tree,
roster slots / second lineage UI, soft cap, offline accrual application + Dev
dispatch UI, notifications, skills XP, pity mechanics, art pass, clock-tamper
defense, any Age II content.
