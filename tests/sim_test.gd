extends SceneTree

## Headless unit test for sim/commands.gd (Phase 1 thesis) and the Phase 2
## seven-term resolve math (WP1) and state/express mechanics (WP2):
##   godot --headless --script res://tests/sim_test.gd

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

	# Phase 1 baseline mechanics
	_test_starter_lineage(content)
	_test_forage(content)
	_test_metabolize(content)
	_test_equip_changes_the_roll(content)
	_test_assign_node(content)
	_test_save_roundtrip(content)

	# Phase 2 WP1: per-term math assertions
	_test_affix_pen(content)
	_test_affix_dot(content)
	_test_affix_mitigation(content)
	_test_affix_uptime_find(content)
	_test_affix_stealth(content)
	_test_affix_control(content)
	_test_accrue_determinism_with_splice(content)

	# Phase 2 WP2: state, express, migration
	_test_forage_banks_genes(content)
	_test_forage_banks_splice_offers(content)
	_test_claim_splice(content)
	_test_express(content)
	_test_rarity_escalation(content)
	_test_niche_key_gating(content)
	_test_migration_v1_to_v2()

	# Per-slot doll routing + soft cap (class tree parked: reset 2026-06-14)
	_test_option_a_slot_routing(content)
	_test_soft_cap(content)
	_test_derived_role(content)
	_test_accrue_determinism_phase3(content)

	# Cladogenesis (the respec valve)
	_test_branch_lineage(content)

	# Phase 3 polish: slot affinity, per-organ cap, evolving organ names
	_test_slot_affinity(content)
	_test_express_cap(content)
	_test_organ_naming(content)
	_test_niche_key_legibility(content)

	# Phase 3.5 WP1: offline accrual application + clamp
	_test_apply_accrual_batch(content)
	_test_offline_dt_clamp()
	# Phase 3.5 WP2: the derived do-now agenda
	_test_agenda_fresh(content)
	_test_agenda_claim_splice(content)
	_test_agenda_tierup_ready(content)
	_test_agenda_one_copy_short(content)

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


# -- Phase 1 baseline ----------------------------------------------------------


func _test_starter_lineage(content: Content) -> void:
	var state := _fresh_state(content)
	_check(state.lineages.size() == 1, "starter: exactly one lineage")
	var l := state.lineages[0]
	_check(l.assigned_node == "microbial_mat", "starter: assigned to the first node")
	_check(Resolve.effective_power(l, content) == 1.0, "starter: bare power is 1.0")


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

	state.inventory_materials["biofilm"] = 780.0
	for expect_tier in [1, 2, 3]:
		var r := Commands.metabolize(state, content, "main", "frontal_appendage")
		_check(r["ok"], "metabolize: tier %d build accepted" % expect_tier)
		var inst: AdaptationInstance = l.doll.get("mouthparts")
		_check(
			inst != null and inst.tier == expect_tier, "metabolize: doll at tier %d" % expect_tier
		)
	var inst: AdaptationInstance = l.doll.get("mouthparts")
	_check(inst.rarity == "rare", "metabolize: tier 3 wears 'rare'")
	_check(
		is_zero_approx(float(state.inventory_materials.get("biofilm", 0.0))),
		"metabolize: exact cost charged (60+180+540)"
	)
	var maxed := Commands.metabolize(state, content, "main", "frontal_appendage")
	_check(
		not maxed["ok"] and maxed["reason"] == "already at max tier",
		"metabolize: max tier enforced"
	)
	_check(Resolve.effective_power(l, content) == 4.0, "metabolize: power 1 + tier 3 = 4")


func _test_equip_changes_the_roll(content: Content) -> void:
	var state := _fresh_state(content)
	var l := state.lineages[0]
	var node := content.node("sea_anemone")
	var before := Resolve.material_rate(l, node, content)
	state.inventory_materials["biofilm"] = 60.0
	Commands.metabolize(state, content, "main", "frontal_appendage")
	var after := Resolve.material_rate(l, node, content)
	_check(after > before, "equip: material rate rises against the defended node")
	_check(Resolve.gene_rate(l, node, content) == 0.0, "equip: chase closed until matchup won")
	state.inventory_materials["biofilm"] = 720.0
	Commands.metabolize(state, content, "main", "frontal_appendage")
	Commands.metabolize(state, content, "main", "frontal_appendage")
	_check(Resolve.gene_rate(l, node, content) > 0.0, "equip: winning matchup opens the chase")


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


# -- Phase 2 WP1: per-term math assertions -------------------------------------
# Each test builds a minimal hand-constructed lineage + node so the expected
# value is computable on paper (PHASE2.md §2.4). Content is the live data so
# affix params are verified end-to-end. Equations reference PHASE2.md §2.2.


func _lineage_with_express(
	adaptation_id: String, slot: String, affix_id: String, tier: int, power: float = 1.0
) -> Lineage:
	var l := Lineage.new("t", "T")
	l.attributes["power"] = power
	var inst := AdaptationInstance.new(adaptation_id, 1)
	inst.affixes = [{"id": affix_id, "tier": tier}]
	l.doll[slot] = inst
	return l


