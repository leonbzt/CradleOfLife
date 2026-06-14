# NEXT_SESSION.md — Start here

> **Temporary resume aid.** A seamless pickup point between sessions. Not canonical —
> if it disagrees with VISION / IMPLEMENTATION / DECISIONS / ROADMAP, those win.

## Where we are (2026-06-14)

- **RESET TO THE SPINE — the governing decision (signed 2026-06-14, building-blocks
  brainstorm).** The 3.5 feature surface ran ahead of the core *feeling* (cohort: dull,
  "random respec," "maxed upgrades without a gene"). So: **keep the engine + content
  pipeline; rebuild the loop's *feel* — active verb + legible progression + the chase
  landing — before re-accreting complexity.** Full record: DECISIONS.md 2026-06-14
  "Building-blocks brainstorm"; ordering in **ROADMAP.md** (Now/Next/Horizon rewritten).
  **Review the `git diff`.**
- **§12 reframed (locked):** idle is the **complete floor**; **active is a bounded,
  genuinely-fun ceiling and the primary way engaged players play** — gap = opportunity cost,
  never loss/decay. Litmus test: if a player never touches an active feature, is the game
  still complete and progressing? Yes → ship; No → cut. Active play = **two axes**
  (optimize-the-loop · light combat-babysit). VISION §12 + "What's locked" edited in place.
- **Vision spine (still current):** *mutation under selection — the lineage becomes what it
  grinds* (§9, reframed 2026-06-14). Selection is now **draft-against-a-budget** (bounded
  expression §7 + metabolic upkeep); **chromosomes = multi-affix genes, PoE-jewel slots**;
  the chase is for the gene that *completes a combo*, not the rarest.
- **Phase 3.5 — deprioritized behind the rebuild.** WP1–WP5 shipped. A player read on the
  current build (old WP7) is still useful signal; map-unlock polish (old WP6) is parked.
- **Sign-off owed (Leon):** gate 2/3 on the 5 new generalist adaptations' flavor + the new
  `bible/refs/shallow-benthos.md` rationale (science) and all new UI strings (voice).
- **UI is split per tab:** `ui/main.gd` shell; tabs in `ui/tabs/*.gd` over shared
  `ui_util` / `ui_state` / `express_sheet`. gdlint-clean.
- **One open pacing decision** for the rebuild: *at what level/timing gene-drafting enters*
  — a live feel call, not yet decided.

## To resume any session

Read `CLAUDE.md`, then `VISION.md` ("What's locked" + §21 disciplines + §9 the spine), the
current phase in `IMPLEMENTATION.md`, **`ROADMAP.md`** (the horizons), and the tail of
`DECISIONS.md` (incl. the Design-session backlog). Then this file.

---

## Recommended next — **scope the core-feel rebuild (ROADMAP "Next")**

The building-blocks brainstorm is **RESOLVED** (DECISIONS.md 2026-06-14). What's next is to
turn ROADMAP "Next" into a signed, formula-exact work order — the way PHASE2/PHASE3 were —
but **smallest-first**, one self-standing piece at a time, each re-proving the chase harness:

1. **The active verb** (the missing core): Axis 1 optimize-the-loop + Axis 2 light
   combat-babysit. This is the piece the cohort feedback most demands.
2. **Skill-level progression** (guaranteed-progress floor; "level the skill, not the node").
3. **Niches with teeth + sequential unlock ladder** (power = access, signature stat =
   throughput; show only the next couple of locked nodes).
4. **Chase lands early** (first gene in minutes).
5. **Selection as draft-against-budget** + chromosomes — *timing TBD (the one open feel call).*

**Process per piece:** §4 propose → Leon signs → build small → re-prove harness → validate.
Keep the engine; simplify the doll/affixes/classes freely where they don't serve the feel.

## The design-session backlog (Leon drives the order)

Full framings in `DECISIONS.md` → Design-session backlog; ordering in `ROADMAP.md`.

1. **Building-blocks brainstorm** — *recommended next* (above).
2. **Skills / ability-tree shape** — one branch per lineage; the identity carrier (build
   uniqueness + the carrier for active play & combat depth).
3. **Active / "babysit" layer** — optional active benefit; touches §12, design carefully.
4. **Splice-vs-drop economy** — make splicing targeted & distinct (likely splice-only genes).
5. **Living meta / coevolution** — Devs shift the meta as opportunity, never loss.
6. **Combat depth** — beyond the visible clash (abilities / active-resolve).
