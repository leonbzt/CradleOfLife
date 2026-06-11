# Pelagic (Open Water) — Science References

Science ground truth for Age I pelagic content. Every mechanic asserted in the
pelagic niche must trace to a section here (gate 2). Invented creatures
(`glass_drifter`) are marked and assert only well-established strategies, not
named species traits.

---

## the-open-water

**Claim:** The pelagic zone is the open water column — fast, exposed, energetically
demanding; sustained swimming requires high respiratory throughput (gill capacity).

**Basis:** The pelagic environment imposes high metabolic costs for sustained
locomotion versus benthic life (Schmidt-Nielsen 1972, *How Animals Work*; Videler
1993, *Fish Swimming*). Cambrian-era animals capable of mid-water locomotion
include Cambrian radiodonts such as Tamisiocaris (Vinther et al., 2014).

**Game mechanic:** Pelagic niche requires a `sustain` affix key (gill capacity)
to enter — representing the sustained aerobic throughput needed for open-water life.

---

## plankton-productivity

**Claim:** Phytoplankton blooms are a high-throughput, low-resistance food source
in open water.

**Basis:** Cambrian and pre-Cambrian oceans had photosynthetic plankton (acritarchs,
cyanobacteria); the radiation of filter feeders like Tamisiocaris is direct evidence
of plankton bloom abundance (Vinther et al., 2014, *Nature* 507:496–499).

**Game mechanic:** `plankton_bloom` is an eat node (no retaliation) with the
highest material rate in the pelagic niche.

---

## notochord

**Claim:** Haikouichthys had a notochord — a stiff cartilaginous rod providing
axial support — which is the defining feature of the chordate phylum and a precursor
to the vertebrate spine.

**Basis:** Shu et al. (1999, *Nature* 402:42–46) describe Haikouichthys ercaicunensis
from the Chengjiang Cambrian Lagerstätte as among the earliest known chordates,
with preserved notochord structures. Conway Morris & Caron (2012, *Nature* 512:419–422)
confirm placement.

**Game mechanic:** Notochord → `notochord_flick` affix (`danger_guard`, amount 1).
The notochord as a shock-absorbing rod reducing effective danger tax. Flavor:
"the lineage that inherits the server" — accurate (Haikouichthys is an early chordate
in the human lineage).

---

## filter-feeding

**Claim:** Tamisiocaris borealis was a filter-feeding radiodont that used
comb-like frontal appendages to sieve plankton from the water column.

**Basis:** Vinther et al. (2014, *Nature* 507:496–499): Tamisiocaris's frontal
appendages bear long, regularly spaced spines consistent with filter feeding on
small particles. This is an exaptation of raptorial appendages into filter apparatus.

**Game mechanic:** Filter combs → `filter_combs` affix (`uptime_mult`, mult 1.35).
The uptime multiplier represents sustained passive intake per unit time — consistent
with filter feeding as a passive, high-throughput feeding strategy.

---

## transparency-crypsis

**Claim:** Transparency is a real open-water crypsis strategy used by pelagic
invertebrates. `glass_drifter` is an invented creature asserting only this
well-established strategy.

**Basis:** Johnsen (2001, *Journal of Experimental Biology* 204:2131–2142):
transparency is the dominant crypsis mechanism in mesopelagic and pelagic
invertebrates (chaetognaths, ctenophores, medusae, pteropods) because it does
not depend on background matching in a featureless environment.

The Cambrian origin of transparency as a strategy is plausible — the physics of
light scattering are unchanged, and soft-bodied Cambrian organisms with low
refractive-index tissue would appear transparent. The fossil record does not
contradict this; it simply cannot preserve transparent tissue.

**Game mechanic:** `glassy_tissue` affix (`ambush_frac`, frac 0.25). The ambush
fraction opens a partial gene/splice gate below the power threshold — representing
how crypsis allows a transparent predator to exploit the ambush window even when
outmatched. `glass_drifter` and `lucent_flesh` material are invented; all asserted
biology (transparency as pelagic crypsis) is real.