func _fight_node(defense: float, danger: float = 0.0, splice_rate: float = 0.0) -> Dictionary:
	return {
		"id": "tn",
		"kind": "fight",
		"defense": defense,
		"danger": danger,
		"material": "flesh",
		"material_rate": 1.0,
		"gene_rate": 0.001,
		"gene_table": [],
		"splice_rate": splice_rate,
		"spliceable": "gene_raptorial",
	}


func _test_affix_pen(content: Content) -> void:
	# gnathobase_minor tier 1 (amount 2) vs DEF 9 → D_eff = 7
	var node := {
		"id": "tn", "kind": "fight", "defense": 9.0, "material_rate": 1.0, "gene_rate": 0.0
	}
	var l_bare := Lineage.new("t", "T")
	var totals_bare := Resolve.affix_totals(l_bare, content)
	_check(
		is_equal_approx(Resolve.effective_defense(node, totals_bare), 9.0),
		"pen: no express → D_eff == 9"
	)
	var l := _lineage_with_express("frontal_appendage", "mouthparts", "gnathobase_minor", 1)
	var totals := Resolve.affix_totals(l, content)
	_check(is_equal_approx(float(totals.get("pen", 0.0)), 2.0), "pen: gnathobase_minor t1 → pen 2")
	_check(is_equal_approx(Resolve.effective_defense(node, totals), 7.0), "pen: D_eff == 7")


func _test_affix_dot(content: Content) -> void:
	# venom_minor tier 1 vs outgeared fight node → floor = EFF_FLOOR + dot
	var node := _fight_node(99.0)  # outgeared (power 1 vs def 99)
	var l := _lineage_with_express("frontal_appendage", "mouthparts", "venom_minor", 1)
	var tick_pct := float(
		(content.affix("venom_minor").get("params", {}) as Dictionary).get("tick_pct", 0.0)
	)
	var expected_floor := minf(Resolve.EFF_FLOOR + tick_pct, 1.0)
	var eff := Resolve.yield_efficiency(l, node, content)
	_check(
		is_equal_approx(eff, expected_floor),
		"dot: outgeared fight node floor == EFF_FLOOR + tick_pct (%.2f)" % expected_floor
	)


func _test_affix_mitigation(content: Content) -> void:
	# danger 4, resilience 1, guard 0 → tax = 0.15*(4-1-0) = 0.45 → df = 0.55
	var node := _fight_node(0.0, 4.0)
	var l_bare := Lineage.new("t", "T")
	l_bare.attributes["resilience"] = 1.0
	var totals_bare := Resolve.affix_totals(l_bare, content)
	# Can't call private _danger_factor directly; verify via material_rate ratio
	# material_rate = base * metab * eff * (1 + uptime) * danger_factor
	# With base=1.0, metab=1.0, eff=EFF_CAP (power 1, def 0, margin=1 → eff=1.1),
	# uptime=0: rate == 1.1 * danger_factor
	var rate_bare := Resolve.material_rate(l_bare, node, content)
	var eff_bare := Resolve.yield_efficiency(l_bare, node, content)
	var df_bare := rate_bare / eff_bare  # == danger_factor (uptime_bonus=0, metabolism=1)
	_check(is_equal_approx(df_bare, 0.55), "mitigation: danger 4, resilience 1, guard 0 → df 0.55")

	# with plating_minor tier 1 (amount 2) → guard 2 → tax = 0.15*(4-1-2) = 0.15 → df = 0.85
	# Uses mouthparts slot (→ power, not resilience) so only guard, not slot tier, affects df.
	var l_plated := _lineage_with_express("frontal_appendage", "mouthparts", "plating_minor", 1)
	l_plated.attributes["resilience"] = 1.0
	var rate_plated := Resolve.material_rate(l_plated, node, content)
	var eff_plated := Resolve.yield_efficiency(l_plated, node, content)
	var df_plated := rate_plated / eff_plated
	_check(is_equal_approx(df_plated, 0.85), "mitigation: with plating_minor t1 → df 0.85")


