# The World Spine

The skeleton of the world: the ages (expansions, in the Devs' parlance) and the
niches inside them. This is real deep-time Earth rendered as a saga (VISION.md §2,
§15). It grows one age at a time, forever. **v1 builds Age I only.**

---

## Age I: The Sea

> *Patch 1.0 — Launch. The water's warm, the light reaches the floor, and
> something down there just learned to bite. Welcome to the only server that's
> ever mattered.*

The launch age. Sunlit, shallow marine. This is where the core loop is proven
(IMPLEMENTATION.md vertical slice): animals only, one kingdom's worth of game
built well before any other is promised.

### Niches

| Niche | id | What it is | Status |
|---|---|---|---|
| The Shallow Benthos | `shallow_benthos` | Sunlit sea floor: microbial mats, slow grazers, and the first predators. | **v1** |
| The Open Water | `pelagic` | The column above the floor — fast, exposed, nowhere to hide. | future |
| The Reef Edge | `reef_edge` | Structure and shelter; ambush country. | future |

The Shallow Benthos is the **starter niche** and the only one authored in v1. A
fresh lineage grazes the microbial mats (a passive Eat node it can already beat),
then gears up to take on things that hit back — the anemone, the trilobite — and
eventually the apex of the launch meta.

### The apex of the launch meta

**Anomalocaris** holds the pinnacle drop of Age I (the Great Appendage). It is a
real radiodont and the genuine apex predator of this world — statted accurately,
gated hard. It is the top of the chase ceiling until Age II raises it.

---

## The climb (named, not built)

Ages are expansions, not resets — no wipe, ever (VISION.md §15). The roadmap *is*
the fiction: each age ships as a Dev expansion patch.

- **Age II — onward in the sea.** Open water, reefs, the first arms races scaling
  up. Raises the chase ceiling.
- **The first summit — Land-fall.** *"Patch: Terrestrial Access is live. No build
  has ever stood here. Good luck."* The make-or-break beat (VISION.md §15);
  over-build it when it comes.
- **Beyond.** Land and onward, indefinitely.

None of this is built in v1. It is named here so the world stays whole and so Age
I's content is authored knowing what it hangs on.
