class_name Validation
extends RefCounted

## Content gate 1 — orthogonality (VISION.md §17, IMPLEMENTATION.md §3), plus
## structural sanity. Automated; runs in CI via tests/validate_data.gd and at
## boot via data_loader.gd. The moat is a small set of mechanically DISTINCT
## primitives, so this gate's job is to reject "the same affix with a new noun".
##
## Phase 2: strict term→role map (CANONICAL_TERMS), param shape checks,
## express_cost validation, gene rarity + uniqueness, drop-table rarity
## normalization, and niche/node structural checks.
##
## Returns a list of human-readable error strings; empty means pass.

const ROLES: Array[String] = [
	"affliction", "control", "guard", "sustain", "perception", "penetration", "stealth"
]
const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
const ATTRIBUTES: Array[String] = ["vitality", "power", "resilience", "metabolism", "instinct"]

## Canonical math_term → orthogonal_role mapping. This is the engine vocabulary;
## a new term in data must fail loudly (PHASE2.md §3, WP3).
const CANONICAL_TERMS: Dictionary = {
	"pen_flat": "penetration",
	"dot_floor": "affliction",
	"danger_guard": "guard",
	"splice_mult": "control",
	"uptime_mult": "sustain",
	"find_mult": "perception",
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
	errors.append_array(validate_class_tree(content))
	errors.append_array(validate_categories(content))
	return errors


## Gate 1 proper. Every affix must:
##  - declare a canonical math_term and the role it maps to
##  - carry required params for its term
##  - carry a express_cost pointing at a real material
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
					(
						"affix '%s' math_term '%s' maps to role '%s' but orthogonal_role is '%s'"
						% [id, term, expected_role, role]
					)
				)
			# Param shape check
			var params: Dictionary = row.get("params", {})
			var required: Array = TERM_PARAMS.get(term, [])
			for pkey: Variant in required:
				if not params.has(String(pkey)):
					errors.append(
						"affix '%s' missing required param '%s' for term '%s'" % [id, pkey, term]
					)
				elif typeof(params[String(pkey)]) not in [TYPE_INT, TYPE_FLOAT]:
					errors.append("affix '%s' param '%s' must be numeric" % [id, pkey])
			if not by_term.has(term):
				by_term[term] = []
			by_term[term].append(row)

		# express_cost required
		var gc: Dictionary = row.get("express_cost", {})
		if gc.is_empty():
			errors.append("affix '%s' missing express_cost" % id)
		else:
			if float(gc.get("base", 0.0)) <= 0.0:
				errors.append("affix '%s' express_cost.base must be > 0" % id)
			if float(gc.get("growth", 0.0)) < 1.0:
				errors.append("affix '%s' express_cost.growth must be >= 1" % id)

		if not row.has("source"):
			errors.append("affix '%s' asserts a capability but has no 'source' (gate 2)" % id)

		# Slot affinity: must name >= 1 valid doll slot (VISION §7). A gene that
		# expresses nowhere is unreachable; one that expresses anywhere is a stat-dump.
		var slots: Array = row.get("slots", [])
		if slots.is_empty():
			errors.append("affix '%s' missing 'slots' (which organs it expresses on)" % id)
		else:
			for s: Variant in slots:
				if not Lineage.SLOTS.has(String(s)):
					errors.append("affix '%s' slot '%s' is not a known doll slot" % [id, s])

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
					(
						"affix '%s' is unlocked by both '%s' and '%s' (must be unique)"
						% [affix_id, affix_unlockers[affix_id], id]
					)
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
		# `feeds` (Option A WP3): which attribute the organ's tier grows. "" is the
		# gland (affix host, no base attribute); any other value must be a real one.
		if row.has("feeds"):
			var feeds := String(row.get("feeds", ""))
			if feeds != "" and not ATTRIBUTES.has(feeds):
				errors.append("adaptation '%s' feeds unknown attribute '%s'" % [id, feeds])
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
						(
							"drop_table '%s' gene '%s' rarity '%s' ≠ gene def rarity '%s'"
							% [table_id, gene, table_rarity, def_rarity]
						)
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


