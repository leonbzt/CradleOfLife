# NEXT_SESSION.md — Start here

> **Temporary resume aid.** A seamless pickup point between sessions. Delete/replace
> once the next design session produces a signed direction. Not canonical — if it
> disagrees with VISION/IMPLEMENTATION/DECISIONS, those win.

## Where we are (2026-06-13)

- **Phase 3 — done & validated** (committed). Class tree, Option A slots,
  cladogenesis, soft cap, 2-lineage roster.
- **Phase 3.5 — in progress.** Thesis: *the check-in becomes a session you play.*
  - **WP1 ✅** session loop — offline accrual applied on launch/resume + the
    while-you-were-away **Dev dispatch** (lead with the rare drop, tally the rest).
  - **WP2 ✅** the **do-now agenda** — derived "what's worth a tap" panel.
  - **WP3 ✅** metabolize-as-choice — each slot reads "what this organ becomes";
    ≥2 generalist options per essential slot, each feeding a real attribute via the
    new organ-declared `feeds` field (Leon signed the small Option A engine tweak).
  - **WP4 ✅** visible combat (World-tab **clash panel** from the resolve() math —
    pen cracking armour, danger tax, splice window) + the **splice catalogue**
    (signature gene · copies · express tier · reach) + rare+ loot beats.
  - **WP5 ✅** tab IA — persistent roster+header over Home / Body / World / Class.
  - **WP7** harness ✅ re-proven (curve byte-identical to pre-WP3). **Pending:**
    WP6 map-unlock achievements (not built — out of this session's ask) and the
    **WP7 playtest gate** (web export to cohort). Full spec: `PHASE3_5.md`.
- **Gate 2/3 sign-off owed (Leon):** the 5 new generalist adaptations' flavor +
  the new `bible/refs/shallow-benthos.md` rationale sections (science), and all new
  UI strings (voice). The Storage Cecum → resilience claim is the most interpretive.
- **UI is now split per tab:** `ui/main.gd` is a 455-line shell; tabs live in
  `ui/tabs/*.gd` over shared `ui_util` / `ui_state` / `express_sheet`. Whole UI is
  gdlint-clean.
- Playtest feedback that drove 3.5: *"fun, but not a lot to do concretely; mainly
  waiting with very short check-ins."* Eyeball the build with a web export (the DEV
  **⏩ +8h** button raises the dispatch; the new tabs + clash + catalogue are live).

## To resume any session

Read `CLAUDE.md`, then the relevant part of `VISION.md` (always "What's locked"),
the current phase in `IMPLEMENTATION.md`, and the tail of `DECISIONS.md` (incl. the
**Design-session backlog** in its Open-questions section). Then this file.

---

## Recommended next design session — **Build identity & the activity-optimal build**

**Why this one first.** (1) It unblocks the very next build WP — WP3
(metabolize-as-choice) should build the *right* options, not placeholders, and
those options are exactly what this session decides. (2) Leon explicitly wants it
("best-in-slot for a situation… spec a build to be optimal for a specific activity,
so branches earn their purpose"). (3) It's foundational: skills, the active layer,
and the living meta all need to know *what a build optimizes toward* — settle this
first and those bigger sessions get much sharper.

**The core question.** *What makes one lineage's build meaningfully different from
another's, and where is each one uniquely good?* Today divergence is mostly stat
flavour (predator vs filter-feeder) + a gentle `niche_mult` home buff. Leon wants
stronger: places/activities where you're efficient **only** with the right build.

**Already in place to build on:**
- The doll + Option A slot→attribute routing (VISION §7).
- Affix-keys gate niche *access* and pay specialization bonuses (§11).
- `Resolve.niche_mult` — a class's at-home material/gene buff (currently ×1.2).
- Classes unlock exclusive gear categories (raptorial / heavy_armor /
  filter_apparatus); monotonic-safe, sticky.

**Open questions to resolve in the session:**
1. How strong should "right build for the place" be? `niche_mult` is a soft buff
   today — do we want harder build-gated efficiency (a wall, not just a bonus)
   without crossing into trap-builds (§11) or loss-aversion (§12)?
2. Is the axis *niche* (where you grind), *activity* (eat vs fight vs farm), or
   *target* (which creature)? Or a mix? This decides what WP3's metabolize options
   optimize toward.
3. What are the 2–3 generalist metabolize options **per essential slot** (WP3),
   and what trade-off does each express? (This is the concrete output WP3 needs.)
4. How does this make a **2-lineage roster** feel like a portfolio with different
   *rhythms* (the Phase-3 gate question), not two of the same?
5. Does it touch the soft cap / breadth-led growth shape (§14)? (Probably not —
   confirm.)

**Constraints (the reality check, CLAUDE.md §3):** no trap builds, synergies
celebrated (§11); idle earns / attention spends, no loss-aversion (§12); depth from
a *small* set of orthogonal primitives, not authored volume (§17); expressible as
data + the one `resolve()` — new engine surface must be justified and signed (§4).

**Desired output:** a signed design direction (DECISIONS.md entry) + the concrete
WP3 metabolize-option content spec, ready to implement. Possibly a small
`niche_mult`/affix-key tuning note for the harness to re-prove.

---

## The rest of the backlog (Leon drives the order)

Full framings live in `DECISIONS.md` → Open questions → **Design-session backlog**.

1. **Build identity & activity-optimal build** — *recommended next* (above);
   unblocks WP3.
2. **Splice catalogue & splice-vs-drop** — resolves Leon's "what's the difference?"
   (drops = random mutation lottery; splice = targeted trait theft; likely fix:
   signature genes become splice-only). Feeds WP4. Small, contained — could pair
   with session 1.
3. **Skills + the active / "babysit" layer** — the marquee. Leon's strongest want
   (engagement-optional active play that improves progress, OSRS/IdleOn-style);
   active skills are a likely carrier. **Touches the §12 red line** — design
   deliberately so it never becomes "log in or lose." Sharper after #1.
4. **Living meta / coevolution** — the biggest differentiator and most on-theme
   (Devs patch the meta). Start small, expand. Strategic; not blocking.
5. **Combat depth** — beyond WP4's visible clash: abilities / active-resolve.
   Overlaps the deferred Fight-encounter layer (VISION §19). Latest.
