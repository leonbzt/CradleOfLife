# PHASE3_5.md — Work order: The check-in becomes a session you play

> **Direction signed by Leon (2026-06-13); sub-decisions resolved inline below.**
> Temporary work order for the Phase 3.5 interphase, in the PHASE2/PHASE3 style;
> deleted when the phase closes (the DECISIONS.md 2026-06-13 entry is the permanent
> record). It **reorders the plan** (pulls the session loop forward from Phase 4)
> and proposes one optional schema bump (v3). If this file and the canonical docs
> disagree, the canonical docs win — stop and flag.
>
> **Progress (2026-06-13):** WP1 ✅ (session loop + dispatch) · WP2 ✅ (do-now
> agenda) · WP3–WP7 pending. See DECISIONS.md 2026-06-13 for the implementation
> record.

---

## The diagnosis (why this phase exists)

Leon's Phase-3 playtest verdict: *"there is fun for now, but not a lot to do
concretely, and it's mainly just waiting with very short check-ins."* Two causes:

1. **The check-in product does not exist yet.** What Leon is testing is the live
   2.5s tick — watching accrual happen with nothing to do. But the real product
   (VISION.md §16) is the **check-in**: you're away, accrual runs closed-form, and
   you *return to a pile of results and a queue of decisions* (the Dev dispatch).
   That return moment is Phase 4 work and is unbuilt. **This is the #1 fix.**
2. **Decision density per check-in is too low.** The fix is **not longer
   check-ins** (short is by design) — it is *more concrete, satisfying things to do
   and decide*, and a chase made legible enough to *feel*.

**Phase thesis.** *A check-in stops being a timer you watch and becomes a short
session you play:* you return to a Dev dispatch, see a concrete agenda, make real
build choices, and watch your chase advance — while idle still earns at full rate
and nothing is ever lost by being away (VISION.md §12).

This phase is **almost entirely legibility, wiring, and feel over the engine that
already exists.** `Accrual` is done; `Resolve` is done; data is through the gates.
We build the *session*, expressing systems we already have — not new mechanics.

---

## Signed decisions (Leon, 2026-06-13)

- **D1 — Reorder: YES.** Offline-accrual *application* + the while-you-were-away
  **dispatch** move into 3.5 (WP1). Phase 4 keeps notifications, the land-fall age
  transition, and telemetry.
- **D2 — Idle vs active (touches VISION §12).** Chase + **denser decisions stay the
  core**. 3.5 ships **visible/watchable combat** (OSRS/Melvor feel) that earns the
  *same whether or not you watch* — active *feel*, not active *earn*. An
  **active-benefit "babysit" layer is WANTED but deferred** to a dedicated design
  session (it's a real §4 change to the locked idle-earns stance; design it before
  building so it never becomes "log in or lose"). **Do not build any active-earn
  mechanic in 3.5.**
- **D3 — Metabolize-as-choice: YES.** Slots become "what this organ becomes" with
  ≥2 generalist options per essential slot. The deeper *situational best-in-slot*
  want goes to the build-identity design session, not here.
- **D4 — Derived "do-now" agenda: YES.** Fully computed from current state; no new
  save fields.
- **D5 — Schema v3 milestones: do it if cheap.** Powers the map-unlock achievements
  (WP6). If the migration proves more than trivial, drop WP6 and stay on v2 — flag
  it rather than forcing it.
- **D6 — Clock-tamper: clamp only.** `dt` clamped to `[0, OFFLINE_CAP≈72h]`; no
  other anti-cheat in v1.

---

## 0. Rules for the implementer (carried from PHASE3 §0)

You are executing a signed design, not designing. Read `CLAUDE.md` first. This
phase is **mostly UI + wiring**; the only engine touches are (1) applying the
existing `Accrual` batch on real elapsed time with a clamp, and (2) — if D5 holds —
a `schema_version` 3 migration adding a `milestones` dict. **No new `math_term`, no
new resolve lever, no second economy, no active-earn action (D2).** Anything beyond
what a WP names → stop and flag.

1. **One work package per commit**, in order (WP1→WP7). Every WP ends green (§9).
2. **Derive, don't store.** The agenda (WP2) and dispatch (WP1) are pure functions
   of existing state + the accrual batch. Add save fields only where D5 says so.
3. **Content rows need sources + all three gates.** New generalist adaptations
   (WP3) and any new strings get gate-2/gate-3 review by Leon before merge; list
   every biological claim in the PR.
4. **Match the codebase.** Typed GDScript, the `sim/resolve.gd` comment register,
   code-built UI, no `Node` deps in `sim/`. Lint with `gdformat`/`gdparse`.
5. **Escalate, don't assume**, on: any save-migration beyond D5, relaxing a
   validation rule, editing VISION/IMPLEMENTATION/bible beyond what a WP names,
   adding files/deps not listed here, touching the economy math.

Run commands (Godot 4.6.2 at `/home/leon/Apps/godot/Godot_v4.6.2-stable_linux.x86_64`):

