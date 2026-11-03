# Dialogue presentation

The dialogue UI uses the same wood, button, and parchment textures as the Shop and Quest Journal. NPC names appear on a wooden nameplate; the reading area uses dark brown text on parchment. Buttons keep cream text, focus borders, and at least 48-pixel height. No new artwork, portraits, dependencies, educational text, or dialogue branches were added.

## Edit in Godot

Open `res://Scene/UI/dialogue_ui.tscn`. DialoguePanel/Layout contains SpeakerRow/Nameplate, Paper, and Footer. Paper/ScrollContainer/Content contains DialogueTextLabel and ChoicesContainer. Footer contains the hint and the compact Continue button. These are native editable Control nodes. Local Theme/StyleBox resources control the wood and parchment appearance. Change DialogueTextLabel font size and line spacing in the Inspector; dynamic choice button styling is in `Scripts/UI/dialogue_ui.gd`.

The display script keeps the box near the bottom with a bounded width and checks mobile display safe areas. Text and responses scroll together; Continue stays outside the scrolling content. On short landscape screens, the choice-only footer is hidden to preserve reading space. The font uses Godot's existing bundled font family with smooth rendering.

## Behavior retained and checked

DialogueManager still owns advance/choose and NPCManager still owns actions. The UI does not pause or resume the game, start quests, or grant rewards. Each new line clears old response controls and resets scroll position. Continue or the first response receives keyboard focus; initial focus does not skip long reading text. Closing the dialogue restores the previous visible control's focus. A pending deferred update cannot reveal Continue after the dialogue ends.

Six focused GUT tests exercise real linear and branching flow, response indices, focus restoration, touch target heights, long text and scroll reset, bounds at 1200×760, 720×360, and 390×844, deferred closing, and existing foreign pause ownership. Desktop and phone renders were visually inspected. A live editor conversation was checked without choosing quest actions. Physical Android touch, safe areas, and device font rendering remain manual checks.
