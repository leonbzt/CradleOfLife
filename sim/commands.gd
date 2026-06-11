class_name Commands
extends RefCounted

## Every mutation of GameState is a named command here (arch §2: replayable,
## testable). Pure and Node-free: (state, content, rng) in, applied change +
## result out. state_store.gd wraps these for the running game and owns
## signals/persistence; headless tests call them directly.

## Rarity a Metabolize-built adaptation carries at each tier (1-indexed).
## Pure craft tops out at "rare" — epic/legendary colours require gene grafts
## (VISION.md §9: materials common→rare, genes rare→legendary).
const TIER_RARITY: Array[String] = ["common", "uncommon", "rare"]


## Starts the Tree: one starter lineage assigned to the first node in content.
static func add_starter_lineage(state: GameState, content: Content) -> Lineage:
	var l := Lineage.new("main", "Your Main")
	var nodes: Array = content.tables.get("nodes", [])
	if not nodes.is_empty():
		l.assigned_node = String((nodes[0] as Dictionary).get("id", ""))
	state.lineages.append(l)
	return l


## Point the lineage at a different node. Checks niche affix-keys: a locked
## niche requires the lineage to have an equipped graft matching each key role.
## A losing matchup never locks the player out — it just yields poorly.
static func assign_node(
	state: GameState, content: Content, lineage_id: String, node_id: String
) -> bool:
	var l := state.lineage_by_id(lineage_id)
	if l == null or content.node(node_id).is_empty():
		return false
	var node := content.node(node_id)
	var niche_id := String(node.get("niche", ""))
	if niche_id != "" and not meets_niche_keys(l, content, niche_id):
		return false
	l.assigned_node = node_id
	return true


## True if the lineage has at least one equipped graft for every affix_key role
## declared by the niche. The shallow_benthos has no keys; always passes.
static func meets_niche_keys(lineage: Lineage, content: Content, niche_id: String) -> bool:
	var niche := content.niche(niche_id)
	if niche.is_empty():
		return false
	var keys: Array = niche.get("affix_keys", [])
	if keys.is_empty():
		return true
	for key: Variant in keys:
		var role := String(key)
		var found := false
		for slot: String in lineage.doll:
			var inst: AdaptationInstance = lineage.doll[slot]
			for graft: Dictionary in inst.affixes:
				var affix_row := content.affix(String(graft.get("id", "")))
				if String(affix_row.get("orthogonal_role", "")) == role:
					found = true
					break
			if found:
				break
		if not found:
			return false
	return true


## One foraging action of `dt` seconds. Gene drops add to genes_known counts.
## Splice offers are banked in state.splice_offers (Phase 2 fix: Phase 1 dropped
## them on the floor — see DECISIONS.md 2026-06-11).
static func forage(
	state: GameState, content: Content, lineage_id: String, dt: float, rng: Rng
) -> Dictionary:
	var l := state.lineage_by_id(lineage_id)
	if l == null or l.graduated or l.assigned_node == "":
		return {}
	var node := content.node(l.assigned_node)
	if node.is_empty():
		return {}
	var loot := Resolve.resolve(l, node, dt, rng, content)
	for mat_id: String in (loot["materials"] as Dictionary):
		var have: float = float(state.inventory_materials.get(mat_id, 0.0))
		state.inventory_materials[mat_id] = have + float(loot["materials"][mat_id])
	var gene: Dictionary = loot["gene"]
	if not gene.is_empty():
		var gid := String(gene.get("id", ""))
		if gid != "":
			state.genes_known[gid] = int(state.genes_known.get(gid, 0)) + 1
	var offer := String(loot["splice_offer"])
	if offer != "":
		state.splice_offers.append({"gene": offer, "node": String(node.get("id", ""))})
	return loot


## Pop the splice offer at `index`, add 1 copy of its gene to genes_known.
static func claim_splice(state: GameState, index: int) -> Dictionary:
	if index < 0 or index >= state.splice_offers.size():
		return {"ok": false, "reason": "no offer at index %d" % index}
	var offer: Dictionary = state.splice_offers[index]
	state.splice_offers.remove_at(index)
	var gid := String(offer.get("gene", ""))
	if gid != "":
		state.genes_known[gid] = int(state.genes_known.get(gid, 0)) + 1
	return {"ok": true, "gene": gid}


