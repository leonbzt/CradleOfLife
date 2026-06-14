# WORKORDER_RESET.md — Reset to the clean spine

> **DRAFT — PROPOSED, awaiting Leon's review of the trim scope (CLAUDE.md §4).** 
> Temporary work order; deleted on completion, decisions in DECISIONS.md
> (2026-06-14 "Aggressive reset to the spine"). **Canonical docs win on conflict.**
>
> This is **step zero of the rebuild** — it precedes every "Next" piece (incl. the
> active verb). Goal: a clean, legible base on which the new vision is built *fresh*,
> with the old feature/content gravity removed but the proven architecture kept.

---

## The principle

**Park the old content & feature surface** (it biases the build toward adapting the
past). **Keep the vision-agnostic architecture** (it is how we prove the new vision —
especially the chase harness). Aggressive ≠ rewrite-from-scratch.

## The split (what happens to every system)

**KEEP (the true spine — untouched or near-untouched):**
- Node-free `sim/` architecture; `sim/rng.gd` (seeded).
- Data model: `game_state.gd` / `lineage.gd` / `adaptation_instance.gd` (trim only
  fields tied to parked systems, e.g. `class_node`).
- `content.gd` loader + `validation.gd` gate-1 (the **locked 7-role affix framework** —
  the moat; it stays even as affix *data* is trimmed).
- **`tests/economy_test.gd` — the chase harness. The #1 tool. Re-greened at every step.**
- The doll concept (slots + Express, VISION §7); the soft cap; the session/check-in
  frame (dispatch, do-now agenda, UI shell — minus the class tab).
- The data + three-gates pipeline; CI.

**PARK (remove from the active build; a git tag + history retain them):**
- The **class tree, in full**: `data/class_tree.json`; class math in `resolve.gd`
  (`niche_mult`, the `stat_mods` step in `effective_attributes`); category gating in
  `commands.gd`; `content.class_node`; `ui/tabs/class_tab.gd`. **Role derives from the
  doll instead.**
- **Most affix / gene / adaptation / niche / node DATA** — trimmed to a minimal,
  coherent starter set, rebuilt fresh in the rebuild. (The 7-role *framework* + gate-1
  stay; only the data shrinks.)

**REWRITE (keep the structure, rebuild the math — incrementally, re-proving the harness):**
- `resolve.gd` / `accrual.gd` economy → niches-with-teeth (power = access, signature
  stat = throughput) + mutation-under-selection + the active multiplier. Keep the
  power-vs-defense → loot + Poisson-gene *structure* and closed-form accrual.

**BUILD NEW (the rebuild, ROADMAP "Next"):** clean niche/node progression ladder ·
skills · niches-with-teeth · chase-lands-early · mutation-under-selection · the active
verb. (Each its own small signed piece.)

---

## The steps (Phase R — execute in order; this is the next build session)

- **R1 — Snapshot.** `git tag prototype-v3.5` (and a branch if wanted) so every parked
  system is one command away. *Gate: tag exists; main is clean.*
- **R2 — Park the class tree.** Remove the files/code above; make role a value derived
  from the doll (a pure read, no engine). Strip `niche_mult` from the economy. *Gate:
  project boots; `sim_test` + `validate_data` green; **harness re-proven** (removing
  `niche_mult` is an economy change — the never-flat curve must still hold).*
- **R3 — Trim content to a clean starter** (
  **Leon 26-6-14: decisions: approved proposed trim scope, choose the ones that fit the vision and identity and biology the most.**
  throwaway placeholder scaffolding, replaced
  in the rebuild — *don't polish it*). *Proposed minimal set (confirm/tune at session
  start):* **1 niche** (`shallow_benthos`; park `pelagic`/`reef_edge` — affix-key-gated,
  a teeth concern); **~2–3 nodes** (≥1 passive eat + 1–2 defended fight, so power-vs-
  defense and the chase are feelable); **~2–3 affixes** across distinct roles (keeps
  gate-1 meaningful); **~4–5 genes** spanning common→rare→**1 legendary** (the two-tier
  distribution the harness needs to prove never-flat — **do not trim below this**); **~4–5
  adaptations** to fill the doll's core slots; **~2–3 materials**. Keep the 6 doll slots
  and the soft cap (framework). *Gate: gate-1 green; no dangling references; harness shows
  the two-tier shape.*
