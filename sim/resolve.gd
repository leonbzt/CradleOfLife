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
## All seven orthogonal affix roles are mechanically real (the moat, VISION §17).
##
## Each doll slot feeds a specific attribute (not uniform +Power): the equipped
## *adaptation* declares which via its `feeds` field, so two organs in the same
## slot can grow different attributes (a power mouthpart vs a filter-feeding one).
## effective_power() soft-caps the result. Role is *derived* from the doll for
## display only (derived_role) — the class tree is parked (DECISIONS 2026-06-14
## reset), so there is no class stat_mod or niche multiplier in the economy.
##
## SLOT_ATTRIBUTE below is the per-slot DEFAULT, used only for rows that omit
## `feeds` (defensive); real content declares `feeds`. gland feeds no base
## attribute (affix host); vitality is unused this phase.
## NOTE: keeping a power default on locomotion (and the swimming_flaps option)
## holds two power slots so the margin engine stays healthy (DECISIONS 2026-06-13).
const SLOT_ATTRIBUTE: Dictionary = {
	"mouthparts": "power",
	"locomotion": "power",
	"integument": "resilience",
	"metabolic_core": "metabolism",
	"sensory": "instinct",
	"gland": "",
}
const SLOT_TIER_WEIGHT: float = 1.0

## Soft-cap constants — placeholders, WP6 tunes and Leon signs the numbers.
## Knee must sit above the Age-I beat threshold (Anomalocaris DEF 9).
const SOFT_CAP_KNEE: float = 12.0
const SOFT_CAP_K: float = 0.15

const MARGIN_SLOPE: float = 0.1
const EFF_FLOOR: float = 0.1
const EFF_CAP: float = 5.0
const DANGER_TAX_K: float = 0.15
const DANGER_FACTOR_FLOOR: float = 0.2
const AMBUSH_CAP: float = 0.75

## Display-only role labels (derived_role): the dominant fed attribute → a label.
const ROLE_BY_ATTRIBUTE: Dictionary = {
	"power": "Predator",
	"resilience": "Armored Grazer",
	"metabolism": "Filter Feeder",
	"instinct": "Ambusher",
}


## The lineage's five attributes after per-slot doll contributions. Every rate
## helper reads THIS — never lineage.attributes directly.
static func effective_attributes(lineage: Lineage, content: Content) -> Dictionary:
	var attrs := lineage.attributes.duplicate()
	for slot: String in lineage.doll:
		var inst := lineage.doll[slot] as AdaptationInstance
		var a := attribute_for_def(content.adaptation(inst.def_id), slot)
		if a != "":
			attrs[a] = float(attrs.get(a, 0.0)) + SLOT_TIER_WEIGHT * float(inst.tier)
	return attrs


## A display-only role label read off the doll — no engine effect (VISION §7:
## "build is the doll; role emerges from it"). The class tree is parked
## (DECISIONS 2026-06-14 reset); this derives a label from the dominant attribute
## the equipped organs feed. An unbuilt doll reads "Generalist".
static func derived_role(lineage: Lineage, content: Content) -> String:
	var attrs := effective_attributes(lineage, content)
	var best := ""
	var best_over := 0.0
	for a: String in ["power", "resilience", "metabolism", "instinct"]:
		var over := float(attrs.get(a, 1.0)) - 1.0  # contribution above the base 1.0
		if over > best_over:
			best_over = over
			best = a
	return String(ROLE_BY_ATTRIBUTE.get(best, "Generalist")) if best != "" else "Generalist"


## The attribute an adaptation `def` feeds: its declared `feeds`, falling back to
## the slot default for rows that omit it. "" means it feeds no base attribute
## (the gland). The UI reads THIS so a metabolize option can show its attribute.
static func attribute_for_def(def: Dictionary, slot: String = "") -> String:
	if def.has("feeds"):
		return String(def.get("feeds", ""))
	var s := slot if slot != "" else String(def.get("slot", ""))
	return String(SLOT_ATTRIBUTE.get(s, ""))


## Diminishing returns on Power above SOFT_CAP_KNEE.
## Asymptote ≈ KNEE + 1/SOFT_CAP_K. Below the knee: identity.
static func soft_cap(p: float) -> float:
	if p <= SOFT_CAP_KNEE:
		return p
	var over := p - SOFT_CAP_KNEE
	return SOFT_CAP_KNEE + over / (1.0 + SOFT_CAP_K * over)