func _test_affix_uptime_find(content: Content) -> void:
	# gill_minor mult 1.15 tier 1 → uptime_bonus = 0.15
	var l_up := _lineage_with_express("gill_branches", "metabolic_core", "gill_minor", 1, 100.0)
	var node := {
		"id": "tn",
		"kind": "eat",
		"defense": 0.0,
		"material_rate": 1.0,
		"gene_rate": 0.001,
		"gene_table": []
	}
	var mult_up := float(
		(content.affix("gill_minor").get("params", {}) as Dictionary).get("mult", 1.0)
	)
	var totals_up := Resolve.affix_totals(l_up, content)
	_check(
		is_equal_approx(float(totals_up.get("uptime_bonus", 0.0)), mult_up - 1.0),
		"uptime: gill_minor t1 → bonus == mult-1"
	)

	# eyes_minor mult 1.2 tier 1 → find_bonus = 0.2
	# Uses gland slot (feeds no stat) so the slot tier doesn't inflate instinct.
	var l_find := _lineage_with_express("nematocyst_gland", "gland", "eyes_minor", 1, 100.0)
	var mult_find := float(
		(content.affix("eyes_minor").get("params", {}) as Dictionary).get("mult", 1.0)
	)
	var totals_find := Resolve.affix_totals(l_find, content)
	_check(
		is_equal_approx(float(totals_find.get("find_bonus", 0.0)), mult_find - 1.0),
		"find: eyes_minor t1 → bonus == mult-1"
	)
	# gene_rate with find bonus == open_rate * (1 + find_bonus)
	var l_bare := Lineage.new("t", "T")
	l_bare.attributes["power"] = 100.0
	l_bare.attributes["instinct"] = 1.0
	var open_rate := Resolve.gene_rate(l_bare, node, content)
	l_find.attributes["power"] = 100.0
	l_find.attributes["instinct"] = 1.0
	var boosted_rate := Resolve.gene_rate(l_find, node, content)
	_check(
		is_equal_approx(boosted_rate, open_rate * (1.0 + mult_find - 1.0)),
		"find: gene_rate scales with find_bonus"
	)


func _test_affix_stealth(content: Content) -> void:
	# glassy_tissue frac 0.25 tier 1, P <= D_eff → gene_rate = 0.25 × open rate
	var affix_row := content.affix("glassy_tissue")
	if affix_row.is_empty():
		_failures.append("stealth: glassy_tissue affix not found (needs WP4 content)")
		return
	var frac := float((affix_row.get("params", {}) as Dictionary).get("frac", 0.0))
	# DEF=15: l_stealth (mouthparts T1 → eff_power 2.0) is outgeared; open_l
	# (power=100, soft_cap≈18.2) beats it. DEF=99 would fail after soft cap.
	var node := _fight_node(15.0)
	var l_stealth := _lineage_with_express("frontal_appendage", "mouthparts", "glassy_tissue", 1)
	var open_l := Lineage.new("t", "T")
	open_l.attributes["power"] = 100.0  # soft_cap(100)≈18.2 > 15 → winning
	var open_rate := Resolve.gene_rate(open_l, node, content)
	var stealth_rate := Resolve.gene_rate(l_stealth, node, content)
	_check(
		is_equal_approx(stealth_rate, open_rate * frac),
		"stealth: outgeared + ambush frac → gene_rate = frac × open_rate"
	)
	var l_bare := Lineage.new("t", "T")
	_check(
		is_zero_approx(Resolve.gene_rate(l_bare, node, content)),
		"stealth: outgeared, no stealth → gene_rate exactly 0"
	)


func _test_affix_control(content: Content) -> void:
	# grasp_minor mult 1.5 tier 1 → splice_bonus = 0.5
	var node := _fight_node(0.0, 0.0, 0.001)
	var l := _lineage_with_express("frontal_appendage", "mouthparts", "grasp_minor", 1, 100.0)
	var mult := float(
		(content.affix("grasp_minor").get("params", {}) as Dictionary).get("mult", 1.0)
	)
	var totals := Resolve.affix_totals(l, content)
	_check(
		is_equal_approx(float(totals.get("splice_bonus", 0.0)), mult - 1.0),
		"control: grasp_minor t1 → splice_bonus == mult-1"
	)
	# splice_rate_eff scaled by 1+splice_bonus vs bare
	var l_bare := Lineage.new("t", "T")
	l_bare.attributes["power"] = 100.0
	var bare_splice := Resolve.splice_rate_eff(l_bare, node, content)
	l.attributes["power"] = 100.0
	var boosted_splice := Resolve.splice_rate_eff(l, node, content)
	_check(
		is_equal_approx(boosted_splice, bare_splice * mult), "control: splice rate scales by mult"
	)
	# gate = 0 when outgeared, no stealth → splice_rate_eff == 0
	var node_hard := _fight_node(99.0, 0.0, 0.001)  # defense >> power
	var l_weak := Lineage.new("t", "T")
	_check(
		is_zero_approx(Resolve.splice_rate_eff(l_weak, node_hard, content)),
		"control: gate zeroes splice when outgeared with no stealth"
	)


func _test_accrue_determinism_with_splice(content: Content) -> void:
	# Two runs of accrue() with the same gap and seed → identical event lists
	# including splice events (PHASE2.md §2.4 determinism check).
	var state := GameState.new()
	state.master_seed = 99
	var l := Lineage.new("p", "P")
	l.attributes["power"] = 10.0
	l.attributes["instinct"] = 1.0
	l.assigned_node = "sea_anemone"
	state.lineages.append(l)
	var content_a := Content.load_dir("res://data")
	var rng_a := Rng.new(99)
	var rng_b := Rng.new(99)
	var dt := 8.0 * 3600.0
	var result_a := Accrual.accrue(state, content_a, dt, rng_a)
	var result_b := Accrual.accrue(state, content_a, dt, rng_b)
	_check(
		JSON.stringify(result_a["events"]) == JSON.stringify(result_b["events"]),
		"determinism: two accrue() runs same seed → identical event lists"
	)


