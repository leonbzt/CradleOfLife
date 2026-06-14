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
- **R3 — Trim content to a clean starter.** Reduce affixes (keep the 7-role framework +
  a few seeds), genes, adaptations, niches, nodes to a minimal coherent base. *Gate:
  gate-1 green; no dangling references; harness green.*
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
  niches/nodes) is Leon's to tune before R3 runs — list it at session start.
