extends SceneTree

## Headless unit test for niches-with-teeth (WP1, WORKORDER_NICHE_TEETH.md):
##   godot --headless --script res://tests/teeth_test.gd
##
## Each niche pays out a SIGNATURE attribute as its throughput multiplier (VISION §11),
## and genes feed attributes (a guard gene → resilience), so doll + genes both build the
## throughput a build laps its home niche with. Power stays universal access.

var _failures: Array[String] = []


func _initialize() -> void:
	var content := Content.load_dir("res://data")
	var errors := Validation.validate(content)
	if not errors.is_empty():
		push_error("content failed validation; aborting teeth test")
		for e in errors:
			print("  - " + e)
		quit(1)
		return

	_test_genes_feed_attributes(content)
	_test_niche_signature_throughput(content)
	_test_off_home_is_baseline_not_penalty(content)
	_test_two_niches_two_homes(content)

	if _failures.is_empty():
		print("== teeth test: PASS ==")
		quit(0)
	else:
		print("== teeth test: FAIL (%d) ==" % _failures.size())
		for f in _failures:
			print("  - " + f)
		quit(1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures.append(what)


## Genes feed attributes too: expressing a guard affix (plating) raises resilience.
func _test_genes_feed_attributes(content: Content) -> void:
	var l := Lineage.new("g", "G")
	l.equip("integument", AdaptationInstance.new("calcite_carapace", 1))
	var before := float(Resolve.effective_attributes(l, content).get("resilience", 1.0))
	(l.doll["integument"] as AdaptationInstance).affixes.append({"id": "plating_minor", "tier": 2})
	var after := float(Resolve.effective_attributes(l, content).get("resilience", 1.0))
	_check(after > before, "teeth: a guard gene (plating) feeds resilience")


## The niche's signature attribute is its throughput multiplier: in the benthos
## (resilience), a tank out-yields an equal-everything-else metabolism build.
func _test_niche_signature_throughput(content: Content) -> void:
	var node := content.node("microbial_mat")  # shallow_benthos -> signature = resilience
	var tank := Lineage.new("t", "T")
	tank.attributes["resilience"] = 5.0
	var swimmer := Lineage.new("s", "S")
	swimmer.attributes["metabolism"] = 5.0
	_check(
		Resolve.material_rate(tank, node, content) > Resolve.material_rate(swimmer, node, content),
		"teeth: in the benthos a resilience build out-yields a metabolism build"
	)


## Off-home is the baseline, never a penalty: a metabolism build in the benthos still
## yields at least the bare-lineage baseline (its low resilience floors at 1.0).
func _test_off_home_is_baseline_not_penalty(content: Content) -> void:
	var node := content.node("microbial_mat")
	var swimmer := Lineage.new("s", "S")
	swimmer.attributes["metabolism"] = 5.0  # off-home stat
	var bare := Lineage.new("b", "B")
	_check(
		Resolve.material_rate(swimmer, node, content) >= Resolve.material_rate(bare, node, content),
		"teeth: an off-signature build is never below the baseline (no penalty)"
	)


## WP2 — two builds, two homes: the whole point of un-parking pelagic. A metabolism
## (filter) build laps the OPEN WATER (signature metabolism); a resilience (tank) build
## laps the BENTHOS (signature resilience) — each strictly out-yields the other AT HOME.
func _test_two_niches_two_homes(content: Content) -> void:
	var benthos := content.node("microbial_mat")  # signature resilience
	var pelagic := content.node("plankton_bloom")  # signature metabolism
	var tank := Lineage.new("t", "T")
	tank.attributes["resilience"] = 5.0
	var filter := Lineage.new("f", "F")
	filter.attributes["metabolism"] = 5.0
	_check(
		(
			Resolve.material_rate(filter, pelagic, content)
			> Resolve.material_rate(tank, pelagic, content)
		),
		"teeth: in the open water a metabolism build out-yields a resilience build"
	)
	_check(
		(
			Resolve.material_rate(tank, benthos, content)
			> Resolve.material_rate(filter, benthos, content)
		),
		"teeth: in the benthos a resilience build out-yields a metabolism build (the mirror)"
	)
