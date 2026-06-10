class_name Accrual
extends RefCounted

## Closed-form offline accrual (VISION.md §12; arch invariant, IMPLEMENTATION.md
## §1). NEVER frame-ticks elapsed time. Materials integrate in closed form;
## rare gene events are sampled as a Poisson process via exponential
## inter-arrivals from a per-lineage RNG stream. Cost is O(number of events),
## not O(number of ticks over the gap.)
##
## Two properties this buys us, both load-bearing:
##  - Reproducible: re-running the same gap with the same seed yields the same
##    events, so what an offline batch grants matches what a notification
##    predicted (VISION.md §16).
##  - Predictable: because we know the inter-arrival distribution, we can compute
##    when the NEXT notable event lands and schedule a local notification for it
##    with no server (deferred to Phase 4 — not built here).
##
## Uses the SAME rate helpers as Resolve, so there is no second economy.


## Accrue `dt` seconds of offline time for every working lineage in `state`.
## Returns { "materials": {id->qty}, "events": Array[Dictionary] } where each
## event is {t, lineage, node, gene, rarity}, sorted by time.
static func accrue(state: GameState, content: Content, dt: float, rng: Rng) -> Dictionary:
	var materials: Dictionary = {}
	var events: Array[Dictionary] = []

	for lineage in state.lineages:
		if lineage.graduated or lineage.assigned_node == "":
			continue
		var node: Dictionary = content.node(lineage.assigned_node)
		if node.is_empty():
			continue

		var mat_id: String = String(node.get("material", ""))
		if mat_id != "":
			var gained: float = Resolve.material_rate(lineage, node) * dt
			materials[mat_id] = float(materials.get(mat_id, 0.0)) + gained

		var rate: float = Resolve.gene_rate(lineage, node)
		var stream_name: String = "gene_accrue:" + lineage.id
		var t: float = rng.exp_interval(stream_name, rate)
		while t < dt:
			var g: Dictionary = Resolve.roll_gene(node, rng)
			var event: Dictionary = {
				"t": t,
				"lineage": lineage.id,
				"node": String(node.get("id", "")),
				"gene": String(g.get("id", "")),
				"rarity": String(g.get("rarity", "common")),
			}
			events.append(event)
			t += rng.exp_interval(stream_name, rate)

	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"])
	return {"materials": materials, "events": events}
