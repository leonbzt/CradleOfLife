class_name Commands
extends RefCounted

## Every mutation of GameState is a named command here (arch §2: replayable,
## testable). Pure and Node-free: (state, content, rng) in, applied change +
## result out. state_store.gd wraps these for the running game and owns
## signals/persistence; headless tests call them directly.

## Rarity a Metabolize-built adaptation carries at each tier (1-indexed).
## Pure craft tops out at "rare" — epic/legendary colours require gene expresses
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
## niche requires the lineage to have an equipped express matching each key role.
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


## True if the lineage has at least one equipped express for every affix_key role
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
			for express: Dictionary in inst.affixes:
				var affix_row := content.affix(String(express.get("id", "")))
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
	for mat_id: String in loot["materials"] as Dictionary:
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


## Apply a closed-form Accrual batch to the save (Phase 3.5 WP1). Pure: this one
## helper backs BOTH the real offline path (state_store.apply_offline_accrual) and
## the DEV +8h button, so what an offline gap grants can never drift from a live
## grind. Materials sum; gene events add genes_known copies; splice events bank
## offers — exactly what a live forage does.
static func apply_accrual_batch(state: GameState, batch: Dictionary) -> void:
	var materials: Dictionary = batch.get("materials", {})
	for mat_id: String in materials:
		state.inventory_materials[mat_id] = (
			float(state.inventory_materials.get(mat_id, 0.0)) + float(materials[mat_id])
		)
	for ev: Dictionary in batch.get("events", []) as Array:
		match String(ev.get("kind", "")):
			"gene":
				var gid := String(ev.get("gene", ""))
				if gid != "":
					state.genes_known[gid] = int(state.genes_known.get(gid, 0)) + 1
			"splice":
				state.splice_offers.append(
					{"gene": String(ev.get("gene", "")), "node": String(ev.get("node", ""))}
				)


## Elapsed offline seconds, clamped to [0, cap] (Phase 3.5 WP1, decision D6).
## A clock set backwards → 0; an absurd gap (clock forward, or a very long sleep)
## → cap, so tampering mints at most `cap` of accrual. This clamp is the only
## clock-tamper defense v1 ships (DECISIONS.md 2026-06-13).
static func offline_dt(last_seen_unix: int, now_unix: int, cap: float) -> float:
	return clampf(float(now_unix - last_seen_unix), 0.0, cap)


## Descend the class tree to `class_id`. Sticky: target must be a descendant of
## the lineage's current class_node (or a no-op). Returns {ok, reason}.
## Requirements: each role in requires.affix_keys must be present as an equipped
## express; each gene in requires.genes must be in genes_known (PHASE3.md §3.3).
static func pick_class(
	state: GameState, content: Content, lineage_id: String, class_id: String
) -> Dictionary:
	var l := state.lineage_by_id(lineage_id)
	if l == null:
		return {"ok": false, "reason": "no such lineage"}
	var target := content.class_node(class_id)
	if target.is_empty():
		return {"ok": false, "reason": "no such class '%s'" % class_id}
	if l.class_node == class_id:
		return {"ok": true, "reason": ""}
	# Sticky descent: class_id must have current class_node in its ancestor chain.
	var anc := String(target.get("parent", ""))
	var visited: Dictionary = {}
	var found_current := false
	while anc != "" and not visited.has(anc):
		visited[anc] = true
		if anc == l.class_node:
			found_current = true
			break
		var anc_row := content.class_node(anc)
		if anc_row.is_empty():
			break
		anc = String(anc_row.get("parent", ""))
	if not found_current:
		return {"ok": false, "reason": "classes are sticky — branch a new lineage to respec"}
	# Requirements (shared with Agenda so the gate never drifts): affix_keys present
	# as equipped expresses, and required genes known.
	var unmet := unmet_class_requirement(state, content, l, target)
	if unmet != "":
		return {"ok": false, "reason": unmet}
	l.class_node = class_id
	return {"ok": true, "reason": ""}


## "" if `lineage` meets every requirement of `class_row`; otherwise a short reason
## naming the first unmet one (VISION.md §7: classes are gated by affix-keys and
## genes). Pure and read-only; shared by pick_class and Agenda.
static func unmet_class_requirement(
	state: GameState, content: Content, lineage: Lineage, class_row: Dictionary
) -> String:
	var class_name_str := String(class_row.get("name", class_row.get("id", "")))
	var reqs: Dictionary = class_row.get("requires", {})
	for key: Variant in reqs.get("affix_keys", []):
		var role := String(key)
		var found := false
		for slot: String in lineage.doll:
			var inst_check: AdaptationInstance = lineage.doll[slot]
			for express_d: Dictionary in inst_check.affixes:
				var affix_row := content.affix(String(express_d.get("id", "")))
				if String(affix_row.get("orthogonal_role", "")) == role:
					found = true
					break
			if found:
				break
		if not found:
			return "%s requires an equipped %s adaptation" % [class_name_str, role]
	for gid: Variant in reqs.get("genes", []):
		if int(state.genes_known.get(String(gid), 0)) == 0:
			return "%s requires gene '%s'" % [class_name_str, String(gid)]
	return ""


## Branch a fresh lineage (cladogenesis / respec valve). The new lineage starts
## with an empty doll, Generalist class, and the starter node. The account gene
## bank (genes_known) is shared automatically — nothing is copied (PHASE3.md §3.4).
## Returns {ok, reason, lineage?}.
static func branch_lineage(
	state: GameState, content: Content, _parent_id: String, display_name: String
) -> Dictionary:
	var active_count := 0
	for lin: Lineage in state.lineages:
		if not lin.graduated:
			active_count += 1
	if active_count >= state.slots_active:
		return {"ok": false, "reason": "no free roster slot"}
	var new_id := "lin_" + str(state.lineages.size())
	# Ensure uniqueness in the unlikely case of prior deletions / custom saves.
	while state.lineage_by_id(new_id) != null:
		new_id = new_id + "_"
	var l := Lineage.new(new_id, display_name)
	l.class_node = "generalist"
	var nodes: Array = content.tables.get("nodes", [])
	if not nodes.is_empty():
		l.assigned_node = String((nodes[0] as Dictionary).get("id", ""))
	state.lineages.append(l)
	return {"ok": true, "reason": "", "lineage": l}


