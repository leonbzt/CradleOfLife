extends SceneTree

## The economy harness — the spine of the project (IMPLEMENTATION.md §4, §8).
## Runs the REAL resolve()/accrue() headless, with no UI:
##   godot --headless --script res://tests/economy_test.gd
##
## Part A loops resolve() 10,000x against a defended node and prints the loot
## distribution. Part B simulates a 6-week arc of check-ins through accrue() and
## reports the chase health: events per check-in, and the DRY-STREAK DISTRIBUTION
## (p10/p50/p90 of check-ins between legendaries) — because the mean staying flat
## is not enough; the unlucky tail is what churns players.
##
## Reset 2026-06-14: the class tree + niche multiplier are parked, so Part B runs
## ONE representative lineage and proves only the §9a *shape* (never-flat week
## means + a legendary always reachable-but-never-given). Niche divergence /
## branches-feel-different is a rebuild gate, not a reset gate. The policy grinds
## the hardest shallow_benthos node it can currently crack, so it stays valid as
## the content is trimmed (R3) and the constants re-tuned (R4).

const SECONDS_PER_HOUR: float = 3600.0

## Maximum express tier the policy will apply per affix slot. Prevents the model
## from stacking affixes to astronomically high tiers (which can't happen in real
## play where legendary copies are gated by drop rarity). A model constraint, not
## a game rule; it doesn't touch the engine.
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
	print("\n== Part A: 10,000 resolve() actions vs Sea Anemone ==")
	var rng := Rng.new(1)
	var node := content.node("sea_anemone")
	var lineage := _make_lineage("explorer", "sea_anemone", 8.0, 1.0)
	var mat_id := String(node.get("material", ""))
	var n := 10000
	var dt := 60.0  # one action = 60 in-game seconds

	var materials := 0.0
	var genes := 0
	var splices := 0
	var by_rarity := {}
	for _i in range(n):
		var loot := Resolve.resolve(lineage, node, dt, rng, content)
		materials += float((loot["materials"] as Dictionary).get(mat_id, 0.0))
		var gene: Dictionary = loot["gene"]
		if not gene.is_empty():
			genes += 1
			var r := String(gene.get("rarity", "?"))
			by_rarity[r] = int(by_rarity.get(r, 0)) + 1
		if String(loot["splice_offer"]) != "":
			splices += 1

	print("  actions:        %d (dt=%.0fs each)" % [n, dt])
	print("  materials:      %.0f %s" % [materials, mat_id])
	print("  gene drops:     %d  (%.2f%% of actions)" % [genes, 100.0 * genes / n])
	print("  splice offers:  %d" % splices)
	print("  gene rarity:    " + JSON.stringify(by_rarity))