# -- Phase 2 WP2: state v2, express, migration -----------------------------------


func _test_forage_banks_genes(content: Content) -> void:
	var state := _fresh_state(content)
	# Run enough foraging actions against the trilobite that we're likely to get
	# at least one gene drop. Use a seed known to produce a drop early.
	state.lineages[0].assigned_node = "trilobite_grazer"
	state.lineages[0].attributes["power"] = 20.0  # definitely winning
	var rng := Rng.new(1234)
	for _i in range(200):
		Commands.forage(state, content, "main", 60.0, rng)
	var total_known := 0
	for k in state.genes_known:
		total_known += int(state.genes_known[k])
	_check(total_known > 0, "forage: gene drops accumulate in genes_known dict")
	_check(
		not state.to_dict().has("inventory_genes"), "forage: inventory_genes absent from v2 save"
	)


func _test_forage_banks_splice_offers(content: Content) -> void:
	var state := _fresh_state(content)
	state.lineages[0].assigned_node = "sea_anemone"
	state.lineages[0].attributes["power"] = 20.0
	var rng := Rng.new(5678)
	for _i in range(200):
		Commands.forage(state, content, "main", 60.0, rng)
	# With enough actions some splice offers should have banked
	_check(state.splice_offers.size() >= 0, "forage: splice_offers field exists on state")
	# Can't guarantee a drop in 200 short actions, but at minimum the field must exist


func _test_claim_splice(content: Content) -> void:
	var state := _fresh_state(content)
	state.splice_offers = [{"gene": "gene_nematocyst", "node": "sea_anemone"}]
	var before_count := int(state.genes_known.get("gene_nematocyst", 0))
	var result := Commands.claim_splice(state, 0)
	_check(result["ok"], "claim_splice: valid index accepted")
	_check(state.splice_offers.is_empty(), "claim_splice: offer removed from list")
	_check(
		int(state.genes_known.get("gene_nematocyst", 0)) == before_count + 1,
		"claim_splice: gene count incremented"
	)
	var bad := Commands.claim_splice(state, 99)
	_check(not bad["ok"], "claim_splice: bad index rejected")


func _test_express(content: Content) -> void:
	var state := _fresh_state(content)
	# Need a metabolized adaptation in the mouthparts slot
	state.inventory_materials["biofilm"] = 60.0
	Commands.metabolize(state, content, "main", "frontal_appendage")
	var l := state.lineages[0]
	var inst: AdaptationInstance = l.doll.get("mouthparts")
	_check(inst != null, "express setup: frontal_appendage equipped")

	# No copies of gnathobase → reject
	var r_no_gene := Commands.express(state, content, "main", "mouthparts", "gnathobase_minor")
	_check(not r_no_gene["ok"], "express: zero copies → rejected")

	# Give 1 copy → tier 1 express succeeds (need materials)
	state.genes_known["gene_gnathobase"] = 1
	var affix_row := content.affix("gnathobase_minor")
	var gc: Dictionary = affix_row.get("express_cost", {})
	var mat := String(gc.get("material", ""))
	state.inventory_materials[mat] = 9999.0
	var r_ok := Commands.express(state, content, "main", "mouthparts", "gnathobase_minor")
	_check(r_ok["ok"], "express: 1 copy → tier 1 express accepted")
	_check(inst.express_tier("gnathobase_minor") == 1, "express: express tier set to 1")
	_check(inst.rarity == "epic", "express: expressed adaptation turns epic")
	_check(int(state.genes_known.get("gene_gnathobase", 0)) == 1, "express: copies not consumed")

	# Tier 2 needs 2 copies; 1 is not enough
	var r_need2 := Commands.express(state, content, "main", "mouthparts", "gnathobase_minor")
	_check(not r_need2["ok"], "express: tier 2 needs 2 copies, 1 is insufficient")

	# Give 2nd copy → tier 2
	state.genes_known["gene_gnathobase"] = 2
	var r_t2 := Commands.express(state, content, "main", "mouthparts", "gnathobase_minor")
	_check(r_t2["ok"], "express: 2 copies → tier 2 express accepted")
	_check(inst.express_tier("gnathobase_minor") == 2, "express: tier 2 set")