## Class tree: structure, attribute names, niche refs, buff >= 1.0, no-trap check.
## An empty class_tree passes (WP3/WP4 transition; no tree = no class rules yet).
static func validate_class_tree(content: Content) -> Array[String]:
	var errors: Array[String] = []
	var rows: Array = content.tables.get("class_tree", [])
	if rows.is_empty():
		return errors

	var seen_ids: Dictionary = {}
	var root_count := 0
	var attr_names: Array[String] = ["vitality", "power", "resilience", "metabolism", "instinct"]
	var niche_ids: Dictionary = {}
	for n: Dictionary in content.tables.get("niches", []):
		niche_ids[String(n.get("id", ""))] = true

	for row: Dictionary in rows:
		var id := String(row.get("id", ""))
		if id == "":
			errors.append("class_tree row missing 'id': " + JSON.stringify(row))
			continue
		if seen_ids.has(id):
			errors.append("duplicate class id: " + id)
		seen_ids[id] = true

		var parent := String(row.get("parent", ""))
		if parent == "":
			root_count += 1
		elif not seen_ids.has(parent):
			# parent might appear later — validated in cycle check below
			pass

		var stat_mods: Dictionary = row.get("stat_mods", {})
		for stat: Variant in stat_mods:
			if not attr_names.has(String(stat)):
				errors.append("class '%s' stat_mods key '%s' is not a valid attribute" % [id, stat])
			elif float(stat_mods[stat]) <= 0.0:
				errors.append("class '%s' stat_mods.%s must be > 0" % [id, stat])

		for niche: Variant in row.get("home_niches", []):
			if not niche_ids.has(String(niche)):
				errors.append("class '%s' home_niches '%s' is not a known niche" % [id, niche])

		var nm: Dictionary = row.get("niche_mult", {})
		for key in ["material", "gene"]:
			if nm.has(key) and float(nm[key]) < 1.0:
				errors.append(
					"class '%s' niche_mult.%s must be >= 1.0 (buff, never nerf)" % [id, key]
				)

		for key: Variant in (row.get("requires", {}) as Dictionary).get("affix_keys", []):
			if not ROLES.has(String(key)):
				errors.append(
					"class '%s' requires.affix_keys '%s' is not a known role" % [id, String(key)]
				)

		if not row.has("source"):
			errors.append("class '%s' has no 'source'" % id)

	# Exactly one root.
	if rows.size() > 0 and root_count != 1:
		errors.append("class_tree must have exactly one root (parent == ''); found %d" % root_count)

	# Every non-root parent references a real class; graph is connected; no cycles.
	for row: Dictionary in rows:
		var id := String(row.get("id", ""))
		var parent := String(row.get("parent", ""))
		if parent != "" and not seen_ids.has(parent):
			errors.append("class '%s' parent '%s' does not exist" % [id, parent])

	# Cycle detection: BFS/walk from every node, ensure we reach root.
	for row: Dictionary in rows:
		var id := String(row.get("id", ""))
		var cur := String(row.get("parent", ""))
		var visited: Dictionary = {id: true}
		while cur != "":
			if visited.has(cur):
				errors.append("class_tree has a cycle involving '%s'" % id)
				break
			visited[cur] = true
			var cur_row := content.class_node(cur)
			cur = String(cur_row.get("parent", ""))

	# No-trap-build check: every class's allowed categories must cover every essential slot.
	var essential_slots: Array[String] = [
		"mouthparts", "integument", "locomotion", "metabolic_core", "sensory"
	]
	for row: Dictionary in rows:
		var class_id := String(row.get("id", ""))
		var allowed := _walk_categories(class_id, content)
		for slot: String in essential_slots:
			var covered := false
			for ad: Dictionary in content.tables.get("adaptations", []):
				if String(ad.get("slot", "")) == slot:
					var cat := String(ad.get("category", "generalist"))
					if allowed.has(cat):
						covered = true
						break
			if not covered:
				(
					errors
					. append(
						(
							"no-trap check: class '%s' has no accessible adaptation for essential slot '%s'"
							% [class_id, slot]
						)
					)
				)
	return errors


## Category cross-checks: every category in unlocks_categories must be used by
## >= 1 adaptation or affix; every non-generalist category used by gear must be
## unlocked by >= 1 class (PHASE3.md §4.3).
static func validate_categories(content: Content) -> Array[String]:
	var errors: Array[String] = []
	# Collect all categories declared in any class's unlocks_categories.
	var class_unlocked: Dictionary = {}  # category -> true
	for row: Dictionary in content.tables.get("class_tree", []):
		for cat: Variant in row.get("unlocks_categories", []):
			class_unlocked[String(cat)] = true

	# Collect all categories used by gear.
	var gear_cats: Dictionary = {}  # category -> true
	for ad: Dictionary in content.tables.get("adaptations", []):
		var cat := String(ad.get("category", "generalist"))
		gear_cats[cat] = true
	for af: Dictionary in content.tables.get("affixes", []):
		var cat := String(af.get("category", "generalist"))
		gear_cats[cat] = true

	# Every unlocked category must be used by >= 1 piece of gear.
	for cat: String in class_unlocked:
		if not gear_cats.has(cat):
			(
				errors
				. append(
					(
						"class unlocks category '%s' but no adaptation or affix uses it (unreachable unlock)"
						% cat
					)
				)
			)

	# Every non-generalist gear category must be unlocked by >= 1 class.
	for cat: String in gear_cats:
		if cat == "generalist":
			continue
		if not class_unlocked.has(cat):
			errors.append(
				"gear uses category '%s' but no class unlocks it (unbuildable gear)" % cat
			)
	return errors


## Collect the full set of allowed categories for `class_id` (generalist + all
## unlocks along the ancestor chain). Same logic as content.allowed_categories()
## but operates directly on the content tables without a Lineage object.
static func _walk_categories(class_id: String, content: Content) -> Dictionary:
	var cats: Dictionary = {"generalist": true}
	var visited: Dictionary = {}
	var cid := class_id
	while cid != "" and not visited.has(cid):
		visited[cid] = true
		var row := content.class_node(cid)
		if row.is_empty():
			break
		for cat: Variant in row.get("unlocks_categories", []):
			cats[String(cat)] = true
		cid = String(row.get("parent", ""))
	return cats


static func _same_params(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)
