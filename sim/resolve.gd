class_name Resolve
extends RefCounted

## The one loop, RPG-resolved (VISION.md §8). Eat and Fight are the SAME call
## pointed at different node kinds — two engines would be two balancing burdens,
## and the whole moat depends on one. Pure and Node-free.
##
## resolve() models ONE foraging action over a short `dt`. The economy itself
## lives in the rate helpers below; long offline gaps are integrated by
## sim/accrual.gd using these SAME rates (closed form for materials, a Poisson
## process for rare gene events) — so there is exactly one economy, evaluated
## two ways.

const TIER_POWER: float = 1.0  # effective power contributed per adaptation tier


## A single foraging action. Materials always; a gene on the (independent) jackpot
## roll; a splice offer when the node is something that hits back.
static func resolve(lineage: Lineage, node: Dictionary, dt: float, rng: Rng) -> Dictionary:
	var loot: Dictionary = {"materials": {}, "gene": {}, "splice_offer": ""}

	var mat_id: String = String(node.get("material", ""))
	if mat_id != "":
		loot["materials"][mat_id] = material_rate(lineage, node) * dt

	# The chase: one independent roll per action (VISION.md §9a). Pure
	# independent rolls for now — no pity; the harness measures the dry-streak
	# tail so we can see whether one is ever needed.
	var p_gene: float = 1.0 - exp(-gene_rate(lineage, node) * dt)
	if rng.chance("gene", p_gene):
		loot["gene"] = roll_gene(node, rng)

	if String(node.get("kind", "eat")) == "fight":
		var p_splice: float = 1.0 - exp(-float(node.get("splice_rate", 0.0)) * dt)
		if rng.chance("splice", p_splice):
			loot["splice_offer"] = String(node.get("spliceable", ""))

	return loot


## Effective Power the build brings to bear: base attribute plus the tiers of
## everything equipped. Equipping a higher-tier adaptation measurably raises this
## — the whole point of having a defended node to test it against (VISION.md §8
## design note). Node-specific matchup mods (affix-keys, affinity) arrive with
## the niches that need them in Phase 2; not built yet.
static func effective_power(lineage: Lineage) -> float:
	var p: float = float(lineage.attributes.get("power", 1.0))
	for slot: String in lineage.doll:
		p += TIER_POWER * float((lineage.doll[slot] as AdaptationInstance).tier)
	return p


## Yield multiplier from the Power-vs-defense margin. Split out because it is
## the number the player watches move when they equip ("yield ×1.4") — the UI
## reads THIS, never re-derives the math.
static func yield_efficiency(lineage: Lineage, node: Dictionary) -> float:
	var margin: float = effective_power(lineage) - float(node.get("defense", 0.0))
	return clampf(1.0 + 0.1 * margin, 0.1, 5.0)


## Materials gathered per in-game second: a Power-vs-defense margin scaled by the
## lineage's metabolism. Always positive, so even a too-strong node still feeds.
static func material_rate(lineage: Lineage, node: Dictionary) -> float:
	var base: float = float(node.get("material_rate", 0.0))
	var metab: float = float(lineage.attributes.get("metabolism", 1.0))
	return base * metab * yield_efficiency(lineage, node)


## Mean genes per in-game second (the Poisson rate). Zero until the build can
## actually beat the node — the jackpot is gated behind winning the matchup, so
## upgrading your gear opens the chase, not just the yield. Scaled by Instinct
## (rare-find), per the attribute table (VISION.md §7).
static func gene_rate(lineage: Lineage, node: Dictionary) -> float:
	if effective_power(lineage) <= float(node.get("defense", 0.0)):
		return 0.0
	var base: float = float(node.get("gene_rate", 0.0))
	var instinct: float = float(lineage.attributes.get("instinct", 1.0))
	return base * instinct


## Weighted pick from the node's (inlined) gene table. Returns {id, rarity}.
static func roll_gene(node: Dictionary, rng: Rng) -> Dictionary:
	var table: Array = node.get("gene_table", [])
	if table.is_empty():
		return {}
	var total: float = 0.0
	for row: Dictionary in table:
		total += float(row.get("weight", 0.0))
	if total <= 0.0:
		return {}
	var pick: float = rng.randf("gene_pick") * total
	var acc: float = 0.0
	for row: Dictionary in table:
		acc += float(row.get("weight", 0.0))
		if pick <= acc:
			return {
				"id": String(row.get("gene", "")), "rarity": String(row.get("rarity", "common"))
			}
	var last: Dictionary = table[-1]
	return {"id": String(last.get("gene", "")), "rarity": String(last.get("rarity", "common"))}