func _part_b_chase_arc(content: Content) -> void:
	print("\n== Part B: 6-week chase arc (1 lineage, 8h check-ins, player policy) ==")
	var rng := Rng.new(42)
	var state := GameState.new()
	state.master_seed = 42
	# One representative lineage starts grazing the microbial mat and works its way
	# up the shallow-benthos nodes as its build grows (the policy below).
	state.lineages.append(_make_lineage("main", "microbial_mat", 1.0, 1.0))

	var gap := 8.0 * SECONDS_PER_HOUR
	var checkins := 6 * 7 * 3  # 6 weeks, 3 check-ins/day
	var events_per: Array = []
	var legendary_gaps: Array = []  # check-ins between legendaries (the dry streak)
	var since := 0
	var total_legendaries := 0
	var eff_powers: Array = []
	var rows: Array = [
		(
			"checkin,day,events,legendaries,since_last_legendary"
			+ ",splices_claimed,expresses_applied,node,eff_power"
		)
	]

	for c in range(checkins):
		# Accrue the offline gap, apply it, then run the deterministic player policy.
		var batch := Accrual.accrue(state, content, gap, rng)
		_apply_batch(state, batch)
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

		var l := state.lineage_by_id("main")
		var ep := Resolve.effective_power(l, content)
		eff_powers.append(ep)
		(
			rows
			. append(
				(
					"%d,%d,%d,%d,%d,%d,%d,%s,%.2f"
					% [
						c + 1,
						c / 3 + 1,
						evs,
						legs,
						dry,
						int(policy["splices"]),
						int(policy["expresses"]),
						l.assigned_node,
						ep,
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

	var final_ep: float = float(eff_powers.back()) if not eff_powers.is_empty() else 0.0
	var max_ep := _max_float(eff_powers)
	var asymptote := Resolve.SOFT_CAP_KNEE + 1.0 / Resolve.SOFT_CAP_K
	print(
		(
			"  lineage: max_eff_power=%.2f  final_eff_power=%.2f  node=%s"
			% [max_ep, final_ep, state.lineage_by_id("main").assigned_node]
		)
	)
	print(
		(
			"  soft cap bites (final < asymptote %.1f): %s"
			% [asymptote, "YES" if final_ep < asymptote else "NO"]
		)
	)
	print(
		(
			"  lineage progressed past the starter node: %s"
			% ("YES" if state.lineage_by_id("main").assigned_node != "microbial_mat" else "NO")
		)
	)
	var lm := state.lineage_by_id("main")
	var skill_bits: Array = []
	for s: Dictionary in content.skills():
		var sid := String(s.get("id", ""))
		skill_bits.append("%s L%d" % [String(s.get("name", sid)), Resolve.skill_level(lm, sid)])
	print("  main skills: " + ", ".join(skill_bits))

	_write_csv("user://chase.csv", rows)
	print("  per-check-in CSV: " + ProjectSettings.globalize_path("user://chase.csv"))
	print("    chart it: python3 tools/chart_chase.py <that path>")


## Credit one accrual batch to the live state. Delegates to the shared command so
## the harness applies materials, gene/splice events, AND skill XP exactly the way
## the real offline path does — one application path, no drift.
func _apply_batch(state: GameState, batch: Dictionary) -> void:
	Commands.apply_accrual_batch(state, batch)


## True if the live stash can pay every material in `cost` (empty cost → false).
func _affordable(state: GameState, cost: Dictionary) -> bool:
	if cost.is_empty():
		return false
	for mat_id: String in cost:
		if float(state.inventory_materials.get(mat_id, 0.0)) < float(cost[mat_id]):
			return false
	return true


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

	# 2. Metabolize, ORGAN-STABLE: keep one organ per slot and tier it up; build the
	#    first adaptation for a slot into an empty slot. Never replace a different
	#    organ (which would thrash and waste materials every check-in).
	for lineage: Lineage in state.lineages:
		for slot: String in Lineage.SLOTS:
			var inst: AdaptationInstance = lineage.doll.get(slot)
			if inst != null:
				var cur_def := content.adaptation(inst.def_id)
				var tier := Commands.next_tier(lineage, cur_def)
				if tier > 0 and _affordable(state, Commands.metabolize_cost(cur_def, tier)):
					Commands.metabolize(state, content, lineage.id, inst.def_id)
				continue
			var target_def: Dictionary = {}
			for def: Dictionary in content.tables.get("adaptations", []):
				if String(def.get("slot", "")) != slot:
					continue
				target_def = def
				break
			if (
				not target_def.is_empty()
				and _affordable(state, Commands.metabolize_cost(target_def, 1))
			):
				Commands.metabolize(state, content, lineage.id, String(target_def.get("id", "")))

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

	# 4. Migrate to the hardest shallow_benthos node this lineage can currently
	#    crack (the gene tables get richer as the build grows). Content-trim-robust:
	#    it just reads whatever benthos nodes exist.
	for lineage: Lineage in state.lineages:
		var node_id := _hardest_clearable_benthos_node(content, lineage)
		if node_id != "" and node_id != lineage.assigned_node:
			Commands.assign_node(state, content, lineage.id, node_id)

	return {"splices": splices, "expresses": expresses}


## The highest-defense shallow_benthos node whose effective defense this lineage's
## effective power currently clears (eat nodes, defense 0, always qualify).
func _hardest_clearable_benthos_node(content: Content, l: Lineage) -> String:
	var totals := Resolve.affix_totals(l, content)
	var ep := Resolve.effective_power(l, content)
	var best := ""
	var best_def := -1.0
	for n: Dictionary in content.tables.get("nodes", []):
		if String(n.get("niche", "")) != "shallow_benthos":
			continue
		# The ladder: a node must be skill-UNLOCKED as well as power-crackable.
		if not Commands.meets_skill_requirement(l, n.get("requires", {})):
			continue
		if ep <= Resolve.effective_defense(n, totals):
			continue
		var d := float(n.get("defense", 0.0))
		if d > best_def:
			best_def = d
			best = String(n.get("id", ""))
	return best


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
