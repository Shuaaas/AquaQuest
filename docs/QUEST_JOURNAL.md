# Quest Journal

Click the HUD quest card, or choose Menu → Quests. Menu → Performance still opens the existing Performance Board.

The journal reads existing quests; it never starts, completes, claims, abandons, or rewards them. Active and Completed tabs show recorded quests, with a Failed tab only when failed records exist. Main and mini quests share the list. Objective targets come from QuestObjectiveManager, including its current DDA multiplier. Ready/completed objectives use the saved completion flag and recorded counts, without inventing historical DDA targets.

Quest descriptions and item rewards come from the quest JSON. Giver and location use existing world-map metadata when absent from the quest definition; missing metadata says “Not specified.” This screen does not add educational content.

## Editing the UI

Open `res://Scene/UI/QuestJournalUI.tscn` in Godot. Frame → Layout contains Header, Tabs, Columns, and Footer. Columns contains Navigation (quest list) and Paper (scrollable details). Shared local Theme and StyleBox resources at the top of the scene control colors, borders, textures, and spacing. Existing wood/button/parchment textures are reused.

Dynamic quest rows and reading text are populated by `Scripts/UI/QuestJournalUI.gd`. `Scripts/UI/QuestJournalData.gd` prepares read-only display data. Below 700 pixels wide, the list and details are separate views with a Quest list back button. Close/Escape releases only the pause owned by this journal.

## Validation

GUT tests cover data accuracy, unchanged quest/inventory data, pause ownership, empty/completed states, phone navigation, Escape, and desktop layout after wrapping. Existing HUD tests cover shortcut routing and the separate Performance entry. Desktop and phone renders were inspected; the live editor game was checked for open/pause/close and unchanged quests. Physical Android touch and safe-area testing remain manual.