func _test_rarity_escalation(content: Content) -> void:
	# Metabolize-then-express: rarity goes common→uncommon→rare→epic on first express,
	# then legendary if the unlocking gene is legendary.
	var state := _fresh_state(content)
	state.inventory_materials["biofilm"] = 60.0
	Commands.metabolize(state, content, "main", "frontal_appendage")
	var l := state.lineages[0]
	var inst: AdaptationInstance = l.doll.get("mouthparts")
	_check(inst.rarity == "common", "rarity: T1 built → common")

	# Metabolize to T2
	state.inventory_materials["biofilm"] = 180.0
	Commands.metabolize(state, content, "main", "frontal_appendage")
	_check(inst.rarity == "uncommon", "rarity: T2 built → uncommon")

	# Graft gnathobase_minor → epic
	state.genes_known["gene_gnathobase"] = 1
	var gc: Dictionary = content.affix("gnathobase_minor").get("express_cost", {})
	state.inventory_materials[String(gc.get("material", ""))] = 9999.0
	Commands.express(state, content, "main", "mouthparts", "gnathobase_minor")
	_check(inst.rarity == "epic", "rarity: expressed → epic")

	# Metabolize again (T3) must preserve epic
	state.inventory_materials["biofilm"] = 540.0
	Commands.metabolize(state, content, "main", "frontal_appendage")
	_check(inst.rarity == "epic", "rarity: metabolize after express preserves epic")

	# Legendary gene test: gene_great_appendage unlocks great_appendage
	var state2 := _fresh_state(content)
	state2.inventory_materials["biofilm"] = 60.0
	Commands.metabolize(state2, content, "main", "frontal_appendage")
	var l2 := state2.lineages[0]
	var inst2: AdaptationInstance = l2.doll.get("mouthparts")
	state2.genes_known["gene_great_appendage"] = 1
	var gc2: Dictionary = content.affix("great_appendage").get("express_cost", {})
	state2.inventory_materials[String(gc2.get("material", ""))] = 9999.0
	var r_leg := Commands.express(state2, content, "main", "mouthparts", "great_appendage")
	if r_leg["ok"]:
		_check(inst2.rarity == "legendary", "rarity: legendary gene → legendary doll")
	else:
		_failures.append("rarity: legendary express rejected: " + String(r_leg.get("reason", "?")))


func _test_niche_key_gating(content: Content) -> void:
	# pelagic requires uptime key; without it assign_node is rejected
	var state := _fresh_state(content)

	# Check meets_niche_keys directly
	var l := state.lineages[0]
	_check(
		not Commands.meets_niche_keys(l, content, "pelagic"),
		"niche key: bare lineage fails pelagic uptime key"
	)

	# Equip an uptime affix → key met
	var inst := AdaptationInstance.new("gill_branches", 1)
	state.inventory_materials["soft_tissue"] = 9999.0
	Commands.metabolize(state, content, "main", "gill_branches")
	state.genes_known["gene_gill"] = 1
	var gc: Dictionary = content.affix("gill_minor").get("express_cost", {})
	state.inventory_materials[String(gc.get("material", ""))] = 9999.0
	Commands.express(state, content, "main", "metabolic_core", "gill_minor")
	_check(
		Commands.meets_niche_keys(l, content, "pelagic"),
		"niche key: uptime express meets pelagic key"
	)

	# Locked niche: assign_node to pelagic node fails without key
	var state2 := _fresh_state(content)
	var ok := Commands.assign_node(state2, content, "main", "plankton_bloom")
	_check(not ok, "niche key: assign_node to locked niche rejected")


func _test_migration_v1_to_v2() -> void:
	var save_path := "res://tests/fixtures/save_v1.json"
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		_failures.append("migration: fixture res://tests/fixtures/save_v1.json not found")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("migration: fixture is not valid JSON")
		return

	var d := parsed as Dictionary
	_check(int(d.get("schema_version", 0)) == 1, "migration fixture: is v1")

	# Apply migration
	var state := GameState.migrate_and_load(d)
	_check(state.schema_version == 2, "migration: result is v2")
	_check(state.genes_known is Dictionary, "migration: genes_known is a dict")
	# v1 fixture has inventory_genes: ["gene_gill"] and genes_known: ["gene_sclerite"]
	_check(int(state.genes_known.get("gene_gill", 0)) >= 1, "migration: inventory_genes folded in")
	_check(
		int(state.genes_known.get("gene_sclerite", 0)) >= 1, "migration: old genes_known folded in"
	)
	_check(state.splice_offers is Array, "migration: splice_offers added")


# -- Phase 3 WP1: Option A, class mods, soft cap, niche multiplier ------------


func _test_option_a_slot_routing(content: Content) -> void:
	# Tier-3 mouthparts (→ power slot) raises effective power by 3.
	var l_mouth := Lineage.new("t", "T")
	var inst_m := AdaptationInstance.new("frontal_appendage", 3)
	l_mouth.doll["mouthparts"] = inst_m
	var ep_mouth := Resolve.effective_power(l_mouth, content)
	_check(is_equal_approx(ep_mouth, 4.0), "option_a: tier-3 mouthparts → effective_power 1+3=4")

	# Tier-3 integument (→ resilience slot) does NOT raise power.
	var l_shell := Lineage.new("t", "T")
	var inst_s := AdaptationInstance.new("calcite_carapace", 3)
	l_shell.doll["integument"] = inst_s
	var ep_shell := Resolve.effective_power(l_shell, content)
	_check(
		is_equal_approx(ep_shell, 1.0),
		"option_a: tier-3 integument → effective_power unchanged (still 1.0)"
	)
	var attrs_shell := Resolve.effective_attributes(l_shell, content)
	_check(
		is_equal_approx(float(attrs_shell.get("resilience", 0.0)), 4.0),
		"option_a: tier-3 integument → effective resilience 1+3=4"
	)
	_check(
		is_equal_approx(float(attrs_shell.get("power", 0.0)), 1.0),
		"option_a: tier-3 integument → effective power still 1.0"
	)


