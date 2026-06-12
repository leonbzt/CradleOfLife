# PHASE3.md — Work order: The portfolio + the class tree

> **Temporary document.** This is the signed, detailed work order for Phase 3
> (IMPLEMENTATION.md §4). It is deleted when the phase closes; the decisions it
> contains are recorded in DECISIONS.md (2026-06-11). If this file and the
> canonical docs disagree, the canonical docs win — stop and flag it.

**Phase goal.** Bring the **class/spec tree** online as a real RPG class system,
make the doll slots **mechanically distinct** (Option A), ship **cladogenesis**
(branch a fresh lineage) and a live **2-lineage roster**, and add a placeholder
per-lineage **soft cap** — so that *two animal lineages feel like genuinely
different characters to check in on* (the validation gate, IMPLEMENTATION.md §4).

**Precondition.** Phase 2's playtest gate must be a pass before any build starts.
**Do not start WP1 until this box is checked:**
☐ pass *Phase 2 gate: pass (Leon, date: _11.6.26__)* — *"does 'what should I fight' become a build decision players talk about?"* (DECISIONS.md open question WP7).

---

## 0. Rules for the implementer

You are executing a signed design, not designing. Read `CLAUDE.md` first; it
governs everything here. This phase touches the **engine** (resolve math, new
commands) and adds **new engine surface** (a class-niche multiplier and a
soft cap) that Leon has signed — see §1. You may not add engine surface beyond
what §1–§2 name.

1. **Formulas are law.** Implement every formula in §2 *verbatim*. If a formula
   looks wrong, underspecified, or contradicts the code you find — **stop and
   flag it to Leon.** Never silently "fix" the design.
2. **No unsigned mechanics.** No new `math_term` values, no new save fields, no
   new engine terms beyond the class-niche multiplier and soft cap named in §1.
   A new mechanical lever = engine work = not yours to invent (VISION.md §17).
3. **One work package per commit.** Do them in order (WP1 → WP7). Every WP ends
   with all checks green (§9). Do not start WP *n+1* with WP *n* red.
4. **Content rows need sources.** Every biological claim gets a `source` pointing
   at a real section in `bible/refs/`, with a real citation there. Leon reviews
   gates 2–3 before any content row merges; make that review easy (list every
   claim you assert in the PR description).
5. **Match the codebase.** Typed GDScript, the existing comment register (see
   `sim/resolve.gd`), code-built UI, no `Node` dependencies in `sim/`. Lint with
   `gdformat`/`gdparse` (installed).
6. **Escalate, don't assume**, on any of: a save-migration need (this phase plans
   **none** — flag if you find one), relaxing any validation rule, editing
   VISION.md/IMPLEMENTATION.md/bible beyond what a WP names, adding files not
   listed here, adding dependencies, deleting anything not listed here.

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

1. **A class is three things at once** (VISION.md §7):
   - **Stat modifiers** — multiplicative on the five attributes.
   - **Equipment + gene access by category** — adaptations and gene-affixes carry
     a `category`; a class allows a set of categories. **Monotonic-safe model:**
     the basic `generalist` category is buildable by everyone; specialist-exclusive
     categories are buildable only by the class that unlocks them (and its
     descendants). Because classes are **sticky** (you only ever descend) a
     lineage's allowed set only *grows* — so specializing **never strands** equipped
     gear. The flexibility you trade is the ability to ever build a *rival*
     specialist's exclusive kit; to get it, you branch a fresh lineage.
   - **A light in-niche multiplier** — a small material/gene buff that applies only
     when the lineage works a node in the class's `home_niches`. This is the one
     **new engine term** (the "specialist at home" surface). It is a buff at home
     and **identity (×1.0) elsewhere — never a penalty** (loss-aversion is banned,
     VISION.md §12).
2. **Option A — doll slots are attribute subsystems.** Each slot's tier feeds a
   *specific* attribute instead of a uniform +Power. This replaces the Phase-1
   `effective_power = power + Σ tiers` rule and is therefore an **economy change**
   re-proven in WP6. Slot→attribute map (§2.1) — *mechanical, flagged for sign-off*.
