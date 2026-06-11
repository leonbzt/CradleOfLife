class_name Validation
extends RefCounted

## Content gate 1 — orthogonality (VISION.md §17, IMPLEMENTATION.md §3), plus
## structural sanity. Automated; runs in CI via tests/validate_data.gd and at
## boot via data_loader.gd. The moat is a small set of mechanically DISTINCT
## primitives, so this gate's job is to reject "the same affix with a new noun".
##
## Phase 2: strict term→role map (CANONICAL_TERMS), param shape checks,
## graft_cost validation, gene rarity + uniqueness, drop-table rarity
## normalization, and niche/node structural checks.
##
## Returns a list of human-readable error strings; empty means pass.

const ROLES: Array[String] = [
	"dot", "control", "mitigation", "uptime", "find", "penetration", "stealth"
]
const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]

## Canonical math_term → orthogonal_role mapping. This is the engine vocabulary;
## a new term in data must fail loudly (PHASE2.md §3, WP3).
const CANONICAL_TERMS: Dictionary = {
	"pen_flat": "penetration",
	"dot_floor": "dot",
	"danger_guard": "mitigation",
	"splice_mult": "control",
	"uptime_mult": "uptime",
	"find_mult": "find",
	"ambush_frac": "stealth",
}

## Required numeric param keys per math_term.
const TERM_PARAMS: Dictionary = {
	"pen_flat": ["amount"],
	"dot_floor": ["tick_pct"],
	"danger_guard": ["amount"],
	"splice_mult": ["mult"],
	"uptime_mult": ["mult"],
	"find_mult": ["mult"],
	"ambush_frac": ["frac"],
}


static func validate(content: Content) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(validate_affixes(content.tables.get("affixes", [])))
	errors.append_array(validate_genes(content))
	errors.append_array(validate_materials(content.tables.get("materials", [])))
	errors.append_array(validate_adaptations(content))
	errors.append_array(validate_drop_tables(content))
	errors.append_array(validate_niches(content))
	errors.append_array(validate_nodes(content))
	return errors


