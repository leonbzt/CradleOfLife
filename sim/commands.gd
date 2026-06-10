class_name Commands
extends RefCounted

## Every mutation of GameState is a named command here (arch §2: replayable,
## testable). Pure and Node-free: (state, content, rng) in, applied change +
## result out. state_store.gd wraps these for the running game and owns
## signals/persistence; headless tests call them directly.

## Rarity colour a Metabolize-built adaptation carries at each tier (1-indexed).
## Crafted gear tops out at "rare" — epic/legendary colours are reserved for the
## gene chase (VISION.md §9: materials common→rare, genes rare→legendary).
const TIER_RARITY: Array[String] = ["common", "uncommon", "rare"]


## Starts the Tree: one starter lineage, assigned to the first (undefended)
## node in content. Roster growth is Phase 3; Phase 1 plays one lineage.
static func add_starter_lineage(state: GameState, content: Content) -> Lineage:
	var l := Lineage.new("main", "Your Main")
	var nodes: Array = content.tables.get("nodes", [])
	if not nodes.is_empty():
		l.assigned_node = String((nodes[0] as Dictionary).get("id", ""))
	state.lineages.append(l)
	return l


## Point the lineage at a different node. No gating: any matchup may be
## attempted; a losing one just yields poorly (the defense check is felt in the
## roll, not hidden behind a lock).
static func assign_node(
	state: GameState, content: Content, lineage_id: String, node_id: String
) -> bool:
	var l := state.lineage_by_id(lineage_id)
	if l == null or content.node(node_id).is_empty():
		return false
	l.assigned_node = node_id
	return true


## One foraging action of `dt` seconds against the lineage's assigned node,
## resolved by the one resolve() and applied to the save. Returns the loot
## (empty if the lineage isn't working). Gene drops are banked on the save for
## Phase 2 — Phase 1 surfaces no gene UI.
static func forage(
	state: GameState, content: Content, lineage_id: String, dt: float, rng: Rng
) -> Dictionary:
	var l := state.lineage_by_id(lineage_id)
	if l == null or l.graduated or l.assigned_node == "":
		return {}
	var node := content.node(l.assigned_node)
	if node.is_empty():
		return {}
	var loot := Resolve.resolve(l, node, dt, rng)
	var mats: Dictionary = loot["materials"]
	for mat_id: String in mats:
		var have: float = float(state.inventory_materials.get(mat_id, 0.0))
		state.inventory_materials[mat_id] = have + float(mats[mat_id])
	var gene: Dictionary = loot["gene"]
	if not gene.is_empty():
		state.inventory_genes.append(String(gene.get("id", "")))
	return loot


## Metabolize (VISION.md §8): spend materials to build the adaptation at tier 1,
## or raise the equipped one a tier, and socket it into its doll slot. Returns
## {ok, reason, instance}.
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
		var have: float = float(state.inventory_materials.get(mat_id, 0.0))
		state.inventory_materials[mat_id] = have - float(cost[mat_id])

	var slot := String(def.get("slot", ""))
	var inst: AdaptationInstance = l.doll.get(slot)
	if inst == null or inst.def_id != adaptation_id:
		inst = AdaptationInstance.new(adaptation_id, tier)
	inst.tier = tier
	inst.rarity = TIER_RARITY[mini(tier, TIER_RARITY.size()) - 1]
	l.equip(slot, inst)
	return {"ok": true, "reason": "", "instance": inst}


## The tier the next Metabolize of `def` would produce: 1 if the slot holds
## nothing (or a different adaptation), current+1 if it holds this one, or 0 if
## it is already at max_tier.
static func next_tier(lineage: Lineage, def: Dictionary) -> int:
	var inst: AdaptationInstance = lineage.doll.get(String(def.get("slot", "")))
	if inst == null or inst.def_id != String(def.get("id", "")):
		return 1
	if inst.tier >= int(def.get("max_tier", 1)):
		return 0
	return inst.tier + 1


## Material cost to metabolize `def` at `tier`: base · growth^(tier-1), rounded
## to whole units so the price is legible. Returns {material_id: qty}.
static func metabolize_cost(def: Dictionary, tier: int) -> Dictionary:
	var cost: Dictionary = def.get("build_cost", {})
	var mat := String(cost.get("material", ""))
	if mat == "":
		return {}
	var qty := float(cost.get("base", 0.0)) * pow(float(cost.get("growth", 1.0)), tier - 1)
	return {mat: roundf(qty)}
