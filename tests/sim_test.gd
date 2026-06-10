extends SceneTree

## Headless unit test for the named commands (sim/commands.gd) — the Phase 1
## mutation layer under the UI:
##   godot --headless --script res://tests/sim_test.gd
## Covers the Phase-1 thesis mechanics: forage applies loot deterministically,
## Metabolize charges the data-driven cost and sockets the doll, and equipping
## MEASURABLY changes the next roll (IMPLEMENTATION.md §4 Phase 1).

var _failures: Array[String] = []


func _initialize() -> void:
	var content := Content.load_dir("res://data")
	var errors := Validation.validate(content)
	if not errors.is_empty():
		push_error("content failed validation; aborting sim test")
		for e in errors:
			print("  - " + e)
		quit(1)
		return

	_test_starter_lineage(content)
	_test_forage(content)
	_test_metabolize(content)
	_test_equip_changes_the_roll(content)
	_test_assign_node(content)
	_test_save_roundtrip(content)

	if _failures.is_empty():
		print("== sim test: PASS ==")
		quit(0)
	else:
		print("== sim test: FAIL (%d) ==" % _failures.size())
		for f in _failures:
			print("  - " + f)
		quit(1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures.append(what)


func _fresh_state(content: Content) -> GameState:
	var state := GameState.new()
	state.master_seed = 7
	Commands.add_starter_lineage(state, content)
	return state


func _test_starter_lineage(content: Content) -> void:
	var state := _fresh_state(content)
	_check(state.lineages.size() == 1, "starter: exactly one lineage")
	var l := state.lineages[0]
	_check(l.assigned_node == "microbial_mat", "starter: assigned to the first node")
	_check(Resolve.effective_power(l) == 1.0, "starter: bare power is 1.0")


func _test_forage(content: Content) -> void:
	var state_a := _fresh_state(content)
	var state_b := _fresh_state(content)
	var loot_a := Commands.forage(state_a, content, "main", 60.0, Rng.new(7))
	var loot_b := Commands.forage(state_b, content, "main", 60.0, Rng.new(7))
	_check(not loot_a.is_empty(), "forage: working lineage yields loot")
	_check(
		JSON.stringify(loot_a["materials"]) == JSON.stringify(loot_b["materials"]),
		"forage: same seed, same loot"
	)
	var got: float = float(state_a.inventory_materials.get("biofilm", 0.0))
	_check(got > 0.0, "forage: biofilm landed in the inventory")
	_check(
		is_equal_approx(got, float((loot_a["materials"] as Dictionary).get("biofilm", 0.0))),
		"forage: inventory matches the loot dict"
	)

	var idle := GameState.new()
	Commands.add_starter_lineage(idle, content)
	idle.lineages[0].assigned_node = ""
	var none := Commands.forage(idle, content, "main", 60.0, Rng.new(7))
	_check(none.is_empty(), "forage: unassigned lineage yields nothing")


func _test_metabolize(content: Content) -> void:
	var state := _fresh_state(content)
	var l := state.lineages[0]

	var broke := Commands.metabolize(state, content, "main", "frontal_appendage")
	_check(not broke["ok"], "metabolize: rejected with an empty stash")

	# Tier 1 -> 2 -> 3 at 60/180/540 biofilm, then maxed.
	state.inventory_materials["biofilm"] = 780.0
	for expect_tier in [1, 2, 3]:
		var r := Commands.metabolize(state, content, "main", "frontal_appendage")
		_check(r["ok"], "metabolize: tier %d build accepted" % expect_tier)
		var inst: AdaptationInstance = l.doll.get("mouthparts")
		_check(
			inst != null and inst.tier == expect_tier, "metabolize: doll at tier %d" % expect_tier
		)
	var inst: AdaptationInstance = l.doll.get("mouthparts")
	_check(inst.rarity == "rare", "metabolize: tier 3 wears the 'rare' colour")
	_check(
		is_zero_approx(float(state.inventory_materials.get("biofilm", 0.0))),
		"metabolize: exact cost charged (60+180+540)"
	)
	var maxed := Commands.metabolize(state, content, "main", "frontal_appendage")
	_check(
		not maxed["ok"] and maxed["reason"] == "already at max tier",
		"metabolize: max tier enforced"
	)
	_check(Resolve.effective_power(l) == 4.0, "metabolize: power 1 + tier 3 = 4")


func _test_equip_changes_the_roll(content: Content) -> void:
	# The Phase 1 gate in miniature: vs the defended anemone, the same lineage
	# must yield measurably more after equipping (VISION.md §8 design note).
	var state := _fresh_state(content)
	var l := state.lineages[0]
	var node := content.node("sea_anemone")
	var before := Resolve.material_rate(l, node)
	state.inventory_materials["biofilm"] = 60.0
	Commands.metabolize(state, content, "main", "frontal_appendage")
	var after := Resolve.material_rate(l, node)
	_check(after > before, "equip: material rate rises against the defended node")
	_check(Resolve.gene_rate(l, node) == 0.0, "equip: chase stays closed until the matchup is won")
	state.inventory_materials["biofilm"] = 720.0
	Commands.metabolize(state, content, "main", "frontal_appendage")
	Commands.metabolize(state, content, "main", "frontal_appendage")
	_check(Resolve.gene_rate(l, node) > 0.0, "equip: winning the matchup opens the chase")


func _test_assign_node(content: Content) -> void:
	var state := _fresh_state(content)
	_check(
		Commands.assign_node(state, content, "main", "sea_anemone"), "assign: valid node accepted"
	)
	_check(state.lineages[0].assigned_node == "sea_anemone", "assign: lineage points at it")
	_check(
		not Commands.assign_node(state, content, "main", "kraken"), "assign: unknown node rejected"
	)
	_check(state.lineages[0].assigned_node == "sea_anemone", "assign: rejection changes nothing")


func _test_save_roundtrip(content: Content) -> void:
	var state := _fresh_state(content)
	state.inventory_materials["biofilm"] = 240.0
	Commands.metabolize(state, content, "main", "frontal_appendage")
	Commands.metabolize(state, content, "main", "frontal_appendage")
	var rng := Rng.new(7)
	Commands.forage(state, content, "main", 60.0, rng)
	state.rng_streams = rng.export_state()

	var copy := GameState.from_dict(state.to_dict())
	var inst: AdaptationInstance = copy.lineages[0].doll.get("mouthparts")
	_check(inst != null and inst.tier == 2, "roundtrip: doll tier survives")
	_check(inst != null and inst.rarity == "uncommon", "roundtrip: rarity survives")
	_check(
		JSON.stringify(copy.inventory_materials) == JSON.stringify(state.inventory_materials),
		"roundtrip: inventory survives"
	)

	# A restored Rng must continue the sequence, not replay it.
	var resumed := Rng.new(7)
	resumed.import_state(copy.rng_streams)
	var replayed := Rng.new(7)
	var streams: Array = copy.rng_streams.keys()
	_check(not streams.is_empty(), "roundtrip: rng stream state was captured")
	if not streams.is_empty():
		var s := String(streams[0])
		_check(
			resumed.stream(s).state != replayed.stream(s).state,
			"roundtrip: restored stream continues instead of replaying"
		)
