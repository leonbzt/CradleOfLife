# Reef Edge — Science References

Science ground truth for Age I reef-edge content. Every mechanic asserted in the
reef-edge niche must trace to a section here (gate 2). Invented creatures
(`reef_lurker`) are marked and assert only well-established strategies.

---

## the-reef-edge

**Claim:** Cambrian reef structures existed and provided structural complexity
that supported distinct ecological roles from the open benthos — including shelter
for ambush predators and substrate for filter feeders.

**Basis:** Rowland & Shapiro (2002, *Paleobiology* 28:S86–S93): archaeocyathids
built carbonate mound structures in Early Cambrian shallow seas that functioned
as reef-like habitats. These structures created microhabitats with shelter and
prey concentration.

**Game mechanic:** Reef-edge niche requires a `stealth` affix key — reflecting
that ambush ecology dominates structured reef habitat. Enter without crypsis,
and prey sees you first.

---

## archaeocyathids

**Claim:** Archaeocyathids were early Cambrian sessile filter-feeding organisms
that secreted calcite skeletons, forming the first carbonate reefs. They yielded
`calcite_lattice` material (unmineralized sponges yield soft tissue; archaeocyathids
yield calcite).

**Basis:** Debrenne et al. (2011, *Treatise on Invertebrate Paleontology* Part E,
Vol. 4): archaeocyathids had porous calcite walls and were the principal reef
constructors of the Early Cambrian. They are not sponges but share a sessile,
filter-feeding lifestyle.

**Game mechanic:** `archaeocyathid_grove` eat node (defense 3 — calcite resists
casual grazing), drops `calcite_lattice` (uncommon).

---

## spiny-armor

**Claim:** Wiwaxia corrugata bore rows of unmineralized sclerites (scale-like
structures) and dorsal spines as anti-predator defense. Its sclerites were
organic (not mineralized), so they yield chitin, not calcite.

**Basis:** Butterfield (1990, *Paleontology* 33:1–22): Wiwaxia is a lophotrochozoan
with unmineralized sclerotized (chitin-like) armor. Conway Morris (1985) describes
the sclerite morphology in detail from Burgess Shale material.

**Game mechanic:** `wiwaxia` yields chitin (not calcite). `spine_rows` affix
(`danger_guard`, amount 3) — spines as a danger-tax guard. The sclerite rows
are redirected outward: accurate to the defensive anti-predator function.

---

## proboscis

**Claim:** Ottoia prolifica was a priapulid worm with an eversible proboscis
(an inside-out throat) it used to ambush and engulf prey from the sediment.

**Basis:** Conway Morris (1977, *Philosophical Transactions of the Royal Society*
B 279:579–609): Ottoia's proboscis bears hooked sclerites and was used in active
predation, with gut contents showing swallowed brachiopods and other organisms.
The eversible mechanism is documented.

**Game mechanic:** `eversible_proboscis` affix (`splice_mult`, mult 2.0) — the
proboscis as a "pinning" tool extending the splice window. Ottoia ambushes from
sediment; the splice-rate bonus represents holding prey long enough to sample
its genome. Asserted capability (eversible proboscis, ambush predation) is real.

---

## ambush-lurking

**Claim:** Ambush predation using structural cover is a well-established reef
ecology strategy. `reef_lurker` is an invented creature asserting only this
strategy. The ambush frac 0.4 affix represents a higher exploitation of the
ambush window than transparency alone.

**Basis:** Broadly supported across modern reef ecology (Randall 1967;
Hobson 1974). For Cambrian specifically: Briggs et al. (1994, *The Fossils of
the Burgess Shale*) document diverse predatory strategies including ambush in
Cambrian communities. Structured reef habitat in any era concentrates prey
and provides cover — the behavioral strategy requires no specific anatomy claim.

**Game mechanic:** `ambush_instinct` affix (`ambush_frac`, frac 0.4) — the
reef lurker's stillness as a higher gate-open fraction than pelagic transparency.
`reef_lurker` is clearly stylized (invented); no specific biology claimed beyond
"ambush predator using structural cover."
