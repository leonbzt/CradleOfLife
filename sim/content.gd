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
