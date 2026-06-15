class_name Content
extends RefCounted

## Loads all content JSON from a directory and exposes it as plain dictionaries.
## Pure and Node-free so the headless tests and the boot-time autoload share ONE
## load path — there is no second loader to drift. Content is data; the engine
## that consumes it (resolve/accrue) is small and hand-written (VISION.md §17).

const FILES: Array[String] = [
	"affixes",
	"adaptations",
	"genes",
	"materials",
	"niches",
	"nodes",
	"drop_tables",
	"skills",
]

# Parsed tables, keyed by the file stem above. Lists of row dicts, except
# drop_tables which is { table_id -> Array[row] }.
var tables: Dictionary = {}


## Loads + post-processes every content file under `dir_path` (e.g. "res://data").
## Inlines each node's drop table so resolve()/accrue() stay self-contained.
static func load_dir(dir_path: String) -> Content:
	var c := Content.new()
	for key in FILES:
		c.tables[key] = _load_json(dir_path.path_join(key + ".json"))
	c._inline_drop_tables()
	return c


func node(node_id: String) -> Dictionary:
	return _row("nodes", node_id)


func adaptation(adaptation_id: String) -> Dictionary:
	return _row("adaptations", adaptation_id)


func material(material_id: String) -> Dictionary:
	return _row("materials", material_id)


func niche(niche_id: String) -> Dictionary:
	return _row("niches", niche_id)


func skill(skill_id: String) -> Dictionary:
	return _row("skills", skill_id)


## All skill rows (data/skills.json). The engine reads these to drive XP, the
## yield multiplier, and danger mitigation — there are no hardcoded skill ids in
## resolve(); skills are content (VISION §17).
func skills() -> Array:
	return tables.get("skills", [])


func affix(affix_id: String) -> Dictionary:
	return _row("affixes", affix_id)


func gene(gene_id: String) -> Dictionary:
	return _row("genes", gene_id)


## Returns the unique gene that unlocks the given affix, or {} if none.
func gene_for_affix(affix_id: String) -> Dictionary:
	for g: Dictionary in tables.get("genes", []):
		if String((g.get("unlocks", {}) as Dictionary).get("id", "")) == affix_id:
			return g
	return {}


## Where a gene can be obtained: every node that drops it (in its gene_table) or
## offers it as a splice. Powers the legibility panels (VISION §11: see the wall
## AND the key). Returns [{node, name, niche, via:[\"drop\"|\"splice\"]}].
func sources_for_gene(gene_id: String) -> Array:
	var out: Array = []
	for n: Dictionary in tables.get("nodes", []):
		var via: Array[String] = []
		for row: Dictionary in n.get("gene_table", []):
			if String(row.get("gene", "")) == gene_id:
				via.append("drop")
				break
		if String(n.get("spliceable", "")) == gene_id:
			via.append("splice")
		if not via.is_empty():
			(
				out
				. append(
					{
						"node": String(n.get("id", "")),
						"name": String(n.get("name", "")),
						"niche": String(n.get("niche", "")),
						"via": via,
					}
				)
			)
	return out


## The affixes that satisfy an affix-key `role`, paired with the gene that unlocks
## each. Used by the niche key panel to tell the player exactly which gene opens a
## locked niche.
func key_affixes_for_role(role: String) -> Array:
	var out: Array = []
	for af: Dictionary in tables.get("affixes", []):
		if String(af.get("orthogonal_role", "")) != role:
			continue
		out.append({"affix": af, "gene": gene_for_affix(String(af.get("id", "")))})
	return out


func _row(table: String, row_id: String) -> Dictionary:
	for r: Dictionary in tables.get(table, []):
		if r.get("id", "") == row_id:
			return r
	return {}


func _inline_drop_tables() -> void:
	var drop_tables: Dictionary = tables.get("drop_tables", {})
	for n: Dictionary in tables.get("nodes", []):
		var table_id: String = n.get("drop_table", "")
		if table_id != "" and drop_tables.has(table_id):
			n["gene_table"] = drop_tables[table_id]


static func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Content: cannot open " + path)
		return null
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("Content: malformed JSON in " + path)
	return parsed