3. **Vitality stays unused this phase.** Map only power/resilience/metabolism/
   instinct to slots; `gland` is the affix host (no base stat). Vitality gets a
   real job in a later phase — **do not invent one** (YAGNI; matches the Phase-2
   precedent that parked `resilience` until it was needed).
4. **Cladogenesis = fresh respec.** A branched lineage starts with an **empty
   doll** and the **Generalist** class, sharing the **account-wide gene bank**
   (`genes_known` is already global — nothing is copied). This is the respec valve
   (VISION.md §4): a mis-built lineage is never punished; you branch a fresh one.
5. **Classes are sticky.** You progress *down* the tree; you cannot re-pick or
   regress. The respec is to branch (decision 4). This gives the commitment weight
   (VISION.md §7 "tiered commitment").
6. **Minimal v1 tree.** Generalist (root) → **three** tier-1 classes: Predator,
   Armored Grazer, Filter Feeder. Tier-2 hyper-specialists are **deferred**.
7. **Placeholder soft cap.** Diminishing returns on effective Power past a knee
   (§2.4), so breadth-led growth has shape (VISION.md §14) and the Phase-0 curve
   doesn't break at the top end. Constants are placeholders; **WP6 tunes them and
   Leon signs the numbers.** Hard constraint: the cap must **not strand existing
   Age-I content** — Anomalocaris (DEF 9) stays beatable by an appropriate build.
8. **Roster: exactly 2 active slots, hard.** `slots_active`/`slots_max` stay 2.
   The slot-unlock schedule and graduation-frees-a-slot are Phase 4+ (§20.7 dial).

**No-trap-build constraint (VISION.md §11, gate-enforced in WP3).** Access
restrictions create identity only if **every class can still fill a complete,
top-tier-capable doll** in its niche. A class barred from gear it needs is a trap.
WP3 adds a check that every class's allowed categories cover every essential slot.

**Schema stays v2.** The save already holds multiple lineages and `class_node`;
Option A, the class system, and cladogenesis add **no** new save fields. If a WP
finds it genuinely needs one, **stop and flag** — do not bump silently.

---

## 2. WP1 — Engine: Option A, class modifiers, in-niche multiplier, soft cap

**Files:** `sim/resolve.gd`, `sim/content.gd` (a `class_node()` accessor),
call-site updates in `sim/commands.gd`, `sim/accrual.gd`, `tests/economy_test.gd`,
`tests/sim_test.gd`, `ui/main.gd`.

### 2.1 Effective attributes (Option A + class stat mods)

New constants in `Resolve` (replaces `TIER_POWER`):

```gdscript
## Which attribute each doll slot's tier feeds (Option A). gland is the affix
## host and feeds no base attribute; vitality is unused this phase.
## NOTE (flagged for Leon): locomotion→power is a tuning choice — it keeps two
## power slots so the margin engine stays healthy. WP6 may flip it to metabolism.
const SLOT_ATTRIBUTE: Dictionary = {
    "mouthparts": "power",
    "locomotion": "power",
    "integument": "resilience",
    "metabolic_core": "metabolism",
    "sensory": "instinct",
    "gland": "",
}
const SLOT_TIER_WEIGHT: float = 1.0   # points added to a slot's attribute per tier
```

```gdscript
## The lineage's five attributes after Option A slot contributions and the class
## stat modifiers. THIS is what every rate helper reads — never lineage.attributes
## directly (that is the un-modified base).
static func effective_attributes(lineage: Lineage, content: Content) -> Dictionary
```

Formula (verbatim):

```text
attrs = lineage.attributes.duplicate()              # base {vitality,power,resilience,metabolism,instinct}
for slot, inst in lineage.doll:
    a = SLOT_ATTRIBUTE[slot]
    if a != "": attrs[a] += SLOT_TIER_WEIGHT * inst.tier
cls = content.class_node(lineage.class_node)         # {} for unknown → identity
for stat, mult in cls.get("stat_mods", {}):
    attrs[stat] = attrs[stat] * mult
return attrs
```

