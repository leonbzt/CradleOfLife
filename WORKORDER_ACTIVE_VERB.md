# WORKORDER_ACTIVE_VERB.md — The check-in becomes a session you *play and improve*

> **DRAFT — PROPOSED, awaiting Leon's sign-off (CLAUDE.md §4).** Nothing here is
> decided yet; the §3 "Open decisions" are the sign-offs needed before any build.
> Temporary work order in the PHASE2/PHASE3 style: once signed and built it is
> deleted, and its decisions move to DECISIONS.md. **If this file disagrees with
> VISION / IMPLEMENTATION / ROADMAP / DECISIONS, those win — stop and flag.**
>
> This is the **first piece of the reset-to-spine rebuild** (ROADMAP "Next"), and
> the one the 6/14 cohort feedback most demands: *"a fairly dull idle game where
> the only way to progress is to time-skip."* It builds the **active verb**.

---

## 0. Thesis & why this is first

The current loop is hollow to *do*: you assign a lineage and watch a timer. The
fix (VISION §12, reframed 2026-06-14) is that **active play is core**: a check-in
becomes a short session you *play and improve*, not just watch. Crucially, this
must be built so it can **never** become "log in or lose":

- **Idle is the complete floor** — offline/away accrual delivers the full baseline,
  never decays, never requires you to be present.
- **Active is a bounded, fun ceiling** — attentive play during a live session gives
  a *capped* uplift; the gap is opportunity cost, never loss.

This piece builds the **container** (the live session + the capped-uplift model +
the idle-floor guarantee). The chase/selection *content* that fills it (legible
skills, the gene draft) are sibling "Next" pieces that flow into this container; a
light version of live-claim ships here so the container isn't empty.

It is first because (a) the cohort screamed for it, and (b) it is the frame every
later active feature (combat depth, drafting, the ecosystem loop) plugs into — get
the §12 contract right *once*, in code and in the harness, and everything later
inherits it.

---

## 1. What's already here — we add a session layer, not an engine

Reuse, do not rebuild:

- `Resolve.resolve(lineage, node, dt, rng, content)` already models one action over
  `dt` and returns `{materials, gene, splice_offer}`. **The active verb is a new
  *parameter* on this existing math, not a new engine.**
- `Accrual` already integrates offline gaps using the *same* rates → this is the
  idle floor; it stays at the floor (active multiplier = 1.0) by construction.
- `Resolve.danger_factor()` already computes the fight retaliation tax → the
  **brace** input modulates this; no new combat engine.
- WP4's visible clash render already exists → the live session reuses it.

The one new idea: an **active-gain multiplier `A`** applied to a live session's
rates, `A ∈ [1.0, A_MAX]`, earned by attentive inputs. Offline/idle always uses
`A = 1.0`. That single parameter is the whole mechanism.

---

## 2. The §12 contract (non-negotiable invariant) and how we test it

1. **Idle pays the floor.** For any node and any wall-time, idling yields exactly
   the closed-form floor (`A = 1.0`). Being away never reduces it and never decays.
2. **Active is capped.** A live session's effective rates are multiplied by `A`,
   `1.0 ≤ A ≤ A_MAX`. Perfect play tops out at `A_MAX`; it cannot exceed it.
3. **No energy/stamina gate** on active play (that is a loss-aversion dark pattern,
   VISION §18). Active is pure attention + timing; it is self-limited by real time.
4. **Both bounds keep the chase alive.** The harness re-proves the never-flat curve
   (VISION §9a) at `A = 1.0` (the floor must be healthy) **and** at a sustained
   `A = A_MAX` (max active must not flatten/trivialize the chase).

**Tests (headless, deterministic):**
- *Idle-parity test:* a live session driven to `A = 1.0` produces the **same** loot
  distribution (within RNG-stream equality) as the offline accrual of the same
  wall-time. One economy, two evaluations — proven, not asserted.
- *Cap test:* a session pinned at `A_MAX` never exceeds `A_MAX ×` the floor rate.
- *Harness re-prove:* `economy_test.gd` runs the 6-week model at `A = 1.0` and at
  `A = A_MAX`; both must pass the §9a gate.

---

## 3. Open decisions for Leon (the sign-offs)

Each has a **proposal**; change any of them.

- **D1 — `A_MAX` (the active cap).** *Proposal: `A_MAX = 1.5`* (perfect active play
  ≈ 50% more efficient than idle, per active second). Modest, and the harness bounds
  it. Higher → active feels more rewarding but risks the chase / risks idlers feeling
  the gap as loss; lower → active feels pointless. **Your call on the number.**
- **D2 — first active inputs.** *Proposal: ship two — **Brace** (fight-node timing
  that cuts the danger tax) and **Live-claim** (genes/splices that surface mid-session
  pop for an in-the-moment claim). Defer the **Focus meter** (a tap-to-top-up uplift on
  any node) to a later WP.* This keeps the first build to one rich input + one dopamine
  beat.
