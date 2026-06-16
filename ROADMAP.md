# ROADMAP.md — Cradle of Life, the living roadmap

> **A living document, explicitly subject to change with development and player feedback.**
> It orders *what comes after the vertical slice, and roughly when* — it is **not a build
> spec and not a promise.** VISION.md owns *what the game is* (the spine: **mutation under
> selection**, §9); IMPLEMENTATION.md owns near-term architecture & phases; DECISIONS.md
> owns *why* things changed. When this disagrees with those, they win.
> Created 2026-06-14 alongside the mutation-under-selection reframe.

## How to read this

Four horizons, **few near and many far** — on purpose, to keep options open. The further
down, the more it is a *hypothesis*, not a plan. Everything past **Next** is governed by
the build disciplines (VISION §21): **each increment must be a complete, fun game by
itself** (think "a new sub-game per update"); the independent wins are sequenced first;
the co-dependent horizon never ships big-bang; the idle floor stays complete; and the
build stays ruthlessly gated by validation.

## The entry rule (governs what may enter a build)

A feature or role enters a build only when it:

1. is expressible by **data + the one `resolve()`** with no new engine system;
2. passes the **science gate in its age** (no "intelligence" build in the Cambrian);
3. needs **no deferred partner / host / ecosystem system** (VISION §19);
4. fits **animals-only** until the kingdoms expansion.

This is what keeps the long-term role vision (below) from corrupting v1.

---

## Now — the rebuild, on a clean spine

**The reset is done (2026-06-15 — Phases R1–R6, DECISIONS).** The class tree is parked (role
derives from the doll), content is trimmed to a clean single-niche starter, the never-flat
chase is re-proven on the clean core, and **`SPINE.md`** is the one-page source of truth for
*what the code is*. The base is small, legible, and vision-agnostic — the trailhead the
rebuild climbs from.

- **Live now:** the one loop (Power vs defense → materials + the chase), the doll (role
  derived, no class), the 7-role affix framework, closed-form accrual, the session/check-in
  frame, the harness — **plus the first three Next increments** (skills + ladder, chase-early,
  niches-with-teeth). Content has grown to two niches / 7 nodes (see `SPINE.md`).
- **Active play is core, not a sprinkle** — VISION §12: idle is the complete floor, active is
  a bounded fun ceiling, the gap is opportunity cost, never loss/decay.
- **The discipline holds:** each rebuild piece is small and signed, built **from the vision,
  not the parked code** (SPINE.md), re-proving the harness on every economy change.

## Next — the core-feel rebuild (the spine, made to *feel* good)

Each is independently buildable and testable; together they cure the 6/14 feedback. Each
economy change re-proves the chase harness. **Ordered by dependency — foundation first, the
active verb last** (signed 2026-06-15; DECISIONS): the active verb is the most-wanted outcome
but the most co-dependent piece, so it sits *on top of* the loop it optimizes, never under it.
Each ships as a signed work order (CLAUDE.md §5a).