### 2.2 Soft cap on Power, then effective_power

```text
SOFT_CAP_KNEE := 12.0     # placeholder — WP6 tunes; must sit above the Age-I beat threshold
SOFT_CAP_K    := 0.15     # placeholder — asymptote ≈ KNEE + 1/K

static func soft_cap(p):
    if p <= SOFT_CAP_KNEE: return p
    over = p - SOFT_CAP_KNEE
    return SOFT_CAP_KNEE + over / (1.0 + SOFT_CAP_K * over)
```

`effective_power(lineage, content)` becomes:
`soft_cap(effective_attributes(lineage, content).power)`. **Signature gains
`content`** — propagate to the private helpers `_eff`, `_gate`, `_danger_factor`
(they currently call `effective_power(lineage)` and read `lineage.attributes`
directly; both must route through `effective_attributes`/`effective_power` with
`content`). No default args — force the compiler to find every call site.

### 2.3 The in-niche multiplier (the one new engine term)

```gdscript
## {material, gene} multipliers from the lineage's class, applied only when the
## worked node sits in one of the class's home_niches. Buff at home, ×1.0 away.
static func niche_mult(lineage: Lineage, node: Dictionary, content: Content) -> Dictionary
```

```text
cls = content.class_node(lineage.class_node)
if String(node.niche) in cls.get("home_niches", []):
    return {material: cls.niche_mult.material, gene: cls.niche_mult.gene}
return {material: 1.0, gene: 1.0}
```

Fold into the existing rates (the *only* places it enters):
- `material_rate` final line: `... * niche_mult(...).material`
- `gene_rate` return: `... * niche_mult(...).gene`
- `splice_rate_eff`: **unchanged** (the in-niche buff covers materials + the gene
  chase; splicing keeps its Phase-2 math).

All other Phase-2 math (affix_totals, danger, dot, pen, ambush) is **unchanged**;
the only edits are: attributes now come from `effective_attributes`, Power is
soft-capped, and the two rate lines gain the niche multiplier.

### 2.4 Tests (extend `tests/sim_test.gd`)

Exact-number assertions, each from a hand-built lineage + class + node:
- **Option A:** a tier-3 mouthparts adaptation raises effective power by 3; a
  tier-3 integument raises effective resilience by 3 and **does not** raise power
  (the Phase-1 uniform-power rule is gone).
- **Class stat mods:** `stat_mods {power: 1.25}` → effective power ×1.25 after
  slot contributions; an unknown `class_node` is identity.
- **Soft cap:** a power below `SOFT_CAP_KNEE` is unchanged; well above it is
  compressed and never exceeds `KNEE + 1/SOFT_CAP_K`.
- **Niche multiplier:** material/gene rate ×buff when the node's niche is a home
  niche; ×1.0 otherwise; splice rate identical either way.
- **Determinism:** two `accrue()` runs over the same gap + seed → identical events
  (Option A/class/soft-cap must not introduce nondeterminism).

---

## 3. WP2 — State, commands: class, cladogenesis, roster

**Files:** `sim/commands.gd`, `sim/content.gd` (`class_node()` accessor + an
`allowed_categories` helper), `tests/sim_test.gd`. **No `game_state.gd` schema
change** (decision §1.8); if you believe one is required, stop and flag.

### 3.1 Access helper

```gdscript
## The set of categories a lineage may build/express: "generalist" plus every
## category unlocked along its committed path (root → class_node). Used by
## metabolize() and graft() for eligibility, and by the UI for greying.
static func allowed_categories(lineage: Lineage, content: Content) -> Dictionary  # set: cat -> true
```

Walk `class_node` up its `parent` chain to the root, unioning each node's
`unlocks_categories`; always include `"generalist"`.

### 3.2 Eligibility gates on existing commands

- **`metabolize()`** — before building, require the adaptation's `category` (default
  `"generalist"`) is in `allowed_categories(lineage)`. Reason on fail:
  `"<class name> cannot build <adaptation name>"`. *(By the monotonic model a
  lineage can only ever have built allowed gear, so tier-ups never conflict.)*