## Graft an affix onto the equipped adaptation in `slot`. Copies of the
## unlocking gene cap the express tier; copies are never consumed.
## Returns {ok, reason, instance?}.
static func express(
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
	# Slot affinity: a gene only expresses on anatomically valid organs (VISION §7).
	if not affix_allows_slot(affix_row, slot):
		return {
			"ok": false,
			"reason":
			"%s does not fit %s" % [String(affix_row.get("name", affix_id)), _slot_label(slot)]
		}
	# Category eligibility gate (PHASE3.md §3.2).
	var cat := String(affix_row.get("category", "generalist"))
	if not content.allowed_categories(l).has(cat):
		var class_row := content.class_node(l.class_node)
		var class_name_str := String(class_row.get("name", l.class_node))
		return {
			"ok": false,
			"reason":
			"%s cannot build %s" % [class_name_str, String(affix_row.get("name", affix_id))]
		}
	var gene_row := content.gene_for_affix(affix_id)
	if gene_row.is_empty():
		return {"ok": false, "reason": "no gene unlocks '%s'" % affix_id}
	var gene_id := String(gene_row.get("id", ""))
	var copies := int(state.genes_known.get(gene_id, 0))
	var current_tier := inst.express_tier(affix_id)
	# Per-organ cap: a NEW affix needs a free expression slot on this organ; a
	# tier-up of an affix already present never does (VISION §7). The trade-off:
	# an organ is venomous OR armoured, not everything at once.
	if current_tier == 0 and inst.affixes.size() >= slot_express_cap(slot):
		return {
			"ok": false,
			"reason": "%s is full (%d genes max)" % [_slot_label(slot), slot_express_cap(slot)]
		}
	var target := current_tier + 1
	if copies < target:
		var gene_name := String(gene_row.get("name", gene_id))
		return {
			"ok": false,
			"reason": "need another %s copy (have %d, need %d)" % [gene_name, copies, target]
		}
	var gc: Dictionary = affix_row.get("express_cost", {})
	var mat := String(gc.get("material", ""))
	if mat == "":
		return {"ok": false, "reason": "affix '%s' has no express_cost" % affix_id}
	var cost_qty := roundf(
		float(gc.get("base", 0.0)) * pow(float(gc.get("growth", 1.0)), target - 1)
	)
	if float(state.inventory_materials.get(mat, 0.0)) < cost_qty:
		return {"ok": false, "reason": "not enough %s" % mat}
	state.inventory_materials[mat] = float(state.inventory_materials.get(mat, 0.0)) - cost_qty

	# Apply or upgrade the express
	var found := false
	for express: Dictionary in inst.affixes:
		if String(express.get("id", "")) == affix_id:
			express["tier"] = target
			found = true
			break
	if not found:
		inst.affixes.append({"id": affix_id, "tier": target})

	inst.rarity = _compute_rarity(inst, content)
	return {"ok": true, "reason": "", "instance": inst}


## Metabolize (VISION.md §8): spend materials to build or tier-up an adaptation
## and socket it into its doll slot. Preserves any existing expresses on tier-up.
static func metabolize(
	state: GameState, content: Content, lineage_id: String, adaptation_id: String
) -> Dictionary:
	var l := state.lineage_by_id(lineage_id)
	if l == null:
		return {"ok": false, "reason": "no such lineage"}
	var def := content.adaptation(adaptation_id)
	if def.is_empty():
		return {"ok": false, "reason": "no such adaptation"}
	# Category eligibility gate (PHASE3.md §3.2).
	var cat := String(def.get("category", "generalist"))
	if not content.allowed_categories(l).has(cat):
		var class_row := content.class_node(l.class_node)
		var class_name_str := String(class_row.get("name", l.class_node))
		return {
			"ok": false,
			"reason":
			"%s cannot build %s" % [class_name_str, String(def.get("name", adaptation_id))]
		}

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
	# Preserve existing expresses: rarity recomputes including them.
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


## True if `affix_row` may be expressed on `slot`. A row with no `slots` list is
## treated as unrestricted (defensive; real content declares slots — gate 1).
static func affix_allows_slot(affix_row: Dictionary, slot: String) -> bool:
	var slots: Array = affix_row.get("slots", [])
	return slots.is_empty() or slots.has(slot)


## How many distinct affixes `slot` can hold (Lineage.SLOT_EXPRESS_CAP).
static func slot_express_cap(slot: String) -> int:
	return int(Lineage.SLOT_EXPRESS_CAP.get(slot, 99))


static func _slot_label(slot: String) -> String:
	return slot.replace("_", " ").capitalize()


## Rarity of an adaptation instance: legendary if any express's unlocking gene is
## legendary; epic if any express exists; otherwise the tier colour (capped rare).
static func _compute_rarity(inst: AdaptationInstance, content: Content) -> String:
	for express: Dictionary in inst.affixes:
		var gene_row := content.gene_for_affix(String(express.get("id", "")))
		if String(gene_row.get("rarity", "")) == "legendary":
			return "legendary"
	if not inst.affixes.is_empty():
		return "epic"
	return TIER_RARITY[mini(inst.tier, TIER_RARITY.size()) - 1]