- **D3 — live gene-draft: in or out here?** *Proposal: OUT of this piece.* Live-claim
  ships as a simple "claim the surfaced gene" beat; the full **draft-against-a-budget**
  (bounded expression + metabolic upkeep + chromosomes) is its own "Next" piece, and
  *when/at what level it enters* is the one open pacing call (ROADMAP). This work order
  leaves the seam for it.
- **D4 — does the active verb apply to Eat nodes too, or fight-only in v1?**
  *Proposal: fight-first.* Brace only means something where there's a danger tax. Eat
  nodes get the active uplift only once the Focus meter (D2, deferred) lands. So v1
  active = fight sessions; eat stays pure idle for now.
- **D5 — session length.** *Proposal: no artificial cap.* You play as long as you
  attend; the per-action cap (`A_MAX`) is the only limiter, and real attention is the
  natural bound. (Confirms no "energy" gate.)

---

## 4. Work packages (small; one per commit; harness re-proven where rates change)

**WP0 — Harness bounds the design (do this *first*).** Add the active-gain
multiplier `A` to `resolve`/`accrual` as a parameter (default `1.0`). Extend
`economy_test.gd` to run the 6-week model at `A = 1.0` and `A = A_MAX`. *Gate: both
pass §9a.* This bounds D1 in numbers before any UI.

**WP1 — The live session shell.** A "play this node" mode that drives `resolve()`
over small real-time `dt` slices with the existing clash render, instead of batching.
Closing the session (or going idle) hands the remainder back to the closed-form floor.
*Test: idle-parity (a session at `A = 1.0` == offline accrual of the same wall-time).*

**WP2 — Brace (the fight input).** A telegraphed incoming-hit beat; a well-timed tap
reduces `danger_factor`'s tax for a window. Accumulated good timing raises `A` toward
`A_MAX` for the session (capped). *Test: perfect bracing → `A_MAX`; no input → `A = 1.0`
== floor; never exceeds `A_MAX`.*

**WP3 — Live-claim.** Genes/splices that surface during the active session pop for an
immediate, satisfying claim (vs idle auto-banking at the floor). No new economy — same
roll, surfaced live. Leaves the seam for the future draft (D3). *Test: claimed-live and
auto-banked paths bank identical genes for the same RNG stream.*

**WP4 — The idle-floor legibility guarantee (UI + invariant).** The session UI shows
**"idle floor vs your active bonus"** explicitly, so the player reads active as *upside*
and never reads idle as *loss*. *Test: the displayed floor equals the accrual floor;
the bonus equals `(A − 1.0) ×` floor.* This is the §12 contract made visible.

**WP5 — Re-prove + validate.** Re-run the full harness; web-export to the cohort.

*(Deferred WP — Focus meter: a tap-to-top-up uplift that also works on Eat nodes.
Pulled in only if D2/D4 want it; not in the first build.)*

---

## 5. Out of scope (named, not built — VISION §19, §21)

- **Full combat depth** — turn model, ability rotations, food/heal types, the
  auto-battler proper (Iktah/Melvor). This piece is a *light* babysit on the existing
  resolve, not the combat system. (ROADMAP Horizon.)
- **Active abilities** — require combat depth above; sequence together, later.
- **The gene draft-against-a-budget + chromosomes** — its own "Next" piece (D3).
- **Axis-1 ecosystem loop** — the scaled-up optimize-the-loop verb; Horizon marquee.
- **The Focus meter / Eat-node active** — deferred WP (D2/D4).

---

## 6. Validation gate (the §12 litmus, with players)

A clear *yes* to **both**, or rework:

1. **Active is worth doing & fun** — testers choose to play sessions actively and say
   the brace/claim loop feels good (not a chore).
2. **Idle stays complete** — a tester who *only* idles still progresses well and does
   **not** report feeling they are "losing" by not playing actively.

Plus the harness gates (§2.4) green at both `A`-bounds. If (1) passes but (2) fails,
`A_MAX` is too high or the UI frames idle as loss — fix before proceeding.

---

## 7. Rules for the implementer

- **Keep `sim/` Node-free.** `A` lives in `resolve`/`accrual` as a plain parameter; the
  live session is a UI/driver layer observing state, never simulation in the scene tree.
- **One economy.** Active and idle are the *same* rates with `A = A_MAX` vs `A = 1.0`.
  Never write a second active-only economy path.
- **Re-prove the harness** on any rate or constant change (CLAUDE.md §6). The chase
  curve is the #1 gate.
- **No energy/stamina, no decay, no "while-you-were-gone you lost X"** — ever (§12, §18).
- **Simplify freely, but not here.** The doll/affixes/classes may be trimmed during the
  rebuild, but that is a *different* work order; this one only adds the session layer.
