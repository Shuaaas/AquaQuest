extends Marker2D
## Optional editor-placed marker for a dock, shop, exam, or precise objective.
## Existing NPCs, fishing spots and region exits are discovered automatically.

@export var title: String = "Location"
@export_enum("location", "shop", "exam", "fishing") var marker_kind: String = "location"
@export var quest_id: String = ""
## -1 means any pending objective on the configured quest.
@export var objective_index: int = -1