- **`graft()`** — before grafting, require the affix's `category` (default
  `"generalist"`) is in `allowed_categories(lineage)`. Reason on fail likewise.

### 3.3 `pick_class` (sticky descent)

```gdscript
static func pick_class(state, content, lineage_id, class_id) -> Dictionary  # {ok, reason}
```

1. Lineage exists; `class_id` is a real `class_tree` row.
2. **Sticky descent:** `class_id`'s `parent` chain must pass through the lineage's
   current `class_node` (i.e. the target is a descendant of where you are). A
   no-op (`class_id == class_node`) returns `ok` silently. Regressing or jumping
   to a sibling → `{ok: false, reason: "classes are sticky — branch a new lineage to respec"}`.
3. **Requirements** (VISION.md §7 "gated by affix-keys and genes"): for each role
   in `requires.affix_keys`, the lineage has ≥1 equipped graft of that role (reuse
   the `meets_niche_keys` role-scan); for each gene id in `requires.genes`,
   `genes_known` has ≥1 copy. Reason names the missing requirement.
4. Set `lineage.class_node = class_id`; return `ok`. No gear is touched (monotonic
   model — the allowed set only grew).

### 3.4 `branch_lineage` (cladogenesis)

```gdscript
static func branch_lineage(state, content, parent_id, display_name) -> Dictionary  # {ok, reason, lineage?}
```

1. Count non-graduated lineages; if `>= state.slots_active` →
   `{ok: false, reason: "no free roster slot"}`.
2. New `Lineage` with a unique id (e.g. `"lin_" + str(state.lineages.size())` —
   must not collide), `display_name`, `class_node = "generalist"`, empty doll.
