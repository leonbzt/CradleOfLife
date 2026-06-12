class_name Lineage
extends RefCounted

## One playable branch of the Tree, expressed as a current organism you level,
## gear, and class up like an RPG hero (VISION.md §7). Pure data: the UI is a
## function of it, never the other way around.

## The equipment doll — body-part slots, each socketing one adaptation
## (VISION.md §7). Exact set is an open dial (§20); this is the v1 default.
const SLOTS: Array[String] = [
	"mouthparts",
	"integument",
	"locomotion",
	"sensory",
	"metabolic_core",
	"gland",
]

## How many distinct affixes each organ can express at once (VISION.md §7).
## Surface-rich, segmented organs hold many (integument plating/spines, the
## serial appendages of locomotion); focused tools hold few (mouthparts, the
## single sensory apparatus). This is what turns the doll from a stat-dump into
## a body with trade-offs — an organ is venomous OR armoured, not both at once.
## Open dial (§20.3); widen per organ as content grows.
const SLOT_EXPRESS_CAP: Dictionary = {
	"mouthparts": 2,
	"integument": 3,
	"locomotion": 3,
	"sensory": 1,
	"metabolic_core": 2,
	"gland": 2,
}

var id: String
var display_name: String
var kingdom: String = "animal"  # animals only in v1 (VISION.md §13)
var attributes: Dictionary = {
	"vitality": 1.0,
	"power": 1.0,
	"resilience": 1.0,
	"metabolism": 1.0,
	"instinct": 1.0,
}
var doll: Dictionary = {}  # slot_id: String -> AdaptationInstance
var skills: Dictionary = {}  # skill_id: String -> xp (float)
var class_node: String = "generalist"
var assigned_node: String = ""  # which world node this lineage is working
var graduated: bool = false


func _init(p_id: String = "", p_display_name: String = "") -> void:
	id = p_id
	display_name = p_display_name


func equip(slot: String, adaptation: AdaptationInstance) -> void:
	assert(slot in SLOTS, "unknown equipment slot: " + slot)
	doll[slot] = adaptation


func to_dict() -> Dictionary:
	var doll_out: Dictionary = {}
	for slot: String in doll:
		doll_out[slot] = (doll[slot] as AdaptationInstance).to_dict()
	return {
		"id": id,
		"display_name": display_name,
		"kingdom": kingdom,
		"attributes": attributes.duplicate(),
		"doll": doll_out,
		"skills": skills.duplicate(),
		"class_node": class_node,
		"assigned_node": assigned_node,
		"graduated": graduated,
	}


static func from_dict(d: Dictionary) -> Lineage:
	var l := Lineage.new(String(d.get("id", "")), String(d.get("display_name", "")))
	l.kingdom = String(d.get("kingdom", "animal"))
	l.attributes = (d.get("attributes", {}) as Dictionary).duplicate()
	l.skills = (d.get("skills", {}) as Dictionary).duplicate()
	l.class_node = String(d.get("class_node", "generalist"))
	l.assigned_node = String(d.get("assigned_node", ""))
	l.graduated = bool(d.get("graduated", false))
	for slot: String in d.get("doll", {}):
		l.doll[slot] = AdaptationInstance.from_dict(d["doll"][slot])
	return l