- **R4 — Reduce the economy to the clean core.** `resolve`/`accrual` = power-vs-defense
  → materials + the two-tier chase, no parked-system math, placeholder constants.
  **Re-prove the never-flat curve on the clean core — this is the critical gate of the
  whole reset.** *Gate: §9a holds on the clean economy.*
- **R5 — Write `SPINE.md`.** One page: the architecture, the one loop, the doll, the
  chase, the harness, and exactly what is parked. The base's source of truth.
- **R6 — Commit the clean base** (tagged). The spine is ready to build on.

---

## Then the rebuild (subsequent sessions; order proposed, adjustable)

Each is a small signed piece; the harness is re-greened on every economy change.

1. **Clean niche/node progression ladder** — sequential unlocks, show-only-the-next-few
   (Melvor / IdleOn / Iktah). The progression skeleton everything grinds on. *(Leon
   wants this early.)*
2. **Niches with teeth** — power = access, signature stat = throughput (VISION §11).
3. **Skill-level progression** — gates + powers + a guaranteed-progress floor.
4. **The chase lands early** — first gene in minutes; the #1 system made to *feel*.
5. **Mutation-under-selection** — the selection decision + niche bias (cures "random
   respec"); leaves the live-claim seam.
6. **The active verb** — `WORKORDER_ACTIVE_VERB.md` (Brace + Live-claim), now built on
   a clean base.

(Then Horizon: draft-against-budget + chromosomes · ability-tree · combat depth ·
Combo/Surge + metabolism burst-fuel · the ecosystem loop.)

---

## Cautions (honest)

- **The harness is non-negotiable to keep.** It is what makes aggressive safe. Every
  step that touches rates re-proves the never-flat curve (the #1 risk, VISION §9a).
- **Don't strip the architecture.** Node-free sim, one `resolve`, closed-form accrual,
  the gates — these are vision-agnostic and correct. "Aggressive" applies to *content
  and the class tree*, not the scaffolding.
- **Trim scope is the one open call.** R3's exact minimal set (how few affixes/genes/
  niches/nodes) is Leon's to tune before R3 runs — list it at session start. A proposed
  starting point is now in R3 above.

---

## How to proceed — what to check, what to plan

**The rhythm (subtractive, one system at a time).** Don't rip everything at once. Do
R2 → green → R3 → green → R4 → re-prove, each a small commit. After every step: the
project boots, `validate_data` + `sim_test` pass, gdlint is clean, and (on rate changes)
the harness still shows the never-flat shape. If a step turns red, fix or revert *that*
step before the next — never stack a second teardown on a broken one.

**Treat trimmed content as throwaway placeholder.** R3 is not about picking the "right"
old rows — it leaves the **minimum scaffolding that keeps the engine and harness running**
until the rebuild authors real content (B1+). This honours the no-old-gravity rule: the
kept rows are scaffolding, not "the content."

**Re-prove means *shape*, not *numbers*.** Stripping `niche_mult` (R2) and reducing the
economy (R4) will *change* the curve — expected. The gate is the §9a never-flat *shape*
(a meaningful event most check-ins; a legendary always reachable-but-never-given),
re-tuned with placeholder constants. The harness is the judge; the old numbers are not a
target.

**Pre-flight (before R2 — R1/snapshot is done):**
- [x] Current state committed, pushed, and **tagged** (`prototype-v3.5`).
- [ ] **Harness runs green *now*** (`godot --headless --script res://tests/economy_test.gd`)
  — confirm the tool works before changing the economy under it.
- [ ] Godot 4.6 + gdtoolkit on PATH (lint between steps).
- [ ] **Branch decision:** a `reset-spine` branch (tidier; merge when green) or `main`
  with the tag as the net. Either is fine; a branch is cleaner for a multi-step teardown.
- [ ] R3 trim scope confirmed/tuned (proposed set in R3 above).

**Planning the rebuild (after R6).** Each "Next" piece follows one rhythm: **propose a
small spec → Leon signs → build the smallest version → re-prove the harness → validate
the feel → next.** Actively resist the AI-bias: **design each piece from the vision
(VISION.md + ROADMAP "Next"), not from "what the old code did."** Parked code is a
reference of last resort, not a template. Build order is the rebuild list above; the
clean niche/node ladder leads.

**Definition of done for Phase R.** Project boots; all tests + gdlint green; the harness
shows the never-flat shape on the clean core economy; `SPINE.md` describes the *actual*
base; the class tree and excess content are parked (recoverable via the tag); the tree is
committed. You then build the new vision on a base you fully understand.