```bash
godot --headless --import
godot --headless --script res://tests/validate_data.gd     # gate 1
godot --headless --script res://tests/sim_test.gd          # commands + math
godot --headless --script res://tests/economy_test.gd      # the chase harness
godot --headless --quit-after 20                           # boot smoke
```

---

## WP1 — The session loop: offline accrual application + the Dev dispatch

**The spine — this is what makes a check-in a check-in.** The accrual engine is
done (`sim/accrual.gd`, mirrored by `Store.dev_fast_forward`). This WP wires it to
real elapsed time and presents the result in the Dev voice.

**Files:** `state_store.gd` (focus-time accrual + clamp), `ui/main.gd` (the dispatch
panel), `tests/sim_test.gd`. `sim/accrual.gd` is reused unchanged.

1. **Apply on focus/launch.** On `_ready` and on `NOTIFICATION_APPLICATION_RESUMED`
   / window focus-in: `dt = now − state.last_seen_unix`, clamp `[0, OFFLINE_CAP]`
   (D6), run `Accrual.accrue`, apply the batch exactly as `dev_fast_forward` does
   (materials summed; gene events → `genes_known`; splice events → `splice_offers`).
   **Factor the apply into one shared helper** so the real path and `dev_fast_forward`
   cannot drift. Keep the live tick while open; it advances `last_seen` on each save,
   so there is **no gap and no double-count** across close/reopen.
2. **The dispatch panel** (`ui/main.gd`), in the §2a Dev voice:
   - A patch-note header keyed to elapsed time (*"Dispatch — 8h offline. The server
     kept running."*). **Good-news framing only**; never "you lost progress" (§12).
   - **Per-lineage summary, aggregated not enumerated:** materials gained, gene
     drops grouped by rarity ("7 common, 1 **rare**"), splice offers waiting. A gap
     that produced 72 events shows as a tidy rarity tally, **never a scroll of 72
     lines** (§16 brevity + honesty).
   - **Lead with the rare moment.** A rare/epic/legendary drop or a waiting splice
     is the headline, with rarity colour and a pulse — the felt event the chase
     promises (§9a). Commons are a quiet tally beneath.
   - **"Continue"** dismisses to the home screen with the agenda (WP2) already
     populated by what just landed.
3. **Tests:** the shared apply-helper credits exactly what `Accrual.accrue` returns
   for a fixed gap+seed; `dt` clamps (negative→0, huge→cap); no double-count across
   two consecutive applies with no real time between (second ≈ 0); determinism held.

---

## WP2 — The agenda: a derived "what to do now" surface

**Answers "not a lot to do concretely."** A small panel of concrete, tappable
objectives, fully derived from current state — no new save fields (D4).

**Files:** `ui/main.gd`, a pure helper (`sim/agenda.gd`, headless-testable),
`tests/sim_test.gd`.

For the shown lineage, compute up to ~4 ranked objectives from:
- **Affordable now:** a tier-up you have the materials for (→ jump to that slot).
- **Claimable now:** a splice offer waiting (→ the claim).
- **One copy short:** an affix you could express a tier higher with one more copy
  of its gene (names the splice target that drops it — makes the invisible copy
  ladder a stated goal).
- **Just out of reach:** the next node whose defense your effective power is closest
  to clearing (names the gap, "need +2 power").
- **One key away:** a class whose `requires` you nearly meet (names the missing
  affix-key or gene).

Each is a one-line, in-voice nudge whose tap navigates to the action. This is the
legible face of opportunity cost (§5) and the chase ceiling (§9a). **Tests:** right
objective for hand-built states; met requirements do *not* surface; stable order.

---

## WP3 — Metabolize-as-choice (closes the open thread)

**Files:** `data/adaptations.json` (new generalist options), `ui/main.gd` (picker
rework), `bible/refs/*.md` (sources), `tests/validate_data.gd` if a grouping field
is added.

1. **Reframe the screen** (D3): each essential slot shows "**what this organ can
   become**" — a choose-one set with the trade-off legible (which attribute it feeds,
   Option A), not a flat row of build buttons. Specialists already see
   generalist-vs-exclusive; this gives the *generalist* the same choice.
2. **Author ≥2 generalist candidates per essential slot** (e.g. mouthparts:
   crushing vs. grasping vs. filtering; integument: plating vs. spines vs. flexible).
   Keep the set **small** (moat = combinatorics from few primitives). Every row is
   real biology, sourced, through all three gates — Leon reviews 2/3 before merge.
3. **No new mechanic** — `category:"generalist"` adaptations on existing
   slots/attributes; the "choice" is which attribute/affordance you grow. **Tests:**
   validation still passes (the no-trap-build check already guarantees each essential
   slot is fillable; this only widens the menu).

---

## WP4 — Visible combat + the splice catalogue (the chase becomes legible)

**Files:** `ui/main.gd`, `ui/loot_pop.gd`, `ui/colors.gd`. **UI only** — renders
data `Resolve`/`Accrual` already produce. No engine, no new earn stream (D2).