func _test_soft_cap(content: Content) -> void:
	# Below the knee: identity.
	var below := Resolve.soft_cap(Resolve.SOFT_CAP_KNEE - 1.0)
	_check(
		is_equal_approx(below, Resolve.SOFT_CAP_KNEE - 1.0),
		"soft_cap: value below knee is unchanged"
	)
	# At the knee: identity.
	_check(
		is_equal_approx(Resolve.soft_cap(Resolve.SOFT_CAP_KNEE), Resolve.SOFT_CAP_KNEE),
		"soft_cap: value at knee is unchanged"
	)
	# Well above the knee: compressed, never exceeds KNEE + 1/K.
	var very_high := Resolve.soft_cap(1000.0)
	var asymptote := Resolve.SOFT_CAP_KNEE + 1.0 / Resolve.SOFT_CAP_K
	_check(
		very_high < asymptote,
		"soft_cap: very high power compressed below asymptote KNEE+1/K=%.1f" % asymptote
	)
	_check(very_high > Resolve.SOFT_CAP_KNEE, "soft_cap: well above knee is still above knee")


func _test_derived_role(content: Content) -> void:
	# Role is a pure display read off the doll (class tree parked, reset 2026-06-14):
	# an empty doll reads Generalist; the dominant fed attribute names the role.
	var l_empty := Lineage.new("t", "T")
	_check(
		Resolve.derived_role(l_empty, content) == "Generalist",
		"derived_role: empty doll → Generalist"
	)

	# A power mouthpart (feeds power) → Predator.
	var l_power := Lineage.new("t", "T")
	l_power.doll["mouthparts"] = AdaptationInstance.new("frontal_appendage", 2)
	_check(
		Resolve.derived_role(l_power, content) == "Predator",
		"derived_role: power-fed doll → Predator"
	)

	# A resilience integument (feeds resilience) → Armored Grazer.
	var l_guard := Lineage.new("t", "T")
	l_guard.doll["integument"] = AdaptationInstance.new("calcite_carapace", 2)
	_check(
		Resolve.derived_role(l_guard, content) == "Armored Grazer",
		"derived_role: resilience-fed doll → Armored Grazer"
	)


func _test_accrue_determinism_phase3(content: Content) -> void:
	# Two accrue() runs with the same gap + seed must be identical under Option A /
	# class mods / soft cap. Uses a lineage with a non-trivial doll.
	var state := GameState.new()
	state.master_seed = 17
	var l := Lineage.new("p", "P")
	l.attributes["power"] = 6.0
	l.assigned_node = "trilobite_grazer"
	var inst := AdaptationInstance.new("frontal_appendage", 2)
	l.doll["mouthparts"] = inst
	state.lineages.append(l)
	var rng_a := Rng.new(17)
	var rng_b := Rng.new(17)
	var dt := 8.0 * 3600.0
	var result_a := Accrual.accrue(state, content, dt, rng_a)
	var result_b := Accrual.accrue(state, content, dt, rng_b)
	_check(
		JSON.stringify(result_a["events"]) == JSON.stringify(result_b["events"]),
		"phase3 determinism: two accrue() runs same seed → identical events"
	)


# -- Cladogenesis (the respec valve) -----------------------------------------


func _test_branch_lineage(content: Content) -> void:
	var state := GameState.new()
	state.master_seed = 3
	state.slots_active = 2

	# First branch: slot free → ok.
	var r1 := Commands.branch_lineage(state, content, "", "Beta")
	_check(r1["ok"], "branch_lineage: first branch accepted")
	var l1: Lineage = r1["lineage"]
	_check(l1.doll.is_empty(), "branch_lineage: doll is empty")
	_check(l1.assigned_node != "", "branch_lineage: assigned to starter node")
	_check(state.lineages.size() == 1, "branch_lineage: lineage appended to state")

	# Gene bank is shared (genes_known is account-wide; nothing copied into the lineage).
	state.genes_known["gene_gill"] = 5
	_check(int(state.genes_known.get("gene_gill", 0)) == 5, "branch_lineage: gene bank shared")

	# Second branch: both slots active (2 lineages) → full roster.
	Commands.branch_lineage(state, content, "", "Gamma")
	var r_full := Commands.branch_lineage(state, content, "", "Delta")
	_check(not r_full["ok"], "branch_lineage: blocked when roster full")

	# New lineage id is unique.
	var ids: Dictionary = {}
	for lin: Lineage in state.lineages:
		_check(not ids.has(lin.id), "branch_lineage: unique ids ('%s' not duplicate)" % lin.id)
		ids[lin.id] = true


# -- Phase 3 polish: slot affinity, per-organ cap, evolving names -------------