## Graft an affix onto the equipped adaptation in `slot`. Copies of the
## unlocking gene cap the graft tier; copies are never consumed.
## Returns {ok, reason, instance?}.
static func graft(
	state: GameState, content: Content, lineage_id: String, slot: String, affix_id: String
) -> Dictionary:
	var l := state.lineage_by_id(lineage_id)
	if l == null:
		return {"ok": false, "reason": "no such lineage"}
	var inst: AdaptationInstance = l.doll.get(slot)
	if inst == null:
		return {"ok": false, "reason": "nothing equipped in slot '%s'" % slot}
	var affix_row := content.affix(affix_id)
	if affix_row.is_empty():
		return {"ok": false, "reason": "no such affix '%s'" % affix_id}
	var gene_row := content.gene_for_affix(affix_id)
	if gene_row.is_empty():
		return {"ok": false, "reason": "no gene unlocks '%s'" % affix_id}
	var gene_id := String(gene_row.get("id", ""))
	var copies := int(state.genes_known.get(gene_id, 0))
	var current_tier := inst.graft_tier(affix_id)
	var target := current_tier + 1
	if copies < target:
		var gene_name := String(gene_row.get("name", gene_id))
		return {
			"ok": false,
			"reason": "need another %s copy (have %d, need %d)" % [gene_name, copies, target]
		}
	var gc: Dictionary = affix_row.get("graft_cost", {})
	var mat := String(gc.get("material", ""))
	if mat == "":
		return {"ok": false, "reason": "affix '%s' has no graft_cost" % affix_id}
	var cost_qty := roundf(
		float(gc.get("base", 0.0)) * pow(float(gc.get("growth", 1.0)), target - 1)
	)
	if float(state.inventory_materials.get(mat, 0.0)) < cost_qty:
		return {"ok": false, "reason": "not enough %s" % mat}
	state.inventory_materials[mat] = float(state.inventory_materials.get(mat, 0.0)) - cost_qty

	# Apply or upgrade the graft
	var found := false
	for graft: Dictionary in inst.affixes:
		if String(graft.get("id", "")) == affix_id:
			graft["tier"] = target
			found = true
			break
	if not found:
		inst.affixes.append({"id": affix_id, "tier": target})

	inst.rarity = _compute_rarity(inst, content)
	return {"ok": true, "reason": "", "instance": inst}


## Metabolize (VISION.md §8): spend materials to build or tier-up an adaptation
## and socket it into its doll slot. Preserves any existing grafts on tier-up.
static func metabolize(
	state: GameState, content: Content, lineage_id: String, adaptation_id: String
) -> Dictionary:
	var l := state.lineage_by_id(lineage_id)
	if l == null:
		return {"ok": false, "reason": "no such lineage"}
	var def := content.adaptation(adaptation_id)
	if def.is_empty():
		return {"ok": false, "reason": "no such adaptation"}

	var tier := next_tier(l, def)
	if tier == 0:
		return {"ok": false, "reason": "already at max tier"}
	var cost := metabolize_cost(def, tier)
	for mat_id: String in cost:
		if float(state.inventory_materials.get(mat_id, 0.0)) < float(cost[mat_id]):
			return {"ok": false, "reason": "not enough " + mat_id}
	for mat_id: String in cost:
		state.inventory_materials[mat_id] = (
			float(state.inventory_materials.get(mat_id, 0.0)) - float(cost[mat_id])
		)

	var slot := String(def.get("slot", ""))
	var inst: AdaptationInstance = l.doll.get(slot)
	if inst == null or inst.def_id != adaptation_id:
		inst = AdaptationInstance.new(adaptation_id, tier)
	else:
		inst.tier = tier
	# Preserve existing grafts: rarity recomputes including them.
	inst.rarity = _compute_rarity(inst, content)
	l.equip(slot, inst)
	return {"ok": true, "reason": "", "instance": inst}


## The tier the next Metabolize would produce: 1 for a new build, current+1
## for an upgrade, or 0 if already at max_tier.
static func next_tier(lineage: Lineage, def: Dictionary) -> int:
	var inst: AdaptationInstance = lineage.doll.get(String(def.get("slot", "")))
	if inst == null or inst.def_id != String(def.get("id", "")):
		return 1
	if inst.tier >= int(def.get("max_tier", 1)):
		return 0
	return inst.tier + 1


## Material cost to metabolize at `tier`: base·growth^(tier-1), rounded.
static func metabolize_cost(def: Dictionary, tier: int) -> Dictionary:
	var cost: Dictionary = def.get("build_cost", {})
	var mat := String(cost.get("material", ""))
	if mat == "":
		return {}
	var qty := float(cost.get("base", 0.0)) * pow(float(cost.get("growth", 1.0)), tier - 1)
	return {mat: roundf(qty)}


## Rarity of an adaptation instance: legendary if any graft's unlocking gene is
## legendary; epic if any graft exists; otherwise the tier colour (capped rare).
static func _compute_rarity(inst: AdaptationInstance, content: Content) -> String:
	for graft: Dictionary in inst.affixes:
		var gene_row := content.gene_for_affix(String(graft.get("id", "")))
		if String(gene_row.get("rarity", "")) == "legendary":
			return "legendary"
	if not inst.affixes.is_empty():
		return "epic"
	return TIER_RARITY[mini(inst.tier, TIER_RARITY.size()) - 1]
