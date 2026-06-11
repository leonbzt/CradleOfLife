class_name Resolve
extends RefCounted

## The one loop, RPG-resolved (VISION.md §8). Eat and Fight are the SAME call
## pointed at different node kinds — two engines would be two balancing burdens,
## and the whole moat depends on one. Pure and Node-free.
##
## resolve() models ONE foraging action over a short `dt`. The economy lives in
## the rate helpers below; long offline gaps are integrated by sim/accrual.gd
## using these SAME rates — so there is exactly one economy, evaluated two ways.
##
## Phase 2: all seven orthogonal affix roles are mechanically real. affix_totals()
## reads every grafted affix from the equipped doll and sums its contribution
## per math_term. Penetration reduces effective defense; dot raises the losing-
## matchup yield floor; danger taxes material rate (mitigation guards against it);
## uptime multiplies material rate; find and stealth each gate-extend the chase.

const TIER_POWER: float = 1.0
const MARGIN_SLOPE: float = 0.1
const EFF_FLOOR: float = 0.1
const EFF_CAP: float = 5.0
const DANGER_TAX_K: float = 0.15
const DANGER_FACTOR_FLOOR: float = 0.2
const AMBUSH_CAP: float = 0.75


## Sums every grafted affix's contribution per math_term. Returns all keys
## always present (zero/identity defaults), so callers never branch on has().
static func affix_totals(lineage: Lineage, content: Content) -> Dictionary:
	var pen: float = 0.0
	var dot: float = 0.0
	var guard: float = 0.0
	var ambush: float = 0.0
	var splice_bonus: float = 0.0
	var uptime_bonus: float = 0.0
	var find_bonus: float = 0.0

	for slot: String in lineage.doll:
		var inst: AdaptationInstance = lineage.doll[slot]
		for graft: Dictionary in inst.affixes:
			var affix_id := String(graft.get("id", ""))
			var tier := int(graft.get("tier", 1))
			var row := content.affix(affix_id)
			if row.is_empty():
				continue
			var params: Dictionary = row.get("params", {})
			match String(row.get("math_term", "")):
				"pen_flat":
					pen += float(params.get("amount", 0.0)) * tier
				"dot_floor":
					dot += float(params.get("tick_pct", 0.0)) * tier
				"danger_guard":
					guard += float(params.get("amount", 0.0)) * tier
				"ambush_frac":
					ambush += float(params.get("frac", 0.0)) * tier
				"splice_mult":
					splice_bonus += (float(params.get("mult", 1.0)) - 1.0) * tier
				"uptime_mult":
					uptime_bonus += (float(params.get("mult", 1.0)) - 1.0) * tier
				"find_mult":
					find_bonus += (float(params.get("mult", 1.0)) - 1.0) * tier

	return {
		"pen": pen,
		"dot": dot,
		"guard": guard,
		"ambush": minf(ambush, AMBUSH_CAP),
		"splice_bonus": splice_bonus,
		"uptime_bonus": uptime_bonus,
		"find_bonus": find_bonus,
	}


## Effective defense after penetration. Pen reduces D before every other
## calculation — it is the only place penetration enters (PHASE2.md §2.2).
static func effective_defense(node: Dictionary, totals: Dictionary) -> float:
	return maxf(0.0, float(node.get("defense", 0.0)) - float(totals.get("pen", 0.0)))


## A single foraging action. Materials always; a gene on the (independent)
## jackpot roll; a splice offer when the node hits back. Pure-independent rolls,
## no pity — the harness measures the dry-streak tail (DECISIONS.md 2026-06-10).
static func resolve(
	lineage: Lineage, node: Dictionary, dt: float, rng: Rng, content: Content
) -> Dictionary:
	var loot: Dictionary = {"materials": {}, "gene": {}, "splice_offer": ""}
	var totals := affix_totals(lineage, content)

	var mat_id := String(node.get("material", ""))
	if mat_id != "":
		loot["materials"][mat_id] = _material_rate_inner(lineage, node, totals) * dt

	var gate := _gate(lineage, node, totals)
	var base_gene := float(node.get("gene_rate", 0.0))
	var instinct := float(lineage.attributes.get("instinct", 1.0))
	var p_gene := 1.0 - exp(
		-base_gene * instinct * (1.0 + float(totals.get("find_bonus", 0.0))) * gate * dt
	)
	if rng.chance("gene", p_gene):
		loot["gene"] = roll_gene(node, rng)

	if String(node.get("kind", "eat")) == "fight":
		var base_splice := float(node.get("splice_rate", 0.0))
		var p_splice := 1.0 - exp(
			-base_splice * (1.0 + float(totals.get("splice_bonus", 0.0))) * gate * dt
		)
		if rng.chance("splice", p_splice):
			loot["splice_offer"] = String(node.get("spliceable", ""))

	return loot