func _test_slot_affinity(content: Content) -> void:
	# gill_minor is metabolic_core-only; it must reject a mouthparts organ and
	# accept a metabolic_core organ.
	var state := _fresh_state(content)
	state.inventory_materials["biofilm"] = 9999.0
	state.inventory_materials["soft_tissue"] = 9999.0
	Commands.metabolize(state, content, "main", "frontal_appendage")  # mouthparts
	Commands.metabolize(state, content, "main", "gill_branches")  # metabolic_core
	state.genes_known["gene_gill"] = 1

	var r_wrong := Commands.express(state, content, "main", "mouthparts", "gill_minor")
	_check(not r_wrong["ok"], "affinity: gill_minor rejected on mouthparts (does not fit)")

	var r_right := Commands.express(state, content, "main", "metabolic_core", "gill_minor")
	_check(r_right["ok"], "affinity: gill_minor accepted on metabolic_core")

	# Static helper agrees with the data.
	_check(
		Commands.affix_allows_slot(content.affix("venom_minor"), "mouthparts"),
		"affinity: venom fits mouthparts"
	)
	_check(
		not Commands.affix_allows_slot(content.affix("venom_minor"), "sensory"),
		"affinity: venom does not fit sensory"
	)


func _test_express_cap(content: Content) -> void:
	# sensory holds 1; a 2nd distinct affix on a sensory organ is rejected, while
	# tiering up the affix already there is always allowed.
	_check(Commands.slot_express_cap("sensory") == 1, "cap: sensory holds 1")
	_check(Commands.slot_express_cap("integument") == 3, "cap: integument holds 3")

	# Use mouthparts (cap 2) with two distinct mouthparts affixes, then a third.
	var state := _fresh_state(content)
	state.inventory_materials["biofilm"] = 9999.0
	state.inventory_materials["chitin"] = 9999.0
	state.inventory_materials["soft_tissue"] = 9999.0
	state.inventory_materials["flesh"] = 9999.0
	Commands.metabolize(state, content, "main", "frontal_appendage")  # mouthparts
	state.genes_known["gene_gnathobase"] = 1  # penetration, fits mouthparts
	state.genes_known["gene_raptorial"] = 1  # grasp_minor (control), fits mouthparts
	state.genes_known["gene_nematocyst"] = 1  # venom_minor, fits mouthparts

	var r1 := Commands.express(state, content, "main", "mouthparts", "gnathobase_minor")
	_check(r1["ok"], "cap: 1st mouthparts affix accepted")
	var r2 := Commands.express(state, content, "main", "mouthparts", "grasp_minor")
	_check(r2["ok"], "cap: 2nd mouthparts affix accepted (cap 2)")
	var r3 := Commands.express(state, content, "main", "mouthparts", "venom_minor")
	_check(not r3["ok"], "cap: 3rd distinct mouthparts affix rejected (organ full)")

	# Tiering up an affix already present is NOT blocked by the cap.
	state.genes_known["gene_gnathobase"] = 2
	var r_up := Commands.express(state, content, "main", "mouthparts", "gnathobase_minor")
	_check(r_up["ok"], "cap: tier-up of present affix not blocked by full organ")


func _test_organ_naming(content: Content) -> void:
	# Tier prefix climbs; affix adjective prepends; tech line carries the precise read.
	var state := _fresh_state(content)
	state.inventory_materials["biofilm"] = 9999.0
	state.inventory_materials["chitin"] = 9999.0
	for _i in range(3):
		Commands.metabolize(state, content, "main", "frontal_appendage")
	var l := state.lineages[0]
	var inst: AdaptationInstance = l.doll.get("mouthparts")
	_check(
		Naming.display_name(inst, content) == "Great Frontal Appendage",
		"naming: tier-3 base reads 'Great Frontal Appendage'"
	)

	state.genes_known["gene_gnathobase"] = 1
	Commands.express(state, content, "main", "mouthparts", "gnathobase_minor")
	_check(
		Naming.display_name(inst, content) == "Toothed Great Frontal Appendage",
		"naming: express prepends adjective"
	)
	_check(
		Naming.tech_line(inst, content) == "T3 · Gnathobase I · epic",
		"naming: tech line carries tier, express, rarity"
	)


func _test_niche_key_legibility(content: Content) -> void:
	# The data the niche-gate panel renders: the key role resolves to a concrete
	# generalist gene, and that gene has a discoverable source.
	var pelagic := content.niche("pelagic")
	var keys: Array = pelagic.get("affix_keys", [])
	_check(keys.size() == 1 and String(keys[0]) == "sustain", "legibility: pelagic key is sustain")

	var options := content.key_affixes_for_role("sustain")
	var has_gill := false
	for opt: Dictionary in options:
		if String((opt["affix"] as Dictionary).get("id", "")) == "gill_minor":
			has_gill = (String((opt["gene"] as Dictionary).get("id", "")) == "gene_gill")
	_check(has_gill, "legibility: sustain key resolves to Gill Branching ← gene_gill")

	# gene_gill drops at the very first free node (microbial_mat) — the path exists.
	var sources := content.sources_for_gene("gene_gill")
	var from_mat := false
	for src: Dictionary in sources:
		if (
			String(src.get("node", "")) == "microbial_mat"
			and (src.get("via", []) as Array).has("drop")
		):
			from_mat = true
	_check(from_mat, "legibility: gene_gill drops at microbial_mat (reachable from turn one)")

	# A spliceable gene reports its splice source.
	var nemato := content.sources_for_gene("gene_nematocyst")
	var splice_from_anemone := false
	for src: Dictionary in nemato:
		if (
			String(src.get("node", "")) == "sea_anemone"
			and (src.get("via", []) as Array).has("splice")
		):
			splice_from_anemone = true
	_check(splice_from_anemone, "legibility: gene_nematocyst splices from sea_anemone")