- **✓ Done (2026-06-15) — Legible progression — skill-level first + the node ladder**. A skill level per (lineage × verb) that **gates** and
  **powers** (OSRS/Iktah), giving a guaranteed-progress floor every check-in ("level the skill,
  not the node"); and the nodes within a niche become a *sequential ladder* you unlock by skill
  level (mat-tier 1→2→3…), showing only the next couple of locked rungs (Iktah UX). Cures
  "random respec, no rhyme or reason" + "nothing to do" + adds the unfold dopamine. (Per-niche
  *adaptation* and grindy per-node *mastery* are Horizon; this is the minimal skill spine, not
  the ability-tree.)
- **✓ Done (2026-06-16) — The chase lands early.** First gene guaranteed + emphatic ("First
  mutation!") within the first minute; one-time onboarding, not pity. Cures "maxed upgrades,
  never saw a gene."
- **✓ Done (2026-06-16) — Niches with teeth.** Power = access, the niche's signature stat =
  throughput (steep, never a penalty, VISION §11); genes feed attributes; the affix-key gate is
  live. **The Open Water** un-parked (signature metabolism, key sustain) as the contrast. Cures
  "branches don't feel different." (Reef signature still OPEN — instinct double-dips the chase.)
- **Selection as a draft against a budget.** Surfaced mutations are *drafted* (à la Slay the
  Spire / Loop Hero / Niche), bounded by **expression** (§7 slot limit) *and* **metabolic
  upkeep** (Thrive, the draft budget) — you *can't keep all*. **Chromosomes = multi-affix
  genes slotted PoE-jewel-style**, so the chase is for the gene that *completes a combo*
  (Diablo sets), not the rarest. *Open: at what level/timing drafting enters — a feel call
  made live during the rebuild.*
- **Splice = rare, targeted, distinct from mutation** — likely signature genes become
  splice-only (its own session). *Economy change → re-prove.*
- **The active verb — Axis 1 (optimize the loop)** *(last in Next)*. Set up each lineage's
  activity loop + tune the doll/genome build against a budget; it auto-runs at the idle floor
  (Increlution-style). Now there is a loop — progression, teeth, a chase, a selection budget —
  *to* optimize. Cures "nothing to *do* but time-skip." **Axis 2 (light combat-babysit) ships
  with combat depth (Horizon) — it needs the auto-battler and must never precede it.**

## Horizon — the spine's bigger systems (sequence carefully, never big-bang)

Co-dependent. Each ships as its own sub-game.

- **Skills → ability/skill-tree → active combat abilities** (the identity carrier, in this
  order). Skills first (in Next). The ability-tree starts with **passive** abilities and a
  few *simple* actives (build uniqueness; convergence is trait-motifs, not clones). **Active
  abilities require combat depth** (below) to matter — sequence them together, never before.
- **Combat depth — a light auto-battler** (Iktah / Melvor shape, decided): idle auto-resolve
  + active food/heal/buff/ability + a pre-fight loadout — *not* a real-time rotation. May
  read as a *second core loop* (the skilling/combat split of Melvor & IdleOn). The payoff
  surface for active abilities and the home of Axis-2 active play.
- **Per-niche adaptation, then grindy per-node mastery.** Adaptation biases which mutations
  surface ("becomes what it grinds"); much later, deep per-node mastery with high tiers that
  take forever (IdleOn / Idle-Obelisk card-tier style) is the committed-player late grind
  (quick early → medium mid → very grindy late, by design — an opt-in ceiling, never a floor).
- **The ecosystem loop — the marquee.** Chain lineages into a web where each has a role (the
  revived ecosystem idea). **It is a graph of *buffs*, synergy always upside — never a
  required supply chain that could starve a lineage** (VISION §8/§13; a hard nutrient-loop
  stays far-horizon, if ever). Mechanically the **scaled-up Axis-1 verb** — optimize one
  lineage's loop → optimize the web — so it accretes from the core, not a new engine.
- **The production web, deepened** — material diversity, processing chains, division of
  labour (the minimal raw→refined→adaptation chain ships in the slice; diversity is here).
- **Internal open-math economy substrate** — surplus, specialization, optimization, shown
  openly (theorycraft a feature). Single-player; the rehearsal for trading.
- **Ages II+** — land-fall and beyond; the unfold cadence (drip-fed unlocks à la Iktah) that
  carries long-term retention without prestige.
- **Living meta / coevolution** — the Devs shift the meta as *opportunity* (move forward for
  new materials), never as loss; old builds still hold in old content.
- **Expanded role taxonomy** — predator / herbivore / scavenger / ambush / … entering by the
  entry rule as ages allow.

## Far horizon — the passion (only once the game carries itself)

- **Social / economy / community** — trading, comparison, theorycraft surfaces, guides;
  eventually **multiplayer / PvP**. The creator's deepest want and the biggest retention
  multiplier; opened on top of the internal economy substrate.
- **Kingdoms** — plants / fungi / microbes; the home of the resource-provider, mutualist,
  architect, and keystone roles that animals-only cannot host.
- **History-overgrows-the-world** — graduated lineages populate the wild (VISION §19).

---

## Resolved & open design sessions

Each its own session (CLAUDE.md §4: propose → sign → canonize). Full framings in
`DECISIONS.md` → Design-session backlog.

- **Building-blocks brainstorm — RESOLVED 2026-06-14.** Produced the reset-to-spine
  decision, the §12 active-as-core reframe, the two-axis active model, selection-as-draft-
  against-budget + chromosomes, and the ecosystem-loop-as-buffs marquee. See DECISIONS.md
  (2026-06-14) and Now/Next/Horizon above.
- **Still open** (ordered by the horizons above): the **ability-tree shape** · **combat
  depth** (the light auto-battler) · **living-meta / coevolution** · **splice-vs-drop
  economy** (likely splice-only signature genes).