## Gate 1 proper. Every affix must:
##  - declare a canonical math_term and the role it maps to
##  - carry required params for its term
##  - carry a graft_cost pointing at a real material
##  - carry a source
##  - not share a math_term+params combo with another affix (synonym check)
static func validate_affixes(affixes: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	var by_term: Dictionary = {}  # math_term -> Array[row]

	for row: Dictionary in affixes:
		var id := String(row.get("id", ""))
		if id == "":
			errors.append("affix row missing 'id': " + JSON.stringify(row))
			continue
		if seen_ids.has(id):
			errors.append("duplicate affix id: " + id)
		seen_ids[id] = true

		var role := String(row.get("orthogonal_role", ""))
		if not ROLES.has(role):
			errors.append("affix '%s' has invalid/missing orthogonal_role '%s'" % [id, role])

		var term := String(row.get("math_term", ""))
		if term == "":
			errors.append("affix '%s' missing math_term" % id)
		elif not CANONICAL_TERMS.has(term):
			errors.append(
				"affix '%s' math_term '%s' is not in the canonical term registry" % [id, term]
			)
		else:
			var expected_role: String = CANONICAL_TERMS[term]
			if role != expected_role:
				errors.append(
					"affix '%s' math_term '%s' maps to role '%s' but orthogonal_role is '%s'"
					% [id, term, expected_role, role]
				)
			# Param shape check
			var params: Dictionary = row.get("params", {})
			var required: Array = TERM_PARAMS.get(term, [])
			for pkey: Variant in required:
				if not params.has(String(pkey)):
					errors.append("affix '%s' missing required param '%s' for term '%s'" % [id, pkey, term])
				elif typeof(params[String(pkey)]) not in [TYPE_INT, TYPE_FLOAT]:
					errors.append("affix '%s' param '%s' must be numeric" % [id, pkey])
			if not by_term.has(term):
				by_term[term] = []
			by_term[term].append(row)

		# graft_cost required
		var gc: Dictionary = row.get("graft_cost", {})
		if gc.is_empty():
			errors.append("affix '%s' missing graft_cost" % id)
		else:
			if float(gc.get("base", 0.0)) <= 0.0:
				errors.append("affix '%s' graft_cost.base must be > 0" % id)
			if float(gc.get("growth", 0.0)) < 1.0:
				errors.append("affix '%s' graft_cost.growth must be >= 1" % id)

		if not row.has("source"):
			errors.append("affix '%s' asserts a capability but has no 'source' (gate 2)" % id)

	# Synonym check: same term, identical params
	for term: String in by_term:
		var rows: Array = by_term[term]
		for i in range(rows.size()):
			for j in range(i + 1, rows.size()):
				if _same_params(rows[i].get("params", {}), rows[j].get("params", {})):
					var a := String(rows[i].get("id", ""))
					var b := String(rows[j].get("id", ""))
					errors.append("suspected synonyms (math_term '%s'): '%s', '%s'" % [term, a, b])
	return errors


## Every gene must have: rarity in RARITIES; unlocks.kind == "affix";
## unlocks.id references a real affix; no two genes unlock the same affix.
static func validate_genes(content: Content) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	var affix_unlockers: Dictionary = {}  # affix_id -> gene_id (uniqueness check)

	for row: Dictionary in content.tables.get("genes", []):
		var id := String(row.get("id", ""))
		if id == "":
			errors.append("gene row missing 'id': " + JSON.stringify(row))
			continue
		if seen_ids.has(id):
			errors.append("duplicate gene id: " + id)
		seen_ids[id] = true

		var rarity := String(row.get("rarity", ""))
		if not RARITIES.has(rarity):
			errors.append("gene '%s' missing or invalid rarity '%s'" % [id, rarity])

		var unlocks: Dictionary = row.get("unlocks", {})
		if unlocks.is_empty():
			errors.append("gene '%s' missing 'unlocks'" % id)
		else:
			if String(unlocks.get("kind", "")) != "affix":
				errors.append("gene '%s' unlocks.kind must be 'affix'" % id)
			var affix_id := String(unlocks.get("id", ""))
			if content.affix(affix_id).is_empty():
				errors.append("gene '%s' unlocks affix '%s' which does not exist" % [id, affix_id])
			elif affix_unlockers.has(affix_id):
				errors.append(
					"affix '%s' is unlocked by both '%s' and '%s' (must be unique)"
					% [affix_id, affix_unlockers[affix_id], id]
				)
			else:
				affix_unlockers[affix_id] = id

		if not row.has("source"):
			errors.append("gene '%s' has no 'source'" % id)
	return errors


## Materials must have unique ids and rarities capped at "rare".
static func validate_materials(materials: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	for row: Dictionary in materials:
		var id := String(row.get("id", ""))
		if id == "":
			errors.append("material row missing 'id': " + JSON.stringify(row))
			continue
		if seen_ids.has(id):
			errors.append("duplicate material id: " + id)
		seen_ids[id] = true
		var rarity := String(row.get("rarity", ""))
		if not RARITIES.has(rarity):
			errors.append("material '%s' has invalid/missing rarity '%s'" % [id, rarity])
		elif RARITIES.find(rarity) > RARITIES.find("rare"):
			errors.append("material '%s' rarity '%s' exceeds 'rare' (genes only)" % [id, rarity])
	return errors


## Adaptations must socket a real slot, have a sane build_cost, and max_tier >= 1.
static func validate_adaptations(content: Content) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	for row: Dictionary in content.tables.get("adaptations", []):
		var id := String(row.get("id", ""))
		if id == "":
			errors.append("adaptation row missing 'id': " + JSON.stringify(row))
			continue
		if seen_ids.has(id):
			errors.append("duplicate adaptation id: " + id)
		seen_ids[id] = true
		if not Lineage.SLOTS.has(String(row.get("slot", ""))):
			errors.append("adaptation '%s' has unknown slot '%s'" % [id, row.get("slot", "")])
		var cost: Dictionary = row.get("build_cost", {})
		if cost.is_empty():
			errors.append("adaptation '%s' missing build_cost" % id)
		else:
			var mat := String(cost.get("material", ""))
			if content.material(mat).is_empty():
				errors.append("adaptation '%s' build_cost uses unknown material '%s'" % [id, mat])
			if float(cost.get("base", 0.0)) <= 0.0:
				errors.append("adaptation '%s' build_cost.base must be > 0" % id)
			if float(cost.get("growth", 0.0)) < 1.0:
				errors.append("adaptation '%s' build_cost.growth must be >= 1" % id)
		if int(row.get("max_tier", 0)) < 1:
			errors.append("adaptation '%s' max_tier must be >= 1" % id)
	return errors


## Drop tables: every gene reference must exist, and the rarity in each row
## must match the gene def's canonical rarity (one source of truth).
static func validate_drop_tables(content: Content) -> Array[String]:
	var errors: Array[String] = []
	var drop_tables: Dictionary = content.tables.get("drop_tables", {})

	for table_id: String in drop_tables:
		for row: Dictionary in drop_tables[table_id]:
			var gene := String(row.get("gene", ""))
			var gene_row := content.gene(gene)
			if gene_row.is_empty():
				errors.append("drop_table '%s' drops unknown gene '%s'" % [table_id, gene])
			else:
				var table_rarity := String(row.get("rarity", ""))
				var def_rarity := String(gene_row.get("rarity", ""))
				if table_rarity != def_rarity:
					errors.append(
						"drop_table '%s' gene '%s' rarity '%s' ≠ gene def rarity '%s'"
						% [table_id, gene, table_rarity, def_rarity]
					)
	return errors


## Niches: affix_keys must be a subset of ROLES.
static func validate_niches(content: Content) -> Array[String]:
	var errors: Array[String] = []
	for row: Dictionary in content.tables.get("niches", []):
		var id := String(row.get("id", ""))
		for key: Variant in row.get("affix_keys", []):
			if not ROLES.has(String(key)):
				errors.append("niche '%s' affix_key '%s' is not a known role" % [id, key])
	return errors


## Nodes: niche exists; fight nodes have danger >= 0; spliceable references a
## known gene; splice_rate > 0 requires spliceable; drop_table/material refs valid.
static func validate_nodes(content: Content) -> Array[String]:
	var errors: Array[String] = []
	var drop_tables: Dictionary = content.tables.get("drop_tables", {})

	for node: Dictionary in content.tables.get("nodes", []):
		var node_id := String(node.get("id", ""))
		var kind := String(node.get("kind", "eat"))

		var niche_id := String(node.get("niche", ""))
		if niche_id != "" and content.niche(niche_id).is_empty():
			errors.append("node '%s' references unknown niche '%s'" % [node_id, niche_id])

		if node.has("danger"):
			if kind != "fight":
				errors.append("node '%s' has danger but kind is not 'fight'" % node_id)
			if float(node.get("danger", 0.0)) < 0.0:
				errors.append("node '%s' danger must be >= 0" % node_id)

		var table_id := String(node.get("drop_table", ""))
		if table_id != "" and not drop_tables.has(table_id):
			errors.append("node '%s' references unknown drop_table '%s'" % [node_id, table_id])

		var mat_id := String(node.get("material", ""))
		if mat_id != "" and content.material(mat_id).is_empty():
			errors.append("node '%s' yields unknown material '%s'" % [node_id, mat_id])

		var splice_rate := float(node.get("splice_rate", 0.0))
		var spliceable := String(node.get("spliceable", ""))
		if splice_rate > 0.0 and spliceable == "":
			errors.append("node '%s' has splice_rate > 0 but no spliceable" % node_id)
		if spliceable != "" and content.gene(spliceable).is_empty():
			errors.append("node '%s' spliceable '%s' is not a known gene" % [node_id, spliceable])
	return errors


static func _same_params(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)
