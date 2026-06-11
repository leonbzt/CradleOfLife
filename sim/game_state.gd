class_name GameState
extends RefCounted

## The whole save, one plain-data object (VISION.md keystone §4; arch §2).
## RefCounted, never a Node: it runs headless, serializes to JSON, and the UI
## is a pure function of it. All mutations go through named commands elsewhere
## so every change is replayable and testable.

## Bumped whenever the save layout changes. A save written by an old client must
## still load in a new one — the Tree never resets across years of patches
## (VISION.md §14). Migration logic lives in migrate_and_load() below.
const SCHEMA_VERSION: int = 2

var schema_version: int = SCHEMA_VERSION
var master_seed: int = 0
var lineages: Array[Lineage] = []
var slots_active: int = 2
var slots_max: int = 2
var inventory_materials: Dictionary = {}   # material_id -> qty (float)
var genes_known: Dictionary = {}           # gene_id -> int copy count
var splice_offers: Array[Dictionary] = []  # [{gene: String, node: String}]
var last_seen_unix: int = 0
# RNG stream positions (stream_name -> state as String; see Rng.export_state).
var rng_streams: Dictionary = {}


func lineage_by_id(lineage_id: String) -> Lineage:
	for l: Lineage in lineages:
		if l.id == lineage_id:
			return l
	return null


func to_dict() -> Dictionary:
	var lineages_out: Array = []
	for l: Lineage in lineages:
		lineages_out.append(l.to_dict())
	return {
		"schema_version": schema_version,
		"master_seed": master_seed,
		"lineages": lineages_out,
		"slots_active": slots_active,
		"slots_max": slots_max,
		"inventory_materials": inventory_materials.duplicate(),
		"genes_known": genes_known.duplicate(),
		"splice_offers": splice_offers.duplicate(true),
		"last_seen_unix": last_seen_unix,
		"rng_streams": rng_streams.duplicate(),
	}


static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.schema_version = int(d.get("schema_version", SCHEMA_VERSION))
	s.master_seed = int(d.get("master_seed", 0))
	s.slots_active = int(d.get("slots_active", 2))
	s.slots_max = int(d.get("slots_max", 2))
	s.inventory_materials = (d.get("inventory_materials", {}) as Dictionary).duplicate()
	s.last_seen_unix = int(d.get("last_seen_unix", 0))
	s.rng_streams = (d.get("rng_streams", {}) as Dictionary).duplicate()
	for k: Variant in d.get("genes_known", {}):
		s.genes_known[String(k)] = int((d["genes_known"] as Dictionary).get(k, 0))
	for offer: Variant in d.get("splice_offers", []):
		if offer is Dictionary:
			s.splice_offers.append((offer as Dictionary).duplicate())
	for ld: Variant in d.get("lineages", []):
		s.lineages.append(Lineage.from_dict(ld as Dictionary))
	return s


## Applies schema migrations then constructs the GameState. Called by
## state_store.gd so the UI load path always passes through here.
static func migrate_and_load(d: Dictionary) -> GameState:
	var v := int(d.get("schema_version", 1))
	if v == 1:
		d = _migrate_v1_to_v2(d)
	return from_dict(d)


static func _migrate_v1_to_v2(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out["schema_version"] = 2

	# Fold old inventory_genes + genes_known (both were Array[String]) into
	# the new genes_known dict of id -> count.
	var counts: Dictionary = {}
	for g: Variant in d.get("inventory_genes", []):
		var id := String(g)
		counts[id] = int(counts.get(id, 0)) + 1
	for g: Variant in d.get("genes_known", []):
		var id := String(g)
		counts[id] = int(counts.get(id, 0)) + 1
	out["genes_known"] = counts
	out.erase("inventory_genes")
	out.erase("niches_unlocked")
	out["splice_offers"] = []
	return out
