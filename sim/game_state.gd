class_name GameState
extends RefCounted

## The whole save, one plain-data object (VISION.md keystone §4; arch §2).
## RefCounted, never a Node: it runs headless, serializes to JSON, and the UI
## is a pure function of it. All mutations go through named commands elsewhere
## so every change is replayable and testable.

## Bumped whenever the save layout changes. A save written by an old client must
## still load in a new one — the Tree never resets across years of patches
## (VISION.md §14). Migration logic lives in state_store.gd when first needed.
const SCHEMA_VERSION: int = 1

var schema_version: int = SCHEMA_VERSION
var master_seed: int = 0  # seeds every Rng stream; stored so accrual is replayable
var lineages: Array[Lineage] = []
var slots_active: int = 2
var slots_max: int = 2
var inventory_materials: Dictionary = {}  # material_id -> qty (float)
var inventory_genes: Array[String] = []
var genes_known: Array[String] = []
var niches_unlocked: Array[String] = []
var last_seen_unix: int = 0


func lineage_by_id(lineage_id: String) -> Lineage:
	for l in lineages:
		if l.id == lineage_id:
			return l
	return null


func to_dict() -> Dictionary:
	var lineages_out: Array = []
	for l in lineages:
		lineages_out.append(l.to_dict())
	return {
		"schema_version": schema_version,
		"master_seed": master_seed,
		"lineages": lineages_out,
		"slots_active": slots_active,
		"slots_max": slots_max,
		"inventory_materials": inventory_materials.duplicate(),
		"inventory_genes": inventory_genes.duplicate(),
		"genes_known": genes_known.duplicate(),
		"niches_unlocked": niches_unlocked.duplicate(),
		"last_seen_unix": last_seen_unix,
	}


static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.schema_version = int(d.get("schema_version", SCHEMA_VERSION))
	s.master_seed = int(d.get("master_seed", 0))
	s.slots_active = int(d.get("slots_active", 2))
	s.slots_max = int(d.get("slots_max", 2))
	s.inventory_materials = (d.get("inventory_materials", {}) as Dictionary).duplicate()
	s.last_seen_unix = int(d.get("last_seen_unix", 0))
	for x: Variant in d.get("inventory_genes", []):
		s.inventory_genes.append(String(x))
	for x: Variant in d.get("genes_known", []):
		s.genes_known.append(String(x))
	for x: Variant in d.get("niches_unlocked", []):
		s.niches_unlocked.append(String(x))
	for ld: Variant in d.get("lineages", []):
		s.lineages.append(Lineage.from_dict(ld))
	return s
