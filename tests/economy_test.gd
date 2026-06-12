extends SceneTree

## The economy harness — the spine of the project (IMPLEMENTATION.md §4 Phase 0,
## §8). Runs the REAL resolve()/accrue() headless, with no UI:
##   godot --headless --script res://tests/economy_test.gd
##
## Part A loops resolve() 10,000x against a defended node and prints the loot
## distribution. Part B simulates a 6-week arc of check-ins through accrue() and
## reports the chase health: events per check-in, and the DRY-STREAK DISTRIBUTION
## (p10/p50/p90 of check-ins between legendaries) — because the mean staying flat
## is not enough; the unlucky tail is what churns players (the open question we
## agreed to measure before deciding anything about pity).
##
## Phase 2 additions: deterministic player policy at each check-in (claim all
## splice offers, express best affordable affix, migrate niches when keys met).
## Phase 3 additions: two lineages commit different classes (hunter→predator,
## grazer→filter_feeder); category gates enforced via Commands; class
## commitment fires as soon as requirements are met. Hunter advances through
## benthos fight nodes; grazer migrates to pelagic after filter_feeder commit.
## CSV gains: hunter_class, hunter_eff_power, grazer_niche, grazer_class, grazer_eff_power.

const SECONDS_PER_HOUR: float = 3600.0

## Maximum express tier the policy will apply per affix slot. Prevents the model
## from stacking splice_mult affixes to astronomically high tiers (which can't
## happen in real play where legendary copies are gated by drop rarity).
## This is a model constraint, not a game rule; it doesn't touch the engine.
const POLICY_MAX_EXPRESS_TIER: int = 3


func _initialize() -> void:
	var content := Content.load_dir("res://data")
	var errors := Validation.validate(content)
	if not errors.is_empty():
		push_error("content failed validation; aborting economy test")
		for e in errors:
			print("  - " + e)
		quit(1)
		return

	_part_a_loot_distribution(content)
	_part_b_chase_arc(content)
	quit(0)


func _make_lineage(id: String, node_id: String, power: float, instinct: float) -> Lineage:
	var l := Lineage.new(id, id)
	l.attributes["power"] = power
	l.attributes["instinct"] = instinct
	l.assigned_node = node_id
	return l


func _part_a_loot_distribution(content: Content) -> void:
	print("\n== Part A: 10,000 resolve() actions vs Trilobite Grazer ==")
	var rng := Rng.new(1)
	var node := content.node("trilobite_grazer")
	var lineage := _make_lineage("explorer", "trilobite_grazer", 8.0, 1.0)
	var n := 10000
	var dt := 60.0  # one action = 60 in-game seconds

	var materials := 0.0
	var genes := 0
	var splices := 0
	var by_rarity := {}
	for _i in range(n):
		var loot := Resolve.resolve(lineage, node, dt, rng, content)
		materials += float((loot["materials"] as Dictionary).get("chitin", 0.0))
		var gene: Dictionary = loot["gene"]
		if not gene.is_empty():
			genes += 1
			var r := String(gene.get("rarity", "?"))
			by_rarity[r] = int(by_rarity.get(r, 0)) + 1
		if String(loot["splice_offer"]) != "":
			splices += 1

	print("  actions:        %d (dt=%.0fs each)" % [n, dt])
	print("  materials:      %.0f chitin" % materials)
	print("  gene drops:     %d  (%.2f%% of actions)" % [genes, 100.0 * genes / n])
	print("  splice offers:  %d" % splices)
	print("  gene rarity:    " + JSON.stringify(by_rarity))


