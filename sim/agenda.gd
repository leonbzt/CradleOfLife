class_name Agenda
extends RefCounted

## The derived "do-now" surface (PHASE3_5.md WP2). A PURE function of current
## state — it adds no save fields and mutates nothing — that names the concrete
## next actions and the nearest chase targets for one lineage. This is the legible
## face of opportunity cost (VISION.md §5) and the chase ceiling (§9a): it answers
## "what do I do this check-in?" without ever throttling decisions (§12). The UI
## renders the rows and wires the ready-now actions; the chase nudges are info.

## Lower = more important. Ready-to-act objectives rank above chase nudges.
const P_CLAIM_SPLICE: int = 10
const P_TIERUP_READY: int = 20
const P_NODE_IN_REACH: int = 40
const P_ONE_COPY_SHORT: int = 50

const MAX_ITEMS: int = 4


## Up to MAX_ITEMS ranked objectives for `lineage_id`, each a dict:
##   {kind: String, text: String, priority: int, action: Dictionary}
## `action` is empty for chase nudges; for ready actions it is one of
##   {cmd:"claim_splice", index}, {cmd:"metabolize", adaptation_id}.
static func for_lineage(
	state: GameState, content: Content, lineage_id: String
) -> Array[Dictionary]:
	var l := state.lineage_by_id(lineage_id)
	if l == null:
		return []
	var items: Array[Dictionary] = []

	_add_claim_splice(state, content, items)
	_add_tierup_ready(state, content, l, items)
	_add_node_in_reach(state, content, l, items)
	_add_one_copy_short(state, content, l, items)

	items.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("priority", 99)) < int(b.get("priority", 99))
	)
	var out: Array[Dictionary] = []
	for i in mini(items.size(), MAX_ITEMS):
		out.append(items[i])
	return out


# -- objective detectors (each appends 0 or 1 item) ---------------------------


## A spliced gene is waiting to be claimed (a free build win). Splice offers are
## account-wide, so this surfaces regardless of which lineage is shown.
static func _add_claim_splice(state: GameState, content: Content, items: Array[Dictionary]) -> void:
	if state.splice_offers.is_empty():
		return
	var offer: Dictionary = state.splice_offers[0]
	var gene_row := content.gene(String(offer.get("gene", "")))
	(
		items
		. append(
			{
				"kind": "claim_splice",
				"text":
				"Claim spliced gene: %s" % String(gene_row.get("name", offer.get("gene", ""))),
				"priority": P_CLAIM_SPLICE,
				"action": {"cmd": "claim_splice", "index": 0},
			}
		)
	)


## The cheapest adaptation this lineage can build or tier up right now (not maxed,
## materials in hand).
static func _add_tierup_ready(
	state: GameState, content: Content, l: Lineage, items: Array[Dictionary]
) -> void:
	var best: Dictionary = {}
	var best_cost := INF
	for def: Dictionary in content.tables.get("adaptations", []):
		# Don't suggest a "build" that would silently REPLACE a different organ
		# already in this slot (a metabolize swap, not a free upgrade). Only tier up
		# the organ that's there, or build into an empty slot (WP3: ≥2 options/slot).
		var equipped: AdaptationInstance = l.doll.get(String(def.get("slot", "")))
		if equipped != null and equipped.def_id != String(def.get("id", "")):
			continue
		var tier := Commands.next_tier(l, def)
		if tier == 0:
			continue
		var cost := Commands.metabolize_cost(def, tier)
		var total := 0.0
		var affordable := true
		for mat_id: String in cost:
			total += float(cost[mat_id])
			if float(state.inventory_materials.get(mat_id, 0.0)) < float(cost[mat_id]):
				affordable = false
				break
		if affordable and total < best_cost:
			best_cost = total
			best = def
	if best.is_empty():
		return
	var next := Commands.next_tier(l, best)
	var verb := "Build" if next == 1 else "Tier up"
	(
		items
		. append(
			{
				"kind": "tierup_ready",
				"text": "%s %s (T%d)" % [verb, String(best.get("name", best.get("id", ""))), next],
				"priority": P_TIERUP_READY,
				"action": {"cmd": "metabolize", "adaptation_id": String(best.get("id", ""))},
			}
		)
	)


## The defended node this lineage is closest to clearing but cannot yet (in an
## accessible niche). Uses the same effective-defense gate resolve() does, so the
## "+N power" reads true.
static func _add_node_in_reach(
	state: GameState, content: Content, l: Lineage, items: Array[Dictionary]
) -> void:
	var eff_power := Resolve.effective_power(l, content)
	var totals := Resolve.affix_totals(l, content)
	var best: Dictionary = {}
	var best_gap := INF
	for n: Dictionary in content.tables.get("nodes", []):
		var niche_id := String(n.get("niche", ""))
		if niche_id != "" and not Commands.meets_niche_keys(l, content, niche_id):
			continue
		var gap := Resolve.effective_defense(n, totals) - eff_power
		if gap <= 0.0:
			continue
		if gap < best_gap:
			best_gap = gap
			best = n
	if best.is_empty():
		return
	(
		items
		. append(
			{
				"kind": "node_in_reach",
				"text":
				(
					"Almost ready for %s — need +%d power"
					% [String(best.get("name", "")), ceili(best_gap)]
				),
				"priority": P_NODE_IN_REACH,
				"action": {},
			}
		)
	)


## An equipped affix that is exactly one gene copy short of its next express tier
## (the copy ladder, made visible). Names where the copy drops, preferring the
## targeted splice source.
static func _add_one_copy_short(
	state: GameState, content: Content, l: Lineage, items: Array[Dictionary]
) -> void:
	for slot: String in l.doll:
		var inst: AdaptationInstance = l.doll[slot]
		for express: Dictionary in inst.affixes:
			var affix_id := String(express.get("id", ""))
			var cur := int(express.get("tier", 0))
			var gene_row := content.gene_for_affix(affix_id)
			if gene_row.is_empty():
				continue
			var gene_id := String(gene_row.get("id", ""))
			# Need cur+1 copies to reach tier cur+1; one short means we hold exactly cur.
			if int(state.genes_known.get(gene_id, 0)) != cur:
				continue
			var affix_row := content.affix(affix_id)
			(
				items
				. append(
					{
						"kind": "one_copy_short",
						"text":
						(
							"1 more %s → %s T%d%s"
							% [
								String(gene_row.get("name", gene_id)),
								String(affix_row.get("name", affix_id)),
								cur + 1,
								_source_hint(content, gene_id),
							]
						),
						"priority": P_ONE_COPY_SHORT,
						"action": {},
					}
				)
			)
			return


## " — splice <creature>" for a targeted source, else " — <creature>", else "".
static func _source_hint(content: Content, gene_id: String) -> String:
	var srcs := content.sources_for_gene(gene_id)
	if srcs.is_empty():
		return ""
	for s: Dictionary in srcs:
		if (s.get("via", []) as Array).has("splice"):
			return " — splice %s" % String(s.get("name", ""))
	return " — %s" % String((srcs[0] as Dictionary).get("name", ""))
