extends Node
## EventBus (Autoload Singleton)
##
## Central signal hub for AquaQuest. Every cross-system communication should
## flow through here instead of managers holding direct references to each
## other. This keeps the architecture decoupled (SOLID: Dependency Inversion)
## and makes it trivial to add new listeners without touching existing code.
##
## USAGE:
##   EventBus.quest_completed.emit(quest_id)
##   EventBus.quest_completed.connect(_on_quest_completed)
##
## Do NOT put logic here. This script only declares and re-broadcasts signals.

# --- Game flow ---
signal game_started
signal game_paused(is_paused: bool)
signal game_over(reason: String)

# --- Scene / region flow ---
signal scene_load_requested(scene_path: String)
signal scene_load_started(scene_path: String)
signal scene_load_finished(scene_path: String)
signal region_changed(old_region_id: String, new_region_id: String)
signal region_unlocked(region_id: String)

# --- Save / load ---
signal save_requested(slot: int)
signal save_completed(slot: int)
signal load_requested(slot: int)
signal load_completed(slot: int)

# --- Quests ---
signal quest_started(quest_id: String)
signal quest_updated(quest_id: String, progress: Dictionary)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

# --- Dialogue ---
signal dialogue_started(dialogue_id: String)
signal dialogue_line_shown(speaker: String, text: String)
signal dialogue_choice_made(choice_index: int)
signal dialogue_ended(dialogue_id: String)
# Added for the NPC framework's branching dialogue support (DialogueManager.gd).
# Purely additive - no existing signal above was changed, so anything already
# connected to dialogue_line_shown/dialogue_choice_made keeps working as-is.
signal dialogue_choices_presented(choices: Array)   ## filtered, condition-passing choices for the current node
signal dialogue_portrait_changed(portrait_path: String)
signal dialogue_voice_requested(voice_clip_id: String) ## future voice support hook, unused until voice assets exist
signal dialogue_action_triggered(action: Dictionary)   ## e.g. {"type": "start_quest"} - NPC role components react to this

# --- Inventory ---
signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal inventory_changed

# --- Exams / Questions (educational core loop) ---
signal exam_started(exam_id: String)
signal question_answered(question_id: String, was_correct: bool)
signal exam_completed(exam_id: String, score: float)

# --- Dynamic Difficulty Adjustment ---
signal difficulty_adjusted(new_difficulty_tier: int, reason: String)

# --- Shop (MerchantComponent, part of the NPC framework) ---
signal shop_opened(merchant: Node)
signal shop_closed
signal item_purchased(item_id: String, price: int)
signal item_sold(item_id: String, price: int)

# --- Audio ---
signal play_sfx_requested(sfx_id: String)
signal play_music_requested(track_id: String, fade_time: float)
signal stop_music_requested(fade_time: float)

# --- UI ---
signal ui_screen_pushed(screen_id: String)
signal ui_screen_popped(screen_id: String)
signal ui_notification_requested(message: String, duration: float)

# --- Player: spawn / position (added for Player System) ---
signal player_spawned(spawn_id: String)

# --- Player: interaction prompts (added for Player System) ---
## Emitted by PlayerInteractionComponent whenever the "nearest interactable"
## changes, so an interaction-prompt UI ("Press E to talk") can react
## without ever referencing the player. Empty prompt_text means "clear prompt".
signal interactable_focus_changed(prompt_text: String)

# --- Player: equipment (added for Player System) ---
## item_id == "" means the player unequipped whatever they had equipped.
signal equipment_changed(item_id: String)

# --- Fishing (added for Player System) ---
signal fishing_started(spot_id: String)
signal fishing_denied(spot_id: String, reason: String)
signal fishing_ended(spot_id: String, success: bool)
# Added for FishingManager: broadcasts the question a fishing UI should
# display once FishingManager has picked one via QuestionManager. Submitting
# an answer goes through FishingManager.submit_answer() directly (a request,
# not a broadcast), same pattern as DialogueManager.advance()/choose().
signal fishing_question_ready(spot_id: String, question: Dictionary)