func _part_b_chase_arc(content: Content) -> void:
	print("\n== Part B: 6-week chase arc (2 lineages, 8h check-ins, player policy) ==")
	var rng := Rng.new(42)
	var state := GameState.new()
	state.master_seed = 42
	# hunter: shallow_benthos → sea_anemone (benthos_fight) → trilobite_grazer;
	#         commits Predator when gnathobase_minor (penetration) is expressed.
	# grazer: stays at microbial_mat, commits Filter Feeder (sustain = gill_minor
	#         from benthos_eat genes), then migrates to pelagic (plankton_bloom).
	# Both start at microbial_mat (benthos eat, drops biofilm + gill/eye genes).
	state.lineages.append(_make_lineage("hunter", "microbial_mat", 3.0, 1.0))
	state.lineages.append(_make_lineage("grazer", "microbial_mat", 3.0, 1.0))

	var gap := 8.0 * SECONDS_PER_HOUR
	var checkins := 6 * 7 * 3  # 6 weeks, 3 check-ins/day
	var events_per: Array = []
	var legendary_gaps: Array = []  # check-ins between legendaries (the dry streak)
	var since := 0
	var total_legendaries := 0
	var hunter_eff_powers: Array = []
	var grazer_eff_powers: Array = []
	var rows: Array = [
		(
			"checkin,day,events,legendaries,since_last_legendary"
			+ ",splices_claimed,expresses_applied"
			+ ",hunter_niche,hunter_class,hunter_eff_power"
			+ ",grazer_niche,grazer_class,grazer_eff_power"
		)
	]

	for c in range(checkins):
		# Accrue offline gap for all working lineages.
		var batch := Accrual.accrue(state, content, gap, rng)

		# Apply batch to state (materials, gene events, splice events).
		_apply_batch(state, batch)

		# Deterministic player policy: claim splices, metabolize, express, migrate.
		var policy := _apply_policy(state, content)

		# Measure this check-in's events AFTER applying the batch.
		var evs := (batch["events"] as Array).size()
		var legs := 0
		for e: Dictionary in batch["events"] as Array:
			if String(e.get("rarity", "")) == "legendary":
				legs += 1

		events_per.append(evs)
		since += 1
		var dry := since
		for _li in range(legs):
			legendary_gaps.append(since)
			since = 0
		total_legendaries += legs

		var hunter_l := state.lineage_by_id("hunter")
		var grazer_l := state.lineage_by_id("grazer")
		var hunter_ep := Resolve.effective_power(hunter_l, content)
		var grazer_ep := Resolve.effective_power(grazer_l, content)
		hunter_eff_powers.append(hunter_ep)
		grazer_eff_powers.append(grazer_ep)
		var hunter_niche := _lineage_niche(state, "hunter", content)
		var grazer_niche := _lineage_niche(state, "grazer", content)
		(
			rows
			. append(
				(
					"%d,%d,%d,%d,%d,%d,%d,%s,%s,%.2f,%s,%s,%.2f"
					% [
						c + 1,
						c / 3 + 1,
						evs,
						legs,
						dry,
						int(policy["splices"]),
						int(policy["expresses"]),
						hunter_niche,
						hunter_l.class_node,
						hunter_ep,
						grazer_niche,
						grazer_l.class_node,
						grazer_ep,
					]
				)
			)
		)

	# Week-over-week decay check (6 groups of 21 check-ins each).
	var weeks: Array = []
	var week_size := 21
	for w in range(6):
		var start := w * week_size
		var end := mini(start + week_size, events_per.size())
		var week_sum := 0.0
		for i in range(start, end):
			week_sum += float(events_per[i])
		weeks.append(week_sum / float(end - start))

	print("  check-ins:            %d over 42 days" % checkins)
	print("  mean events/check-in: %.2f   (min %d)" % [_mean(events_per), _min_int(events_per)])
	print("  total legendaries:    %d" % total_legendaries)
	print(
		(
			"  week means (never-flat): %s"
			% ", ".join(Array(weeks).map(func(w: float) -> String: return "%.1f" % w))
		)
	)
	if legendary_gaps.is_empty():
		print("  WARNING: no legendaries in window — chase ceiling may be too high")
	else:
		var p10 := _pct(legendary_gaps, 0.1)
		var p50 := _pct(legendary_gaps, 0.5)
		var p90 := _pct(legendary_gaps, 0.9)
		var dmax := _max_int(legendary_gaps)
		print(
			(
				"  dry streak (check-ins between legendaries): p10=%d p50=%d p90=%d max=%d"
				% [p10, p50, p90, dmax]
			)
		)
		var target_met := p50 >= 10 and p50 <= 25
		print("  p50 in target band [10,25]: %s" % ("YES" if target_met else "NO — needs tuning"))

	# Phase 3 acceptance checks
	var hunter_l_fin := state.lineage_by_id("hunter")
	var grazer_l_fin := state.lineage_by_id("grazer")
	var hunter_max_ep := _max_float(hunter_eff_powers)
	var grazer_max_ep := _max_float(grazer_eff_powers)
	var hunter_final_ep: float = (
		float(hunter_eff_powers.back()) if not hunter_eff_powers.is_empty() else 0.0
	)
	var grazer_final_ep: float = (
		float(grazer_eff_powers.back()) if not grazer_eff_powers.is_empty() else 0.0
	)
	print(
		(
			"  hunter: class=%s  max_eff_power=%.2f  final_eff_power=%.2f  niche=%s"
			% [
				hunter_l_fin.class_node,
				hunter_max_ep,
				hunter_final_ep,
				_lineage_niche(state, "hunter", content)
			]
		)
	)
	print(
		(
			"  grazer: class=%s  max_eff_power=%.2f  final_eff_power=%.2f  niche=%s"
			% [
				grazer_l_fin.class_node,
				grazer_max_ep,
				grazer_final_ep,
				_lineage_niche(state, "grazer", content)
			]
		)
	)
	var soft_cap_bites: bool = (
		hunter_final_ep < Resolve.SOFT_CAP_KNEE + 1.0 / Resolve.SOFT_CAP_K
		and grazer_final_ep < Resolve.SOFT_CAP_KNEE + 1.0 / Resolve.SOFT_CAP_K
	)
	print(
		(
			"  soft cap bites (both < asymptote %.1f): %s"
			% [Resolve.SOFT_CAP_KNEE + 1.0 / Resolve.SOFT_CAP_K, "YES" if soft_cap_bites else "NO"]
		)
	)
	var no_stranded := hunter_max_ep > 9.0 or grazer_max_ep > 9.0
	print("  no stranded content (someone beats DEF 9): %s" % ("YES" if no_stranded else "NO"))
	var lineages_diverged := (
		hunter_l_fin.class_node != grazer_l_fin.class_node
		and _lineage_niche(state, "hunter", content) != _lineage_niche(state, "grazer", content)
	)
	print("  lineages diverged (class + niche differ): %s" % ("YES" if lineages_diverged else "NO"))

	_write_csv("user://chase.csv", rows)
	print("  per-check-in CSV: " + ProjectSettings.globalize_path("user://chase.csv"))
	print("    chart it: python3 tools/chart_chase.py <that path>")


