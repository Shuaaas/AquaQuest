extends Node
## FishingAreaManager (Autoload Singleton)
##
## Single responsibility: load Fishing Area / Fishing Location definitions
## from JSON and answer "what does this location require and offer" -
## nothing more. It doesn't run the fishing flow (FishingManager's job),
## doesn't grade questions (QuestionManager's job), and doesn't check rod
## equip state itself (FishingRodComponent's job) - it's a pure data
## lookup, the same role RegionManager plays for regions.
##
## MAPPING FROM YOUR BRIEF'S 7 REQUIREMENTS:
##   Water Area          -> not a separate script/object. This is the
##                          physical water tilemap layer + where you place
##                          the FishingSpot's CollisionShape2D in the
##                          scene - a level-design/art concern, not data.
##   Fishing Spot         -> FishingSpot.gd (unchanged role, now optionally
##                          references a location_id defined here)
##   Fish Spawn Data       -> the weighted "fish_species" list below
##   Available Fish Species -> same "fish_species" list (species + weight
##                          together ARE the spawn data - one field, not two)
##   Required Rod          -> "required_rod_id", checked via
##                          FishingRodComponent.get_equipped_rod_id()
##   Related Lesson        -> "lesson_id", passed straight into
##                          QuestionManager.get_random_question()'s
##                          existing lesson_id parameter
##   Question Pool          -> optional "question_pool" array of specific
##                          question ids, passed into
##                          QuestionManager.get_random_question()'s new
##                          (Phase 8) allowed_ids parameter
##
## DATA LOCATION: Data/JSON/FishingAreas/*.json
##
## EXPECTED JSON SHAPE:
##   {
##     "location_id": "region1_dock_north",
##     "required_rod_id": "fishing_rod",
##     "lesson_id": "post_harvest_basics",
##     "question_pool": [],
##     "fish_species": [
##       { "fish_id": "tilapia", "weight": 5 },
##       { "fish_id": "milkfish", "weight": 1 }
##     ]
##   }
## `question_pool` empty means "any question matching lesson_id/tier" (no
## extra restriction). `required_rod_id` empty means "any equipped rod is
## fine" (today, that's a moot distinction - only one rod item exists).

const FISHING_AREAS_JSON_DIR := "res://Data/JSON/FishingAreas/"

# location_id -> location definition Dictionary
var _locations: Dictionary = {}


func _ready() -> void:
	var dir := DirAccess.open(FISHING_AREAS_JSON_DIR)
	if dir == null:
		push_warning("FishingAreaManager: no FishingAreas JSON directory found yet at %s" % FISHING_AREAS_JSON_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_location_file(FISHING_AREAS_JSON_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_location_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("location_id"):
		_locations[parsed["location_id"]] = parsed
	else:
		push_warning("FishingAreaManager: %s missing required field 'location_id'" % path)


## Returns {} if no location with this id was loaded - callers (FishingSpot,
## FishingManager) treat that as "no location data, use per-instance/
## default behavior" rather than an error, so a FishingSpot with no
## location_id set keeps working exactly as it did before this phase.
func get_location(location_id: String) -> Dictionary:
	return _locations.get(location_id, {})


## Weighted random pick from a location's fish_species list. Returns ""
## if the location has no species defined - caller falls back to its own
## default in that case.
func pick_weighted_species(location_id: String) -> String:
	var location := get_location(location_id)
	var species: Array = location.get("fish_species", [])
	if species.is_empty():
		return ""

	var total_weight := 0
	for entry in species:
		total_weight += int(entry.get("weight", 1))

	if total_weight <= 0:
		return ""

	var roll := randi() % total_weight
	var cumulative := 0
	for entry in species:
		cumulative += int(entry.get("weight", 1))
		if roll < cumulative:
			return entry.get("fish_id", "")

	return ""
