extends SceneTree

## Headless unit test for the skill spine (WP1, WORKORDER_PROGRESSION_SPINE.md):
##   godot --headless --script res://tests/skill_test.gd
##
## Skills are the PROFICIENCY layer — XP, the level curve, the activity yield
## multiplier, and Fortitude's danger mitigation. Power stays the doll and gene
## rate is untouched (the chase is doll + genes), so these assert only the
## proficiency math; the chase shape is the economy harness's job.

var _failures: Array[String] = []


func _initialize() -> void:
	var content := Content.load_dir("res://data")
	var errors := Validation.validate(content)
	if not errors.is_empty():
		push_error("content failed validation; aborting skill test")
		for e in errors:
			print("  - " + e)
		quit(1)
		return

	_test_skill_level_curve()
	_test_skill_xp_awarded(content)
	_test_skill_yield_mult(content)
	_test_skill_fortitude_mitigates_danger(content)
	_test_skill_gates_node(content)
	_test_skill_gates_organ(content)

	if _failures.is_empty():
		print("== skill test: PASS ==")
		quit(0)
	else:
		print("== skill test: FAIL (%d) ==" % _failures.size())
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


## The level curve: untrained is level 1, BASE xp reaches level 2, huge xp caps.
func _test_skill_level_curve() -> void:
	_check(Resolve.level_for_xp(0.0) == 1, "skill curve: 0 xp is level 1")
	_check(Resolve.level_for_xp(Resolve.SKILL_XP_BASE) == 2, "skill curve: BASE xp reaches level 2")
	_check(
		Resolve.level_for_xp(1.0e12) == Resolve.SKILL_LEVEL_CAP,
		"skill curve: capped at the level cap"
	)


## Working a node trains the skill that governs its kind, not the others.
func _test_skill_xp_awarded(content: Content) -> void:
	var state := _fresh_state(content)  # "main" works microbial_mat (eat) -> Foraging
	var l := state.lineages[0]
	Commands.forage(state, content, "main", 600.0, Rng.new(7))
	_check(float(l.skills.get("foraging", 0.0)) > 0.0, "skill xp: foraging trains on an eat node")
	_check(float(l.skills.get("hunting", 0.0)) == 0.0, "skill xp: hunting idle on an eat node")


## A yield skill raises its node kind's material rate; level 1 is no bonus.
func _test_skill_yield_mult(content: Content) -> void:
	var node := content.node("microbial_mat")
	var l := Lineage.new("s", "S")
	var base := Resolve.material_rate(l, node, content)
	_check(
		is_equal_approx(Resolve.skill_yield_mult(l, node, content), 1.0),
		"skill yield: level 1 is no bonus"
	)
	l.skills["foraging"] = 1.0e9  # cap Foraging
	var boosted := Resolve.material_rate(l, node, content)
	_check(boosted > base, "skill yield: high Foraging raises eat-node material rate")


## Fortitude blunts the danger tax (raises the danger factor toward 1.0).
func _test_skill_fortitude_mitigates_danger(content: Content) -> void:
	var node := content.node("sea_anemone")  # fight, danger 2
	var l := Lineage.new("f", "F")
	var base := Resolve.danger_factor(l, node, content)
	l.skills["fortitude"] = 1.0e9  # cap Fortitude
	var mitigated := Resolve.danger_factor(l, node, content)
	_check(mitigated > base, "skill fortitude: training raises the danger factor")
	_check(mitigated <= 1.0, "skill fortitude: danger factor never exceeds 1.0")


## Skills gate node access (the ladder) — assign_node refuses an under-skilled node.
func _test_skill_gates_node(content: Content) -> void:
	var state := _fresh_state(content)
	var l := state.lineages[0]
	_check(
		not Commands.assign_node(state, content, "main", "anomalocaris"),
		"ladder: anomalocaris locked without Hunting 10"
	)
	l.skills["hunting"] = 1.0e9  # cap Hunting
	_check(
		Commands.assign_node(state, content, "main", "anomalocaris"),
		"ladder: anomalocaris opens at Hunting 10"
	)


## Skills gate organ-building — metabolize refuses an under-skilled adaptation.
func _test_skill_gates_organ(content: Content) -> void:
	var state := _fresh_state(content)
	var l := state.lineages[0]
	state.inventory_materials["soft_tissue"] = 999.0
	var blocked := Commands.metabolize(state, content, "main", "calcite_carapace")
	_check(not blocked["ok"], "organ-gate: calcite carapace locked without Fortitude 2")
	l.skills["fortitude"] = 1.0e9  # cap Fortitude
	var ok := Commands.metabolize(state, content, "main", "calcite_carapace")
	_check(ok["ok"], "organ-gate: calcite carapace builds at Fortitude 2")