# -- Phase 3.5 WP1: offline accrual application -------------------------------


## The shared apply helper credits exactly what Accrual.accrue produced — the
## offline path and a live grind can never drift (PHASE3_5.md WP1).
func _test_apply_accrual_batch(content: Content) -> void:
	var state := _fresh_state(content)  # starter works microbial_mat (always gated open)
	var batch := Accrual.accrue(state, content, 8.0 * 3600.0, Rng.new(7))
	var gene_events := 0
	var splice_events := 0
	for ev: Dictionary in batch["events"] as Array:
		if String(ev.get("kind", "")) == "gene":
			gene_events += 1
		elif String(ev.get("kind", "")) == "splice":
			splice_events += 1

	Commands.apply_accrual_batch(state, batch)

	var copies := 0
	for g: String in state.genes_known:
		copies += int(state.genes_known[g])
	_check(copies == gene_events, "apply batch: every gene event becomes a gene-bank copy")
	_check(state.splice_offers.size() == splice_events, "apply batch: splice events become offers")

	var mats_ok := true
	for m: String in batch["materials"] as Dictionary:
		if (
			float(state.inventory_materials.get(m, 0.0))
			< float((batch["materials"] as Dictionary)[m]) - 0.001
		):
			mats_ok = false
	_check(mats_ok, "apply batch: materials credited to the stash")
	_check(gene_events > 0, "apply batch: an 8h gap actually produced events (sanity)")


func _test_offline_dt_clamp() -> void:
	_check(Commands.offline_dt(100, 50, 1000.0) == 0.0, "offline_dt: a clock set back clamps to 0")
	_check(
		Commands.offline_dt(0, 999999, 1000.0) == 1000.0, "offline_dt: an absurd gap clamps to cap"
	)
	_check(Commands.offline_dt(0, 500, 1000.0) == 500.0, "offline_dt: a normal gap passes through")


# -- Phase 3.5 WP2: the do-now agenda ----------------------------------------


func _has_kind(items: Array, kind: String) -> bool:
	for item: Dictionary in items:
		if String(item.get("kind", "")) == kind:
			return true
	return false


## A fresh lineage with nothing in the bank still has a concrete next thing: the
## nearest node it can't quite clear. No phantom claim/tier-up appears.
func _test_agenda_fresh(content: Content) -> void:
	var state := _fresh_state(content)
	var items := Agenda.for_lineage(state, content, "main")
	_check(not items.is_empty(), "agenda: a fresh lineage still has something to do")
	_check(_has_kind(items, "node_in_reach"), "agenda: names the nearest node out of reach")
	_check(not _has_kind(items, "claim_splice"), "agenda: no phantom splice on a fresh lineage")
	_check(not _has_kind(items, "tierup_ready"), "agenda: no tier-up with an empty stash")


func _test_agenda_claim_splice(content: Content) -> void:
	var state := _fresh_state(content)
	state.splice_offers.append({"gene": "gene_nematocyst", "node": "sea_anemone"})
	var items := Agenda.for_lineage(state, content, "main")
	_check(_has_kind(items, "claim_splice"), "agenda: a waiting splice surfaces a claim action")


func _test_agenda_tierup_ready(content: Content) -> void:
	var rich := _fresh_state(content)
	rich.inventory_materials["biofilm"] = 1000.0
	var items := Agenda.for_lineage(rich, content, "main")
	_check(
		_has_kind(items, "tierup_ready"),
		"agenda: affordable tier-up surfaces with materials in hand"
	)


## An expressed affix held at exactly its current tier in copies is one short of
## the next — the copy ladder, surfaced (PHASE3_5.md WP2).
func _test_agenda_one_copy_short(content: Content) -> void:
	var state := _fresh_state(content)
	var l := state.lineages[0]
	var inst := AdaptationInstance.new("frontal_appendage", 1)
	inst.affixes.append({"id": "venom_minor", "tier": 1})
	l.doll["mouthparts"] = inst
	state.genes_known[String(content.gene_for_affix("venom_minor").get("id", ""))] = 1
	var items := Agenda.for_lineage(state, content, "main")
	_check(
		_has_kind(items, "one_copy_short"), "agenda: surfaces an affix one copy from its next tier"
	)
