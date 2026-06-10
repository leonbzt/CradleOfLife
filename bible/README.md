# The Bible — content ground truth

This directory is the single source of truth the three content gates check
against (VISION.md §17, IMPLEMENTATION.md §3). Every authored content row — affix,
adaptation, gene, node, patch note — must clear all three before it enters the
build:

1. **Orthogonality (automated, CI).** Each affix declares an `orthogonal_role`
   and the `math_term` it modifies; `sim/validation.gd` rejects rows that miss
   them or that duplicate another affix's `math_term` with identical `params`.
   *This gate is code; it runs on every push.*
2. **Scientific accuracy (human, sourced).** Any row asserting a real biological
   capability carries a `source` pointing into `refs/`. A human verifies the
   claim against a primary source before merge. **AI is strong at flavour and
   unreliable at facts** — so the `refs/` notes here are *rationale to be
   verified*, never a substitute for the human check.
3. **Voice & world coherence (human, against the bible).** The row reads in the
   register described in `voice.md` and fits the world in `world_spine.md`.

## Layout

| File | Owns |
|---|---|
| `world_spine.md` | The ages and niches — the skeleton content hangs on. |
| `voice.md` | The narrator's voice: do/don't, example patch notes & blurbs. |
| `refs/` | Per-niche scientific references the accuracy gate checks against. |

## How `source` fields work

A content row's `source` is a path + anchor into this directory, e.g.
`bible/refs/shallow-benthos.md#cnidarian-nematocysts`. The anchor must resolve to
a real heading. If you add a capability, add (and source) the heading first.
