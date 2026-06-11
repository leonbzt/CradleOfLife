# Refs — The Shallow Benthos (Age I)

Scientific rationale for every capability authored in the `shallow_benthos` niche.
Each section is the anchor a content row's `source` field points at.

> **Gate-2 status: rationale only.** The notes below are the *case* for each
> claim, written to be checked — not a passed review. Before a row merges, a
> human verifies the claim against a cited primary/secondary source and records
> it here. AI is unreliable at facts; this file is where the human closes that
> gap (VISION.md §2, gate 2).

---

## Microbial mats

**Used by:** the `microbial_mat` Eat node.
Cyanobacterial mats and stromatolites are among the oldest communities on Earth
and persisted into the shallow Cambrian sea floor. As a passive, undefended food
source (photosynthetic primary production grazed by early animals) they are the
canonical low-risk Eat node. *Verify: source on Cambrian microbial mats / matground
ecology.*

## Cnidarian nematocysts

**Role:** `affliction` (damage-over-time). **Used by:** Venom affix, Sea Anemone.
Cnidarians (anemones, jellyfish, hydroids) carry nematocysts — explosive stinging
cells that inject venom on contact. Venom is a real, ancient delivery mechanism
and a clean DoT in game terms: it keeps working after contact rather than
front-loading damage. *Verify: source on cnidarian nematocyst structure & venom
function.*

## Biomineralized exoskeletons

**Role:** `guard`. **Used by:** Sclerite Plating affix, Trilobite Grazer.
The Cambrian saw the widespread arrival of biomineralized hard parts — trilobites
built calcite (calcium carbonate) exoskeletons. Hard armour reduces incoming
damage: a flat mitigation term, distinct from dodge or regen. *Verify: source on
Cambrian biomineralization / trilobite calcite cuticle.*

## Raptorial appendages

**Role:** `control` (immobilise). **Used by:** Raptorial Grasp affix, the Great
Appendage (legendary), Anomalocaris.
Radiodonts such as *Anomalocaris* bore paired frontal grasping appendages used to
seize prey. A grasping limb that pins prey maps to control/slow — preventing
escape — which is mechanically distinct from raw damage. *Verify: source on
radiodont frontal appendage morphology & function.*

## Gill surface area

**Role:** `sustain` (sustained throughput). **Used by:** Gill Branching affix.
Respiratory gas exchange scales with respiratory surface area; branched/feathered
gills increase that surface and so support a higher sustained metabolic rate. In
game terms this is an uptime/throughput multiplier, not burst. *Verify: source on
gill surface-area scaling and aquatic respiration.*

## Compound eyes

**Role:** `perception` (rare-find / acuity). **Used by:** Compound Eyes affix, stalked
eyes, Anomalocaris.
Trilobites had mineralised (calcitic) compound eyes; radiodonts including
*Anomalocaris* had large compound eyes with many lenses (described from
exceptionally preserved material). Acute vision maps to find-rate / detection —
the Instinct attribute — distinct from damage or defense. *Verify: source on
trilobite calcitic eyes and radiodont compound eyes.*

## Gnathobases

**Role:** `penetration` (armour-break). **Used by:** Gnathobase affix.
Many early arthropods processed prey with gnathobases — toothed spines at the
bases of the legs — capable of crushing shelled prey. Crushing through hard parts
maps to penetration: reducing the effectiveness of an opponent's mitigation,
distinct from raw power. *Verify: source on arthropod gnathobasic feeding (e.g.
trilobites, Sidneyia).*