1. **Visible combat (the headline).** When a fight roll fires (live, or as a
   highlighted dispatch line), render it as an **OSRS/Melvor-style event**: your
   effective power vs the node's effective defense, the margin, **penetration
   cracking armour**, the **danger tax** landing, the **splice window** opening —
   with a hit/clash animation or equivalent feedback. Turn "yield ×2.3" into "your
   toothed appendage cracked the trilobite; sclerite splice offered." This is the
   single biggest "it's an RPG, not a number" win, and it delivers the *active feel*
   D2 wants without changing earnings (watchable, never required).
   *Scope note: this is the legible **clash render**, not a full combat surface with
   abilities/active-resolve — that is its own design session (deferred, VISION §19).*
2. **The splice catalogue.** A collection surface: each creature is a named splice
   target holding a distinct gene; show known/total, and per gene the copies held
   and the express-tier they unlock (the copy ladder, made visible). Makes "what
   should I fight" the build decision the Phase-2 gate is about.
   *Note for the splice-catalogue design session: today splice and gene-drop both
   just add a `genes_known` copy and signature genes also appear in random drop
   tables, so the two feel identical (Leon's open question). The likely sharpening —
   make signature genes **splice-only** — is an economy change and is **out of scope
   here**; 3.5 only makes the existing distinction visible.*
3. **Rarity-themed loot moments.** Rare/epic/legendary gets the colour, the pulse,
   the held beat; commons stay quiet. The felt two-tier chase (§9b).

---

## WP5 — Tab IA + the phone check-in shape

**Files:** `ui/main.gd` (restructure), `ui/colors.gd`.

The screen is one long scroll. For a 2–5 min one-handed session (§16) and the
RuneScape grammar the vision calls for, restructure into **tabs**:
- **Dispatch/Home** — the WP1 dispatch + the WP2 agenda (the landing screen).
- **Body** — the doll + metabolize-as-choice (WP3) + express.
- **World** — niche selector, node cards, visible combat + splice catalogue (WP4).
- **Class/Tree** — the class panel + roster + branch.

Same observer pattern: every widget from content data, mutations only via Store
commands. The DEV bar stays (flagged for removal). **Voice pass** on all new
strings against `bible/voice.md` (Leon = gate 3).

---

## WP6 — Map-unlock achievements *(replaces the summit beat; only if D5 holds)*

**Files:** `sim/game_state.gd` (schema_version 3 + `milestones` dict + migration),
`state_store.gd`, `ui/main.gd`, `tests/sim_test.gd`.

Leon judged the apex "summit beat" unneeded (the pull comes from optimizing and
growing). The real felt-progress moment is **unlocking a new niche/map** via a
gene/affix-key. Give those unlocks an **achievement-style highlight** — a
celebrated, visually/conceptually marked moment when a lineage first builds the key
that opens a new niche — recorded in `milestones` so it fires once. This dignifies
the affix-key gating that already exists (no new mechanic). **Tests:** the milestone
sets once and never re-fires; v2→v3 migration adds an empty `milestones` and loses
nothing. *If migration is non-trivial, skip this WP and stay on v2 (D5) — flag it.*

---

## WP7 — Re-prove the harness + the playtest gate

**Files:** `tests/economy_test.gd` (only if a column changes), then Leon's web
export to the cohort.

1. **Harness:** none of WP1–WP6 changes the economy math (accrual application sums
   the same batch the harness already models; the rest is presentation). Re-run to
   confirm the chase curve is **unchanged** (week means non-decaying, legendary p50
   in [10,25], soft cap bites, no stranded content, lineages diverge). If a number
   moved, something leaked into the economy — stop and flag.
2. **The gate (the point of the phase):** *Does a check-in now feel like a short
   session you play — concrete things to do, a chase you can see — rather than a
   timer you watch?* Evidence: testers describe *doing* things (claiming, choosing
   what an organ becomes, chasing a copy, watching a fight); sessions feel purposeful;
   they return to the dispatch. Watch for: the dispatch read as a wall of text; the
   agenda ignored; "still nothing to do." Honest pass/fail → DECISIONS.md; on pass,
   canonize the reorder into IMPLEMENTATION.md §4 and delete this file.

---

## 9. Definition of done (every WP)

```bash
godot --headless --import
godot --headless --script res://tests/validate_data.gd   # exit 0
godot --headless --script res://tests/sim_test.gd        # exit 0
godot --headless --script res://tests/economy_test.gd    # exit 0 + curve unchanged
godot --headless --quit-after 20                         # boots clean
gdparse <touched .gd>                                    # parses
gdformat --check <touched .gd>                           # formatted
```

CI must stay green on every push. No dead code, no doc/code drift. On phase close:
fold the session loop + reorder into IMPLEMENTATION.md §4 (and any §16 wording),
record it in DECISIONS.md, delete this file.

**Deferred to dedicated design sessions (do not build/stub/scaffold here):** the
active-benefit "babysit" layer (D2 — touches §12), skills (OSRS-like / skill tree /
active skills), living meta / coevolution, build identity & situational
best-in-slot, the splice-vs-drop sharpening + full splice catalogue economy,
full OSRS/Melvor combat depth (abilities/active-resolve). **Also out of scope
(Phase 4+):** local notifications + the prediction scheduler, the land-fall age
transition + Age II content, telemetry, a finished pixel-art set (direction only).
```
