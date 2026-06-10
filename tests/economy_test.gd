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
## Numbers here are placeholder constants (open dials, VISION.md §20). This
## script is how we'll tune them and confirm the curve never flattens.

const SECONDS_PER_HOUR: float = 3600.0


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
		var loot := Resolve.resolve(lineage, node, dt, rng)
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
	print("\n== Part B: 6-week chase arc (2 lineages, 8h check-ins) ==")
	var rng := Rng.new(42)
	var state := GameState.new()
	state.master_seed = 42
	state.lineages.append(_make_lineage("hunter", "trilobite_grazer", 8.0, 1.0))
	state.lineages.append(_make_lineage("stinger", "sea_anemone", 6.0, 1.2))

	var gap := 8.0 * SECONDS_PER_HOUR
	var checkins := 6 * 7 * 3  # 6 weeks, 3 check-ins/day
	var events_per: Array = []
	var legendary_gaps: Array = []  # check-ins between legendaries (the dry streak)
	var since := 0
	var total_legendaries := 0
	var rows: Array = ["checkin,day,events,legendaries,since_last_legendary"]

	for c in range(checkins):
		var batch := Accrual.accrue(state, content, gap, rng)
		var evs := (batch["events"] as Array).size()
		var legs := 0
		for e: Dictionary in batch["events"]:
			if String(e.get("rarity", "")) == "legendary":
				legs += 1
		events_per.append(evs)
		since += 1
		var dry := since  # check-ins since last legendary, counting this one (pre-reset)
		for _li in range(legs):
			legendary_gaps.append(since)
			since = 0
		total_legendaries += legs
		rows.append("%d,%d,%d,%d,%d" % [c + 1, c / 3 + 1, evs, legs, dry])

	print("  check-ins:            %d over 42 days" % checkins)
	print("  mean events/check-in: %.2f   (min %d)" % [_mean(events_per), _min_int(events_per)])
	print("  total legendaries:    %d" % total_legendaries)
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

	_write_csv("user://chase.csv", rows)
	print("  per-check-in CSV: " + ProjectSettings.globalize_path("user://chase.csv"))
	print("    chart it: python3 tools/chart_chase.py <that path>")


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