## Effective Power: per-slot doll contributions + soft cap.
## content is required — no default arg so the compiler catches every call site.
static func effective_power(lineage: Lineage, content: Content) -> float:
	return soft_cap(float(effective_attributes(lineage, content).get("power", 1.0)))


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
## calculation — it is the only place penetration enters.
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
	var eff_attrs := effective_attributes(lineage, content)

	var mat_id := String(node.get("material", ""))
	if mat_id != "":
		loot["materials"][mat_id] = (
			_material_rate_inner(lineage, node, totals, content, eff_attrs) * dt
		)

	var gate := _gate(lineage, node, totals, content)
	var base_gene := float(node.get("gene_rate", 0.0))
	var instinct := float(eff_attrs.get("instinct", 1.0))
	var p_gene := (
		1.0 - exp(-base_gene * instinct * (1.0 + float(totals.get("find_bonus", 0.0))) * gate * dt)
	)
	if rng.chance("gene", p_gene):
		loot["gene"] = roll_gene(node, rng)

	if String(node.get("kind", "eat")) == "fight":
		var base_splice := float(node.get("splice_rate", 0.0))
		var p_splice := (
			1.0 - exp(-base_splice * (1.0 + float(totals.get("splice_bonus", 0.0))) * gate * dt)
		)
		if rng.chance("splice", p_splice):
			loot["splice_offer"] = String(node.get("spliceable", ""))

	return loot


## Yield multiplier from Power-vs-effective-defense margin.
## The UI reads THIS to show "yield ×N" — it never re-derives the formula.
static func yield_efficiency(lineage: Lineage, node: Dictionary, content: Content) -> float:
	return _eff(lineage, node, affix_totals(lineage, content), content)


## The danger-tax multiplier as the clash panel shows it (1.0 = no tax, < 1 =
## retaliation bites; eat nodes are always 1.0). Public readout so the UI reads
## THIS rather than re-deriving the tax formula (WP4 visible combat).
static func danger_factor(lineage: Lineage, node: Dictionary, content: Content) -> float:
	return _danger_factor(lineage, node, affix_totals(lineage, content), content)


## Materials gathered per second: margin efficiency, uptime bonus, and the danger
## tax all fold in. Always positive.
static func material_rate(lineage: Lineage, node: Dictionary, content: Content) -> float:
	var totals := affix_totals(lineage, content)
	var eff_attrs := effective_attributes(lineage, content)
	return _material_rate_inner(lineage, node, totals, content, eff_attrs)


## Mean gene drops per second (the Poisson rate). Zero until power clears the
## effective defense — unless stealth's ambush fraction cracks the gate open.
static func gene_rate(lineage: Lineage, node: Dictionary, content: Content) -> float:
	var totals := affix_totals(lineage, content)
	var gate := _gate(lineage, node, totals, content)
	if is_zero_approx(gate):
		return 0.0
	var eff_attrs := effective_attributes(lineage, content)
	var base := float(node.get("gene_rate", 0.0))
	var instinct := float(eff_attrs.get("instinct", 1.0))
	return base * instinct * (1.0 + float(totals.get("find_bonus", 0.0))) * gate


## Mean splice offers per second. Gated like genes; control affix multiplies it.
## splice_rate_eff is unchanged by the niche multiplier (PHASE3.md §2.3).
static func splice_rate_eff(lineage: Lineage, node: Dictionary, content: Content) -> float:
	var totals := affix_totals(lineage, content)
	var gate := _gate(lineage, node, totals, content)
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
			return {
				"id": String(row.get("gene", "")), "rarity": String(row.get("rarity", "common"))
			}
	var last: Dictionary = table[-1]
	return {"id": String(last.get("gene", "")), "rarity": String(last.get("rarity", "common"))}


# -- private helpers -----------------------------------------------------------


static func _eff(lineage: Lineage, node: Dictionary, totals: Dictionary, content: Content) -> float:
	var d_eff := effective_defense(node, totals)
	var margin := effective_power(lineage, content) - d_eff
	var floor := EFF_FLOOR
	if String(node.get("kind", "eat")) == "fight":
		floor = minf(EFF_FLOOR + float(totals.get("dot", 0.0)), 1.0)
	return clampf(1.0 + MARGIN_SLOPE * margin, floor, EFF_CAP)


static func _danger_factor(
	lineage: Lineage, node: Dictionary, totals: Dictionary, content: Content
) -> float:
	if String(node.get("kind", "eat")) != "fight":
		return 1.0
	var eff_attrs := effective_attributes(lineage, content)
	var tax := (
		DANGER_TAX_K
		* maxf(
			0.0,
			(
				float(node.get("danger", 0.0))
				- float(eff_attrs.get("resilience", 1.0))
				- float(totals.get("guard", 0.0))
			)
		)
	)
	return clampf(1.0 - tax, DANGER_FACTOR_FLOOR, 1.0)


static func _gate(
	lineage: Lineage, node: Dictionary, totals: Dictionary, content: Content
) -> float:
	return (
		1.0
		if effective_power(lineage, content) > effective_defense(node, totals)
		else float(totals.get("ambush", 0.0))
	)


static func _material_rate_inner(
	lineage: Lineage,
	node: Dictionary,
	totals: Dictionary,
	content: Content,
	eff_attrs: Dictionary,
) -> float:
	var base := float(node.get("material_rate", 0.0))
	var metab := float(eff_attrs.get("metabolism", 1.0))
	var eff := _eff(lineage, node, totals, content)
	var danger := _danger_factor(lineage, node, totals, content)
	return base * metab * eff * (1.0 + float(totals.get("uptime_bonus", 0.0))) * danger
