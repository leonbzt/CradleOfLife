class_name Validation
extends RefCounted

## Content gate 1 — orthogonality (VISION.md §17, IMPLEMENTATION.md §3), plus
## structural sanity. Automated; runs in CI via tests/validate_data.gd and at
## boot via data_loader.gd. The moat is a small set of mechanically DISTINCT
## primitives, so this gate's job is to reject "the same affix with a new noun".
##
## Returns a list of human-readable error strings; empty means pass.

const ROLES: Array[String] = [
	"dot", "control", "mitigation", "uptime", "find", "penetration", "stealth"
]
const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]


static func validate(content: Content) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(validate_affixes(content.tables.get("affixes", [])))
	errors.append_array(validate_materials(content.tables.get("materials", [])))
	errors.append_array(validate_adaptations(content))
	errors.append_array(validate_node_refs(content))
	return errors


## Gate 1 proper. Every affix must declare a known orthogonal_role and the
## math_term it modifies, and carry a source (it asserts a real capability).
## Two affixes on the same math_term must DIFFER in params, or they are flagged
## as suspected synonyms. A math_term must map to exactly one role.
static func validate_affixes(affixes: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	var term_to_role: Dictionary = {}
	var by_term: Dictionary = {}  # math_term -> Array[row]

	for row: Dictionary in affixes:
		var id: String = String(row.get("id", ""))
		if id == "":
			errors.append("affix row missing 'id': " + JSON.stringify(row))
			continue
		if seen_ids.has(id):
			errors.append("duplicate affix id: " + id)
		seen_ids[id] = true

		var role: String = String(row.get("orthogonal_role", ""))
		if not ROLES.has(role):
			errors.append("affix '%s' has invalid/missing orthogonal_role '%s'" % [id, role])

		var term: String = String(row.get("math_term", ""))
		if term == "":
			errors.append("affix '%s' missing math_term" % id)
		else:
			if not by_term.has(term):
				by_term[term] = []
			by_term[term].append(row)
			if term_to_role.has(term) and term_to_role[term] != role:
				var other: String = term_to_role[term]
				errors.append("math_term '%s' maps to 2 roles ('%s', '%s')" % [term, other, role])
			else:
				term_to_role[term] = role

		if not row.has("source"):
			errors.append("affix '%s' asserts a capability but has no 'source' (gate 2)" % id)

	for term: String in by_term:
		var rows: Array = by_term[term]
		for i in range(rows.size()):
			for j in range(i + 1, rows.size()):
				if _same_params(rows[i].get("params", {}), rows[j].get("params", {})):
					var a: String = String(rows[i].get("id", ""))
					var b: String = String(rows[j].get("id", ""))
					errors.append("suspected synonyms (math_term '%s'): '%s', '%s'" % [term, a, b])
	return errors


## Materials are the loot players see every check-in: each must have a unique id
## and a known rarity colour, capped at "rare" — epic/legendary colours belong to
## the gene chase (VISION.md §9), and this gate keeps a data row from quietly
## promoting a crafting mat into jackpot colours.
static func validate_materials(materials: Array) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	for row: Dictionary in materials:
		var id: String = String(row.get("id", ""))
		if id == "":
			errors.append("material row missing 'id': " + JSON.stringify(row))
			continue
		if seen_ids.has(id):
			errors.append("duplicate material id: " + id)
		seen_ids[id] = true
		var rarity: String = String(row.get("rarity", ""))
		if not RARITIES.has(rarity):
			errors.append("material '%s' has invalid/missing rarity '%s'" % [id, rarity])
		elif RARITIES.find(rarity) > RARITIES.find("rare"):
			errors.append("material '%s' rarity '%s' exceeds 'rare' (genes only)" % [id, rarity])
	return errors


## Every adaptation must socket a real doll slot and carry a sane Metabolize
## cost in a material that exists — a broken cost would strand the player with
## gear they can never build.
static func validate_adaptations(content: Content) -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	for row: Dictionary in content.tables.get("adaptations", []):
		var id: String = String(row.get("id", ""))
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
			var mat: String = String(cost.get("material", ""))
			if content.material(mat).is_empty():
				errors.append("adaptation '%s' build_cost uses unknown material '%s'" % [id, mat])
			if float(cost.get("base", 0.0)) <= 0.0:
				errors.append("adaptation '%s' build_cost.base must be > 0" % id)
			if float(cost.get("growth", 0.0)) < 1.0:
				errors.append("adaptation '%s' build_cost.growth must be >= 1" % id)
		if int(row.get("max_tier", 0)) < 1:
			errors.append("adaptation '%s' max_tier must be >= 1" % id)
	return errors


## Structural integrity so the loader fails loudly, not the player: nodes point
## at drop tables and materials that exist, and every gene a table can drop is
## defined.
static func validate_node_refs(content: Content) -> Array[String]:
	var errors: Array[String] = []
	var drop_tables: Dictionary = content.tables.get("drop_tables", {})
	var gene_ids: Dictionary = {}
	for g: Dictionary in content.tables.get("genes", []):
		gene_ids[String(g.get("id", ""))] = true

	for node: Dictionary in content.tables.get("nodes", []):
		var node_id: String = String(node.get("id", ""))
		var table_id: String = String(node.get("drop_table", ""))
		if table_id != "" and not drop_tables.has(table_id):
			errors.append("node '%s' references unknown drop_table '%s'" % [node_id, table_id])
		var mat_id: String = String(node.get("material", ""))
		if mat_id != "" and content.material(mat_id).is_empty():
			errors.append("node '%s' yields unknown material '%s'" % [node_id, mat_id])

	for table_id: String in drop_tables:
		for row: Dictionary in drop_tables[table_id]:
			var gene: String = String(row.get("gene", ""))
			if not gene_ids.has(gene):
				errors.append("drop_table '%s' drops unknown gene '%s'" % [table_id, gene])
	return errors


static func _same_params(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)