3. `assigned_node` = the **starter entry node** (the first node in content, the
   benthos eat node) — a fresh Generalist meets no niche keys, so it must start in
   the keyless starter niche. *(Do not inherit the parent's node; a fresh lineage
   may not meet that niche's key.)*
4. Append to `state.lineages`; return `{ok: true, lineage: l}`. The account gene
   bank is shared automatically (no copy). `parent_id` is recorded only if a
   `parent` flavor field is wanted — **not required**; skip if it needs a schema
   field.

### 3.5 Tests
`metabolize`/`graft` eligibility (allowed pass, disallowed fail, generalist gear
always allowed); `pick_class` (descend ok, sibling/regress rejected, requirement
unmet rejected then met → ok, no-op); `branch_lineage` (fresh lineage shape,
shares gene bank, blocked when roster full); the monotonic invariant (after any
legal `pick_class`, every previously-equipped item is still allowed).

---

## 4. WP3 — Validation gate extensions

**File:** `sim/validation.gd`, plus a `class_tree` entry in `Content.FILES` and
`validate()`’s call list. Keep every existing check.

1. **New content file `class_tree`** loaded by `Content` (add to `FILES`).
2. **Class rows:** unique `id`; exactly **one root** (`parent == ""`); every other
   `parent` references a real class; **no cycles**, graph connected to the root;
   `stat_mods` keys ⊆ the five attribute names and values `> 0`; `home_niches` ⊆
   existing niches; `niche_mult.material`/`.gene` present and `>= 1.0` (buff, never
   a nerf — §1.1); `requires.affix_keys` ⊆ `ROLES`; `requires.genes` ⊆ gene ids;
   `unlocks_categories` is an array of strings; `source` present.
3. **Categories:** every adaptation and every affix has a `category` string
   (default `"generalist"` is acceptable if absent — but assert the field exists
   once content adds specialist gear). Every category named in any class's
   `unlocks_categories` must be used by ≥1 adaptation **or** affix (no unreachable
   unlock); every non-`generalist` category used by gear must be unlocked by ≥1
   class (no unbuildable gear).
4. **No-trap-build check (VISION.md §11):** for **every** class node, the union of
   `"generalist"` + categories unlocked along its path must include ≥1 adaptation
   for each **essential slot** = `[mouthparts, integument, locomotion,
   metabolic_core, sensory]` (gland is the optional wildcard). Fail loudly naming
   the class and the uncoverable slot.

---

## 5. WP4 — Content: the class tree + categories, through all three gates

**Files:** `data/class_tree.json` (new), `data/adaptations.json` +
`data/affixes.json` (add `category`), new specialist adaptations/affixes as needed,
`bible/refs/classes.md` (new — the three archetypes, sourced), `bible/world_spine.md`
(archetype table status note only if a row's status flips).

**Process:** you draft rows + the ref file with real citations; **every row stops
at Leon for gates 2–3** before merge. List each biological claim in the PR. All
numbers are **placeholders — WP6 retunes**; the *structure* (which class, which
niche, which key, which exclusive gear) is the signed part.

### 5.1 The class tree (grounded in `bible/world_spine.md` archetypes)

| id | name | parent | home niche | requires (key) | unlocks category | identity (stat_mods) |
|---|---|---|---|---|---|---|
| `generalist` | Generalist | `""` | — | — | — | none (root; the Mesopredator) |
| `predator` | Predator | `generalist` | `reef_edge` | `penetration` | `raptorial` | power↑, metabolism↓ |
| `armored_grazer` | Armored Grazer | `generalist` | `shallow_benthos` | `guard` | `heavy_armor` | resilience↑, metabolism↓ |
| `filter_feeder` | Filter Feeder | `generalist` | `pelagic` | `sustain` | `filter_apparatus` | metabolism↑, power↓ |

`niche_mult` for each specialist ≈ `{material: 1.2, gene: 1.2}` at home
(placeholder). The Generalist has empty `stat_mods`, no `home_niches`, identity
`niche_mult`, no `requires`, no `unlocks_categories` — it is intentionally the
launch pad and respec hub, not a finished build; the no-trap rule is checked on
the **leaf** classes (each must fill a full doll from `generalist` + its category).

### 5.2 Categories on existing gear + the exclusive specialist gear

- Tag every existing adaptation and affix with a `category`. The Phase-1/2 kit is
  all `"generalist"` (buildable by every class).
- Each specialist needs **≥1 exclusive piece** to feel special. Author at least:
  - `predator` → a `raptorial` mouthparts adaptation (e.g. a raptorial claw) —
    real radiodont/arthropod weaponry (chronology-clean).
  - `armored_grazer` → a `heavy_armor` integument adaptation (e.g. fused dorsal
    plating) — real biomineralized defense.
  - `filter_feeder` → a `filter_apparatus` metabolic_core or mouthparts adaptation
    — Tamisiocaris-style filter combs (the bible already lists this splice).
  Optionally a category-tagged affix per specialist, unlocked by a gene, if the
  affix layer needs the identity too. Keep the set **small** (moat: combinatorics
  from few primitives, not authored volume).
- Because a specialist now has *two* candidates in a slot (generalist piece vs.
  its exclusive piece), pick-between-items emerges for free — **do not** build a
  separate "competing adaptations" system (deferred Option B).

### 5.3 The archetype ref

`bible/refs/classes.md`: one section per class with a real ecological-strategy
citation (ambush predation; armored grazing/biomineralization; suspension/filter
feeding). Gate 2 checks every asserted capability against it.

---

## 6. WP5 — UI (placeholder look, observer-only, code-built)

**File:** `ui/main.gd` (+ `ui/colors.gd` as needed). Same pattern as Phase 1/2:
every widget from content data; mutations only via Store commands (Store gains thin
wrappers for `pick_class`, `branch_lineage` with signals).

1. **Roster bar.** Both active lineages visible; tap to switch which one the screen
   shows. Each chip shows the lineage's class. A **"Branch new lineage"** action
   when a roster slot is free; disabled with the reason when full.
2. **Class screen/tab.** Shows the current class, its stat mods + home-niche buff,
   and the pickable children (with their requirements, identity, and what category
   they unlock). Committing is a **confirm** (sticky — copy says so). Locked
   children show the unmet requirement. Reachable-but-uncommitted children invite
   the tap.
3. **Doll.** Each slot now shows **which attribute it feeds** (Option A). In the
   metabolize/graft pickers, gear whose category is **not** in the lineage's
   allowed set is greyed/hidden with a "requires <class>" hint.
4. **Power readout** reflects the soft cap (show the effective, capped value; a
   subtle "near cap" cue is enough — no new mechanic).
5. **Voice pass** on all new strings (class names, branch copy, sticky-commit
   warning, lock hints) against `bible/voice.md`. Leon reviews as gate 3. (Also
   close the still-open Phase-2 voice review if any strings remain unsigned.)

---

## 7. WP6 — Harness: re-prove the chase curve under the new economy

**Files:** `tests/economy_test.gd`, `tools/chart_chase.py` (only if columns change
— append, never rename; the chart reads by header name).

Option A + the soft cap + class mods change the economy, so the 6-week model is
re-run with the two model lineages now committing **different classes**:

1. Update call sites for the new `effective_power(lineage, content)` etc.
2. Policy (keep it dumb and explicit — a model, not an AI): lineage **`hunter`**
   commits `predator` when it meets the `penetration` key, migrates toward
   `reef_edge`; lineage **`grazer`** commits `armored_grazer` (or `filter_feeder`)
   and works its home niche. Each builds/grafts only **allowed** gear; commits its
   class as soon as eligible. New CSV columns: `<lineage>_class`,
   `<lineage>_eff_power`.
3. Re-run the 6-week arc. **Acceptance** (the §9a never-flat property **plus** the
   Phase-3 shape):
   - mean interesting events/check-in does not decay week-over-week (week 6 ≥ ~80%
     of week 1); no dead check-ins (min ≥ 1);
   - legendary dry-streak **p50 in [10,25]** check-ins (p90 reported, not gated —
     the no-pity experiment continues);
   - **soft cap bites:** each lineage's `eff_power` plateaus (does not grow
     unbounded) — the breadth-led shape (VISION.md §14);
   - **no stranded content:** an appropriately-built lineage still beats
     Anomalocaris (DEF 9) inside the window (else the soft cap or the slot map is
     mistuned);
   - the two lineages end the arc with **different** class/gear/niche profiles
     (the model's proxy for the gate — if the policy can't make them diverge, the
     system can't either).
4. Tune placeholders (§5 numbers, `SOFT_CAP_KNEE`/`SOFT_CAP_K`, `niche_mult`,
   `SLOT_ATTRIBUTE` if needed) until acceptance holds. **Leon eyeballs the chart
   and signs the numbers.**

---

## 8. WP7 — Playtest build & the gate

Leon's job, with your support: web export to the friend cohort (his existing flow).
The gate question (IMPLEMENTATION.md §4): *with two animal lineages, does each feel
like a different character to check in on, or is it tap-claim-twice?* Evidence we
want: players describing their two lineages as different builds/roles unprompted,
choosing a class with intent, and branching a second lineage to try another path.
Watch for: classes read as cosmetic, restrictions feel arbitrary/annoying rather
than identity-giving, the roster feels like tap-claim-twice. **If they feel
identical, the fix is role variety (lean on the real-biology class differences),
not more slots** (IMPLEMENTATION.md §4). Honest pass/fail goes in DECISIONS.md and
closes the phase — at which point **this file is deleted**.

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
behind (CLAUDE.md §2.7). When the phase closes, canonize the finalized class
system + Option A into **VISION.md §7** and **IMPLEMENTATION.md §4** and delete
this file (the DECISIONS.md entry is the permanent record).

**Out of scope for this phase (do not build, stub, or scaffold):** tier-2 /
hyper-specialist classes, a vitality use, skills XP, the roster slot-unlock
schedule (stays 2), graduation polish + graduation-frees-a-slot, offline-accrual
**application** to the save + the Dev-dispatch while-you-were-away UI (Phase 4),
notifications, a separate "competing adaptations per slot" system (emerges for
free, §5.2), Age II content, clock-tamper defense, pity mechanics, art pass.
