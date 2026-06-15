class_name Accrual
extends RefCounted

## Closed-form offline accrual (VISION.md §12; arch invariant, IMPLEMENTATION.md
## §1). NEVER frame-ticks elapsed time. Materials integrate in closed form;
## rare gene events are sampled as a Poisson process via exponential
## inter-arrivals from a per-lineage RNG stream — O(events), not O(ticks).
##
## Two load-bearing properties:
##  - Reproducible: re-running the same gap with the same seed yields the same
##    events, so what an offline batch grants matches what a notification
##    predicted (VISION.md §16).
##  - Predictable: because we know the inter-arrival distribution, we can compute
##    when the NEXT notable event lands and schedule a local notification for it
##    with no server (deferred to Phase 4 — not built here).
##
## Phase 2: splice offers are sampled as a second Poisson stream per lineage.
## Events carry a `kind` field: "gene" or "splice". Application of splice offers
## to the save (claim_splice) is Phase 2 commands; application of the batch to
## the save state is Phase 4 (offline catch-up UI). The harness counts both.
##
## Uses the SAME rate helpers as Resolve — no second economy.


## Accrue `dt` seconds of offline time for every working lineage in `state`.
## Returns { "materials": {id->qty}, "events": Array[Dictionary] } where each
## event is {kind, t, lineage, node, gene, rarity?}, sorted by time.
static func accrue(state: GameState, content: Content, dt: float, rng: Rng) -> Dictionary:
	var materials: Dictionary = {}
	var events: Array[Dictionary] = []
	var skill_xp: Dictionary = {}  # lineage_id -> {skill_id -> xp}

	for lineage: Lineage in state.lineages:
		if lineage.graduated or lineage.assigned_node == "":
			continue
		var node := content.node(lineage.assigned_node)
		if node.is_empty():
			continue

		var mat_id := String(node.get("material", ""))
		if mat_id != "":
			var gained := Resolve.material_rate(lineage, node, content) * dt
			materials[mat_id] = float(materials.get(mat_id, 0.0)) + gained

		# Skill XP integrates closed-form like materials (rate · dt), per lineage.
		var sx := Resolve.skill_xp_for_node(node, content)
		if not sx.is_empty():
			var per: Dictionary = {}
			for sid: String in sx:
				per[sid] = float(sx[sid]) * dt
			skill_xp[lineage.id] = per

		var gene_rate := Resolve.gene_rate(lineage, node, content)
		var gene_stream := "gene_accrue:" + lineage.id
		var t := rng.exp_interval(gene_stream, gene_rate)
		while t < dt:
			var g := Resolve.roll_gene(node, rng)
			(
				events
				. append(
					{
						"kind": "gene",
						"t": t,
						"lineage": lineage.id,
						"node": String(node.get("id", "")),
						"gene": String(g.get("id", "")),
						"rarity": String(g.get("rarity", "common")),
					}
				)
			)
			t += rng.exp_interval(gene_stream, gene_rate)

		var splice_rate := Resolve.splice_rate_eff(lineage, node, content)
		if splice_rate > 0.0:
			var splice_stream := "splice_accrue:" + lineage.id
			var ts := rng.exp_interval(splice_stream, splice_rate)
			while ts < dt:
				(
					events
					. append(
						{
							"kind": "splice",
							"t": ts,
							"lineage": lineage.id,
							"node": String(node.get("id", "")),
							"gene": String(node.get("spliceable", "")),
						}
					)
				)
				ts += rng.exp_interval(splice_stream, splice_rate)

	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"])
	return {"materials": materials, "events": events, "skill_xp": skill_xp}
