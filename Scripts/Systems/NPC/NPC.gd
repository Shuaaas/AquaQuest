extends Interactable
class_name NPC
## NPC
##
## Thin Interactable subclass for any NPC in the world - Teacher, Fisher,
## Merchant, Examiner, or Villager. Deliberately has NO per-type subclass
## and NO branching logic here: every difference between NPC types is
## DATA (see Data/JSON/NPC/<npc_id>.json and its linked dialogue tree in
## Data/JSON/Dialogue/), not code. Adding a 6th NPC type later never
## requires a new script - only new JSON content.
##
## `npc_type` is metadata only - useful for picking a sprite/animation set
## or filtering NPCs, but never checked by this script's own logic. All
## real behavior differences (what an NPC teaches, what quest it gives,
## whether it evaluates an exam, etc.) live entirely in the dialogue
## tree's per-state conditions and actions, interpreted by NPCManager.
##
## NPCs never fight - there is no health/damage capability here or
## anywhere in this script, by design, matching the rest of the project.

## Must match the "npc_id" field in exactly one Data/JSON/NPC/*.json file.
@export var npc_id: String = ""

## Metadata only - see class doc above. Extend this list in the Inspector
## dropdown if a 6th type is ever needed; no script change required.
@export_enum("teacher", "fisher", "merchant", "examiner", "villager") var npc_type: String = "villager"


func _ready() -> void:
	super._ready()
	add_to_group("npcs")


func interact(interactor: Node) -> void:
	if not enabled:
		return
	interacted.emit(interactor)
	NPCManager.start_conversation(npc_id, interactor, self)
