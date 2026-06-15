# CLAUDE.md — How we build Cradle of Life

**Read this first, every session.** It governs *how* we work. It outranks your own recollection, prior chats, and any assumption. When in doubt, this file and the canonical docs win over memory.

This is an idle RPG about evolution, built by a small indie team with heavy AI assistance, for long-term live operation. The goal of this file is simple: keep the project **clean, current, honest, and actually fun** — without the human having to babysit stale context, re-explain decisions, or fight old ideas that overstayed their welcome.

---

## 1. The document hierarchy — the single source of truth

There are exactly these canonical documents. Each *owns* a domain. If a fact about the project isn't in the doc that owns it, it isn't decided yet — so decide it (with the human) and write it down, rather than letting it live only in chat.

| Doc | Owns | Authority |
|---|---|---|
| **CLAUDE.md** (this file) | *How* we work — process, principles, protocols | Governs every session |
| **VISION.md** | *What* the game is — design, the locked structure, the open dials | The design source of truth |
| **IMPLEMENTATION.md** | *How and when* we build — architecture, phases, validation gates | The current plan/roadmap |
| **bible/** | Content ground truth — the world spine, the voice, per-niche science references | What the three content gates check against |
| **DECISIONS.md** | *Why* things changed — append-only, dated log | The **only** place history lives |
| **the code** | The implementation | Must always match the docs; any mismatch is a bug |

**The rules that make this work:**

- **The docs are the memory.** At session start, re-read the relevant docs and treat them as truth. Do **not** rely on what you "remember" from earlier in this chat or from past sessions. If your memory conflicts with a doc, the doc wins and you flag the conflict.
- **One canonical file per purpose.** Never create `VISION_v2.md`, `VISION_final.md`, `VISION_REAL_final.md`, or parallel copies. Edit the canonical file in place.
- **Living docs hold only the current truth.** No inline version history, no "(old idea, deprecated)" clutter, no struck-through paragraphs left lying around. When something is superseded, **delete it from the doc** and record the change in DECISIONS.md.
- **DECISIONS.md is the one history.** Append a dated entry whenever a design or plan decision changes: *what changed, why, what it replaced.* This is so the human never has to reconstruct "why did we do X?" from chat logs — and so the working docs never accumulate sediment.
- **Docs and code never drift.** If a change alters a design decision or the plan, update the owning doc **in the same session** as the code. A doc that lies about the code is worse than no doc.

### 1a. Regenerating a canonical doc (grounding & guardrails)

When a doc has drifted so far that patching won't fix it — the reframes outran the prose and it reads as "old version with patches" — re-draft it **ground-up**. But old text is *gravity*: AI (and humans) will preserve overthrown framing unless explicitly directed not to. The method that prevents both hallucination and re-locking onto dead concepts:

- **Ground in DECISIONS.md + ROADMAP.md + the live session — not the old doc.** Regenerate *from* the dated, signed history. Treat the doc being rewritten as **suspect (possibly stale), never the template**; mine it only for concepts on the keep-list.
- **Write two explicit lists first.** A **kill-list** of overthrown concepts that must not reappear (read them off the "replaced / supersedes" clauses in DECISIONS), and a **keep-list** of locked concepts that must survive (this guards against over-correcting the good parts away).
- **Cite-source or flag.** Every substantive claim traces to a DECISIONS/ROADMAP source, or is marked `[NEW — needs sign-off]`. No silent invention; the human signs the NEW flags.
- **Fresh draft, not edit-in-place.** Write a new draft file (e.g. `VISION_DRAFT.md`), diff it against the old, get section-by-section sign-off, then replace the canonical file and delete the draft (one canonical file per purpose). Record the rewrite in DECISIONS.

---

## 2. How we work — core principles

1. **Ask, don't assume.** Make few assumptions. For anything touching design, taste, vision, architecture, or anything hard to reverse — **stop and ask** before building. For small, reversible, mechanical choices, proceed but **state the assumption inline** so it can be corrected. Never silently decide something the human would want a say in.

2. **Small, reviewable steps.** One concern per change. Show the plan or the diff and get a nod before sprawling. The human should never open the editor to a surprise.

3. **Honesty over agreeableness.** You are a critical collaborator, not a cheerleader. If an idea — including the human's, including something already in VISION.md, including something you proposed yesterday — looks like it won't work, **say so plainly and make the case.** Do not pad, do not flatter, do not pretend uncertainty is confidence. A blunt "I don't think this works, here's why" is the most valuable thing you can offer.

4. **Test with the feature, not after.** The economy is the riskiest system; it must stay deterministic and headless-testable (seeded RNG, sim out of the scene tree). Write or update the test alongside the change. "It compiles" is not "it works."

5. **Respect the architecture invariants** (full detail in IMPLEMENTATION.md): the simulation stays out of the scene tree; there is one `resolve()` function for Eat and Fight; content is data, the engine is small and hand-written; offline accrual is closed-form, never frame-ticked; AI authors data rows, never the engine.

6. **Build only the current phase.** Do not build scaffolding, hooks, or "future-proof" abstractions for deferred features (see VISION.md §19). YAGNI. The deferred list is a promise to *not* build yet.

7. **Clean as you go.** No dead code, no orphaned files, no commented-out experiments left in place, no superseded concepts left in docs. If you replace something, remove what it replaced.

---

## 3. The reality check — "does this actually work in a game like *this*?"

Before building any new mechanic, system, or content type, run this check out loud and get agreement. Passing "it's a plausible idea" is not enough; this is a game with specific, fragile load-bearing systems.

- **Which pillar does it serve — idle, RPG, or growth?** If none, why are we building it?
- **Does it keep the chase alive?** The chase curve is the entire long-game pull (VISION.md §5, §9a). Anything that flattens "interesting events per check-in" is a threat, not a feature.
- **Is it idle-earns / attention-spends compatible?** Does it sneak in loss-aversion, babysitting, or a "log in or lose progress" pressure? Those are banned (VISION.md §12).
- **Does it fight the content moat?** Does it add authored-volume burden instead of multiplying a small set of orthogonal primitives (VISION.md §17)?
- **Can it be expressed as data + the one resolve function?** Or does it demand new engine surface? New engine surface is expensive and must be justified.
- **Is it true?** If it asserts a biological capability, does it pass the scientific-accuracy gate with a real source (VISION.md §2, gate 2)?
- **How will we *know* it works — cheaply?** Model it in the headless economy harness, prototype the smallest version, or put it in front of the playtest cohort. Plausibility is not evidence.
- **Honest verdict:** Would you bet this makes the game better? If you're unsure, say "unsure" and propose the cheapest experiment to find out. Do not manufacture confidence.

If a built feature later fails its playtest/validation gate, say so and propose cutting or reworking it. Sunk cost is not a reason to keep something that isn't working.

---

## 4. Nothing is permanently locked — the change protocol

VISION.md has a "What's locked" section. **"Locked" means "stable default that we don't churn casually" — it does not mean "immutable."** This game will change a lot during development as different ideas prove better in practice. Early ideas must never become blockers. Both of these are true at once:

- **The human's vision and taste are important** and are the tie-breaker on anything subjective.
- **The human's vision and taste can change**, and good development *should* change them when reality teaches us something.

So the protocol is:

1. **When you believe a locked/default idea is wrong or beaten by an alternative — raise it.** Proactively. Do not silently comply with a doc you think is mistaken, and do not silently override it either. Surface the tension, make the strongest case for the change (and the strongest case against), and propose a concrete alternative.
2. **The human decides.** Vision/taste/design changes require their explicit sign-off. You propose; they dispose. Never assume approval, never treat your own preference as the decision.
3. **On approval, canonize it immediately.** Update the owning doc in place, **delete the superseded concept** (don't leave it haunting the doc), and add a DECISIONS.md entry: what changed, why, what it replaced. The change is now the new default — no asterisks, no "but the old way was…".
4. **On rejection, drop it cleanly.** Record nothing in the doc; the default stands. Don't re-litigate the same point repeatedly unless new evidence appears.

The point: your early decisions are a *starting position*, not a cage. The mechanism that keeps the human in control is the **ask** — not the lock.

---

## 5. Session protocols

**Start of a work session:**
1. Re-read this file and the relevant part of VISION.md (always the "What's locked" + the section you're touching) and IMPLEMENTATION.md (the current phase + its validation gate). Check the tail of DECISIONS.md for recent changes.
2. State, in one or two sentences, what you understand the current task and phase to be, and any assumption you're making. **Confirm before building.**

**During work:**
- Keep changes small and the tests green. Flag any place where the code and docs have drifted, or where a doc has accumulated cruft, the moment you notice it.

**End of a work session (or any decision-bearing change):**
1. If a design or plan decision changed: update the owning doc in place + append a DECISIONS.md entry. If nothing design-level changed, touch no docs.
2. Ensure the code matches the docs and the tests pass.
3. Note any open questions or unresolved tensions for next time — in the doc or DECISIONS.md, not only in chat.

---

## 5a. The Work Order Protocol — how an AI builds an increment without drift

Every build increment (a ROADMAP "Next" piece, an age, any multi-step change) runs as a **work order**: a temporary `WORKORDER_<name>.md`, signed before code, deleted on close with its decisions moved to DECISIONS.md. This names and hardens the pattern PHASE2 / PHASE3 / WORKORDER_RESET already used. Its purpose is narrow and important: let AI implement a lot, across many iterations, **without hallucinating or drifting back into overthrown concepts** — while you still steer mid-build. Copy `WORKORDER_TEMPLATE.md` to start one.

1. **Ground it before you write it (kills hallucination).** The work order opens with a **grounding contract**: cite the VISION §§, the ROADMAP item, and the DECISIONS entries it derives from, and **list the exact code symbols/files it will touch, verified by reading them.** Never "I think there's an X" — open the file. Every substantive claim traces to a doc or the code, or is tagged `[NEW — needs sign-off]` and you sign it (the §1a rule, applied to building).

2. **Write a keep-list and a kill-list (kills drift — the load-bearing guard).** Old prose and **parked code are gravity**; AI re-locks onto overthrown framing unless explicitly told not to (§1a). So each order names, up front: a **keep-list** (locked concepts that must survive — from VISION "What's locked") and a **kill-list** (parked/overthrown concepts that must not reappear — e.g. the class tree, `niche_mult`, loot-as-gear, "active out-earns idle," a new affix role). The standing rule **"build from the vision, not the parked code"** goes in every order — `prototype-v3.5` is one checkout away and is the most dangerous gravity in the repo.

3. **The oracles, not opinions (so heavy iteration can't rot the economy).** "It compiles" and "it looks right" are not evidence. Truth is: the **harness** re-proves §9a on every economy change; the **three gates** clear every content row; **headless sim tests** ship with the change. These don't tire over fifty iterations the way review does.

4. **Build in small WPs with feedback at the seams (your steering, without derailment).** Sequence: **design-sign** (no code) → build one WP (one concern) → show the diff + the harness/test result → you react → next WP. The anti-derail rule: **feedback that changes design goes back through design-sign and updates the work order's design section** (the doc never lies about the build); a feedback *tweak* applies inline. You never open the editor to a surprise (§2).

5. **Canonize on close (so the next session starts clean).** When the gate passes: update the owning docs in place, **delete the superseded concept**, append the DECISIONS entry (what changed, why, what it replaced), refresh SPINE.md to match the new code, and **delete the work-order file**. History lives in DECISIONS + git, never in a parallel doc.

**The three altitudes this anchors.** ROADMAP = the long-term living plan (re-ordered as we learn). The work order = the signed short-term increment. The WP = the step. Each altitude grounds in the one above **plus the code** — which is how the same plan governs both the next commit and the multi-year roadmap.

---

## 6. Testing & validation (specifics in IMPLEMENTATION.md)

- **Headless economy tests** for `resolve()` / `accrue()`, deterministic via seeded RNG, run in CI on every push. The 6-week chase-curve model (Phase 0) is the most important test in the project — re-run it whenever economy constants change and confirm the curve still never flattens.
- **The three content gates** run on every content change: (1) orthogonality (automated, CI), (2) scientific accuracy (human, sourced), (3) voice & world coherence (against bible/). No row enters the build until it passes all three.
- **Playtest gates** end each phase. A phase is not "done" because the feature exists; it's done when its validation question (IMPLEMENTATION.md §4) is a clear yes from real testers — or you've reported honestly that it isn't.

---

## 7. Red lines — never silently break these

These are the systems most likely to be quietly eroded by a "small" change. Touching any of them requires an explicit flag and, where it's a vision change, the §4 protocol:

- The **chase curve never goes flat** (VISION.md §5, §9a).
- **Idle earns, attention spends** — no loss-aversion, no babysitting, no "log in or lose" (VISION.md §12).
- **No dark patterns, no pay-to-win** — the ethical monetization stance is positioning, not a placeholder (VISION.md §18).
- **AI authors data, never the engine**; everything passes the three gates (VISION.md §17).
- **Scientific accuracy** of any asserted real capability (VISION.md §2).

When uncertain whether something crosses a red line: **stop and ask.** That is always the correct call.