## Effective Power: base attribute plus the tiers of everything equipped.
## Equipping a higher-tier adaptation measurably raises this — the whole point
## of having a defended node to test it against (VISION.md §8).
static func effective_power(lineage: Lineage) -> float:
	var p: float = float(lineage.attributes.get("power", 1.0))
	for slot: String in lineage.doll:
		p += TIER_POWER * float((lineage.doll[slot] as AdaptationInstance).tier)
	return p


## Yield multiplier from Power-vs-effective-defense margin. Penetration reduces
## D_eff before this calculation. The UI reads THIS to show "yield ×N" — it
## never re-derives the formula.
static func yield_efficiency(lineage: Lineage, node: Dictionary, content: Content) -> float:
	return _eff(lineage, node, affix_totals(lineage, content))


## Materials gathered per second: margin efficiency, uptime bonus, and danger
## tax all fold in. Always positive — even a losing matchup still feeds.
static func material_rate(lineage: Lineage, node: Dictionary, content: Content) -> float:
	return _material_rate_inner(lineage, node, affix_totals(lineage, content))


## Mean gene drops per second (the Poisson rate). Zero until power clears the
## effective defense — unless stealth's ambush fraction cracks the gate open.
static func gene_rate(lineage: Lineage, node: Dictionary, content: Content) -> float:
	var totals := affix_totals(lineage, content)
	var gate := _gate(lineage, node, totals)
	if is_zero_approx(gate):
		return 0.0
	var base := float(node.get("gene_rate", 0.0))
	var instinct := float(lineage.attributes.get("instinct", 1.0))
	return base * instinct * (1.0 + float(totals.get("find_bonus", 0.0))) * gate


## Mean splice offers per second. Gated like genes; control affix multiplies it.
static func splice_rate_eff(lineage: Lineage, node: Dictionary, content: Content) -> float:
	var totals := affix_totals(lineage, content)
	var gate := _gate(lineage, node, totals)
	if is_zero_approx(gate):
		return 0.0
	var base := float(node.get("splice_rate", 0.0))
	return base * (1.0 + float(totals.get("splice_bonus", 0.0))) * gate


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
			return {"id": String(row.get("gene", "")), "rarity": String(row.get("rarity", "common"))}
	var last: Dictionary = table[-1]
	return {"id": String(last.get("gene", "")), "rarity": String(last.get("rarity", "common"))}


# -- private helpers -----------------------------------------------------------


static func _eff(lineage: Lineage, node: Dictionary, totals: Dictionary) -> float:
	var d_eff := effective_defense(node, totals)
	var margin := effective_power(lineage) - d_eff
	var floor := EFF_FLOOR
	if String(node.get("kind", "eat")) == "fight":
		floor = minf(EFF_FLOOR + float(totals.get("dot", 0.0)), 1.0)
	return clampf(1.0 + MARGIN_SLOPE * margin, floor, EFF_CAP)


static func _danger_factor(lineage: Lineage, node: Dictionary, totals: Dictionary) -> float:
	if String(node.get("kind", "eat")) != "fight":
		return 1.0
	var tax := DANGER_TAX_K * maxf(
		0.0,
		float(node.get("danger", 0.0))
			- float(lineage.attributes.get("resilience", 1.0))
			- float(totals.get("guard", 0.0))
	)
	return clampf(1.0 - tax, DANGER_FACTOR_FLOOR, 1.0)


static func _gate(lineage: Lineage, node: Dictionary, totals: Dictionary) -> float:
	return (
		1.0
		if effective_power(lineage) > effective_defense(node, totals)
		else float(totals.get("ambush", 0.0))
	)


static func _material_rate_inner(
	lineage: Lineage, node: Dictionary, totals: Dictionary
) -> float:
	var base := float(node.get("material_rate", 0.0))
	var metab := float(lineage.attributes.get("metabolism", 1.0))
	var eff := _eff(lineage, node, totals)
	var danger := _danger_factor(lineage, node, totals)
	return base * metab * eff * (1.0 + float(totals.get("uptime_bonus", 0.0))) * danger
