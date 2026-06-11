# The World Spine

The skeleton of the world: the ages (expansions, in the Devs' parlance) and the
niches inside them. This is real deep-time Earth rendered as a saga (VISION.md §2,
§15). It grows one age at a time, forever. **v1 builds Age I only.**

## Two rules that govern every age

**Chronology (decided 2026-06-10, VISION.md §20.12).** Real-named creatures
appear in their real eras — no modern anglerfish in the Cambrian. But the fossil
record is incomplete and most lineages died unrecorded, so **invented, clearly
stylized creatures may fill gaps**, as long as they contradict no known biology
(an invented luminescent ambusher in an early deep niche is fine; gate 2 still
checks every capability it asserts).

**World events never wipe (decided 2026-06-10).** A mass extinction is a Dev
world-event — a server-wide nerf that reshapes the meta — never a reset of the
player's Tree (VISION.md §14: no prestige wipe, ever). In v1 these are flavor
and content gates; real-stakes events are deferred depth (VISION.md §19).

---

## Age I: The Sea

> *Patch 1.0 — Launch. The water's warm, the light reaches the floor, and
> something down there just learned to bite. Welcome to the only server that's
> ever mattered.*

The launch age. Sunlit, shallow marine. This is where the core loop is proven
(IMPLEMENTATION.md vertical slice): animals only, one kingdom's worth of game
built well before any other is promised.

### Niches

| Niche | id | What it is | Key | Status |
|---|---|---|---|---|
| The Shallow Benthos | `shallow_benthos` | Sunlit sea floor: microbial mats, slow grazers, and the first predators. | none | **v1** |
| The Open Water | `pelagic` | The column above the floor — fast, exposed, nowhere to hide. | `uptime` | **v1** |
| The Reef Edge | `reef_edge` | Structure and shelter; ambush country. | `stealth` | **v1** |

The Shallow Benthos is the **starter niche**; The Open Water and The Reef Edge
are Phase 2 niches gated by affix-key builds. A fresh lineage grazes the microbial
mats, gears up, and eventually progresses to the new niches once the right affix
build is in place.

### The apex of the launch meta

**Anomalocaris** holds the pinnacle drop of Age I (the Great Appendage). It is a
real radiodont and the genuine apex predator of this world — statted accurately,
gated hard. It is the top of the chase ceiling until Age II raises it.

### Archetypes (the sea-age role spread)

The real-biology roles a sea roster draws from (VISION.md §13: within animals
there is already a full role spread). Authored creatures should map onto these.

| Archetype | Gamer read | Role | v1? |
|---|---|---|---|
| **Apex Predator** | Burst DPS carry, high upkeep | offense | yes |
| **Generalist / Mesopredator** | Flex pick, the Generalist class root | adaptable | yes |
| **Armored Grazer** | The tank / bruiser, eats everything safely | mitigation | yes |
| **Filter Feeder** | The efficient passive farmer; great idle uptime | support/uptime | yes |
| Ecosystem Engineer | Reshapes the biome | utility | defer (world-reshaping) |
| Eusocial Colony | Unit-spawning swarm economy | — | defer (second-engine risk) |

### Signature creatures (Sea age — science-honest)

The starter roster pool: role-diverse, chronologically coherent for a Cambrian →
early-Paleozoic sea. Post-Cambrian entries wait for later sea patches (the
chronology rule above).

| Creature | Clade / era | Class one-liner | Role | Splice candidate |
|---|---|---|---|---|
| **Anomalocaris** | Radiodont, Cambrian | S-tier apex burst carry | offense | Grasping Strike |
| **Trilobite** | Arthropod, Cambrian+ | The everyman tank; armored, never gets nerfed | mitigation | Mineralized Carapace |
| **Orthocone nautiloid** (e.g. Cameroceras) | Cephalopod, Ordovician | Jet-propelled ranged apex; the kraken of its day | offense/mobility | Jet Dash |
| **Eurypterid** (sea scorpion) | Chelicerate, Ordovician–Silurian | Heavy bruiser duelist | offense/control | Pincer Grip |
| **Haikouichthys / Pikaia** | Early chordate, Cambrian | F-tier underdog that inherits the server | utility/scaling | Notochord |
| **Tamisiocaris** | Filter-feeding radiodont, Cambrian | AFK farmer; turns plankton into pure uptime | support/uptime | Filter Combs |

### Trait → affix-role map (gate-1 ground truth)

Where sea-age traits land in the orthogonal role set (VISION.md §17; enforced by
`sim/validation.gd`). Decided 2026-06-10: **aposematism is mitigation-flavor**
(deterrence reduces incoming pressure; no 7th-role-by-accident), and
**mimicry/crypsis is the `stealth` role** — a real term of its own.

- Neurotoxin / venom → `dot`
- Crushing bite / shell-cracker → `penetration`
- Mineralized carapace, **aposematism** → `mitigation`
- Abyssal torpor (cold, paralytic) → `control`
- Filter-feeding efficiency → `uptime`
- Acute lateral line, compound eyes → `find`
- **Mimicry / crypsis** → `stealth`

---

## The climb (named, not built)

Ages are expansions, not resets — no wipe, ever (VISION.md §15). The roadmap *is*
the fiction: each age ships as a Dev expansion patch.

- **Age II — onward in the sea.** Open water, reefs, the first arms races scaling
  up. Raises the chase ceiling. Candidates: the Ordovician–Silurian roster above
  (orthocones, eurypterids); a reef niche (mantis/pistol shrimp are modern —
  stylized stand-ins only, per the chronology rule); a deep/abyss niche (an
  invented luminescent lure-ambusher beats a literal modern anglerfish).
- **The first summit — Land-fall.** *"Patch: Terrestrial Access is live. No build
  has ever stood here. Good luck."* The make-or-break beat (VISION.md §15);
  over-build it when it comes.
- **Beyond.** Land and onward, indefinitely. Parked creature ideas: honey badger
  (berserker), archerfish (skill-shot), parasitoid wasp (summoner/debuffer);
  slime mold waits on a protist kingdom, if ever. Parked systems stay in
  VISION.md §19's deferred list (metamorphosis, symbiosis companions, eusocial
  swarms — the last flagged as second-engine risk).

None of this is built in v1. It is named here so the world stays whole and so Age
I's content is authored knowing what it hangs on.