## Credit materials and events from one accrual batch to the live state.
func _apply_batch(state: GameState, batch: Dictionary) -> void:
	for mat_id: String in batch["materials"] as Dictionary:
		state.inventory_materials[mat_id] = (
			float(state.inventory_materials.get(mat_id, 0.0))
			+ float((batch["materials"] as Dictionary)[mat_id])
		)
	for ev: Dictionary in batch["events"] as Array:
		match String(ev.get("kind", "")):
			"gene":
				var gid := String(ev.get("gene", ""))
				if gid != "":
					state.genes_known[gid] = int(state.genes_known.get(gid, 0)) + 1
			"splice":
				(
					state
					. splice_offers
					. append(
						{
							"gene": String(ev.get("gene", "")),
							"node": String(ev.get("node", "")),
						}
					)
				)


## Deterministic player policy. Runs AFTER _apply_batch on the same check-in.
## Returns {splices: int, expresses: int}.
func _apply_policy(state: GameState, content: Content) -> Dictionary:
	var splices := 0
	var expresses := 0

	# 1. Claim all pending splice offers (each adds 1 gene copy to genes_known).
	while not state.splice_offers.is_empty():
		var result := Commands.claim_splice(state, 0)
		if not result["ok"]:
			break
		splices += 1

	# 2. Metabolize: build or tier-up any affordable adaptation for each lineage.
	for lineage: Lineage in state.lineages:
		for def: Dictionary in content.tables.get("adaptations", []):
			var tier := Commands.next_tier(lineage, def)
			if tier == 0:
				continue
			var cost := Commands.metabolize_cost(def, tier)
			if cost.is_empty():
				continue
			var affordable := true
			for mat_id: String in cost:
				if float(state.inventory_materials.get(mat_id, 0.0)) < float(cost[mat_id]):
					affordable = false
					break
			if affordable:
				Commands.metabolize(state, content, lineage.id, String(def.get("id", "")))

	# 3. Graft: for each equipped slot, apply the affordable affix with the most
	#    gene copies (ties broken by data order).
	for lineage: Lineage in state.lineages:
		for slot: String in Lineage.SLOTS:
			var inst: AdaptationInstance = lineage.doll.get(slot)
			if inst == null:
				continue
			var best_id := ""
			var best_copies := -1
			for affix: Dictionary in content.tables.get("affixes", []):
				var affix_id := String(affix.get("id", ""))
				var gene_row := content.gene_for_affix(affix_id)
				if gene_row.is_empty():
					continue
				var gene_id := String(gene_row.get("id", ""))
				var copies := int(state.genes_known.get(gene_id, 0))
				if copies == 0:
					continue
				# Slot affinity + per-organ cap: only express genes that fit this
				# organ, and only a NEW one if the organ has a free expression slot
				# (a tier-up of one already present always fits). Mirrors express().
				if not Commands.affix_allows_slot(affix, slot):
					continue
				var current_tier := inst.express_tier(affix_id)
				if current_tier == 0 and inst.affixes.size() >= Commands.slot_express_cap(slot):
					continue
				var target := current_tier + 1
				if target > POLICY_MAX_EXPRESS_TIER:
					continue
				if copies < target:
					continue
				var gc: Dictionary = affix.get("express_cost", {})
				var mat := String(gc.get("material", ""))
				var cost_qty := roundf(
					float(gc.get("base", 0.0)) * pow(float(gc.get("growth", 1.0)), target - 1)
				)
				if float(state.inventory_materials.get(mat, 0.0)) < cost_qty:
					continue
				if copies > best_copies:
					best_copies = copies
					best_id = affix_id
			if best_id != "":
				var result := Commands.express(state, content, lineage.id, slot, best_id)
				if result["ok"]:
					expresses += 1

	# 3b. Class commitment: commit class as soon as eligible (sticky descent).
	#     hunter commits Predator when gnathobase_minor (penetration) is expressed
	#     — gene drops from benthos_fight; express costs chitin from trilobite_grazer.
	#     grazer commits Filter Feeder when gill_minor (sustain) is expressed
	#     — gene drops from benthos_eat; express costs biofilm from microbial_mat.
	var class_targets: Dictionary = {"hunter": "predator", "grazer": "filter_feeder"}
	for lineage: Lineage in state.lineages:
		if not class_targets.has(lineage.id):
			continue
		var target_class := String(class_targets[lineage.id])
		if lineage.class_node == target_class:
			continue
		var r := Commands.pick_class(state, content, lineage.id, target_class)
		if r["ok"]:
			pass  # class committed; allowed categories expanded

	# 4. Migrate: hunter advances through benthos fight nodes to accumulate
	#    gnathobase genes; grazer moves to pelagic once filter_feeder committed.
	for lineage: Lineage in state.lineages:
		if lineage.assigned_node == "":
			continue
		var ep := Resolve.effective_power(lineage, content)
		if lineage.id == "hunter":
			if lineage.assigned_node == "microbial_mat" and ep > 2.0:
				Commands.assign_node(state, content, lineage.id, "sea_anemone")
			elif lineage.assigned_node == "sea_anemone" and ep > 4.0:
				Commands.assign_node(state, content, lineage.id, "trilobite_grazer")
		elif lineage.id == "grazer":
			if lineage.class_node == "filter_feeder":
				Commands.assign_node(state, content, lineage.id, "plankton_bloom")

	return {"splices": splices, "expresses": expresses}


func _lineage_niche(state: GameState, lineage_id: String, content: Content) -> String:
	var l := state.lineage_by_id(lineage_id)
	if l == null or l.assigned_node == "":
		return "none"
	return String(content.node(l.assigned_node).get("niche", "none"))


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()


func _min_int(a: Array) -> int:
	if a.is_empty():
		return 0
	var m := int(a[0])
	for x in a:
		m = mini(m, int(x))
	return m


func _max_int(a: Array) -> int:
	var m := 0
	for x in a:
		m = maxi(m, int(x))
	return m


func _max_float(a: Array) -> float:
	var m := 0.0
	for x in a:
		m = maxf(m, float(x))
	return m


func _pct(a: Array, q: float) -> int:
	var s := a.duplicate()
	s.sort()
	var idx := int(clampf(q * (s.size() - 1), 0.0, float(s.size() - 1)))
	return int(s[idx])


func _write_csv(path: String, rows: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	for r in rows:
		f.store_line(String(r))
	f.close()
