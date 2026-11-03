# AquaQuest — Codex Instructions

## Project
AquaQuest is a 2D educational RPG made with Godot 4.5 and GDScript.
It teaches Post-Harvest Fisheries to Fisheries and Aquatic Science students.

## Existing implementation
This project was previously developed with Claude-generated code.
Treat existing project files as the source of truth.
Do not assume planned features are already implemented or working.

## Core gameplay
- NPCs introduce lessons and give quests.
- Fishing interactions lead to educational questions.
- Correct answers progress fishing or quests.
- Incorrect answers support learning through review or mini-quests.
- The game tracks points, accuracy, completion, and performance.
- Dynamic Difficulty Adjustment (DDA) adapts question difficulty.
- Regional examinations control progression.
- The game may include inventory, a learning Codex, customization,
  shops, a performance board, and a world map.

## Architecture rules
- Inspect existing scripts, scenes, resources, autoloads, and signals
  before creating or changing systems.
- Preserve the existing architecture and folder structure.
- Keep UI, gameplay logic, managers, and data responsibilities separate.
- Verify node paths, signals, resources, and APIs in the actual project.
- Follow existing naming and coding conventions.

## Safety rules
- Never regenerate the whole project.
- Do not delete, rename, or move existing files without approval.
- Do not replace working systems without evidence.
- Do not modify unrelated features when fixing a bug.
- Do not add plugins or dependencies without approval.
- Do not change established gameplay or DDA rules without approval.
- Do not add combat or fighting mechanics.
- Preserve mobile-friendly UI and Android compatibility.

## Workflow
1. Inspect relevant files first.
2. Explain the proposed changes and affected files.
3. During the initial audit, make no file changes.
4. Implement only the approved task.
5. Review the diff and run appropriate checks.
6. Report changed files, test results, and remaining issues.
7. Distinguish automated checks from manual Godot testing.
## Development toolkit
- Reuse existing managers, components, signals, and resources; avoid duplicate systems.
- Use Godot 4.5 and GDScript, native Control nodes, modular scenes, reusable components,
  and signals between independent systems. Maintain mobile-friendly layouts.
- Use UI/UX Pro Max as a design reference, translating guidance into native Godot UI.
  Do not generate React, HTML, Tailwind, or web interfaces for the actual game.
- Preserve the existing pixel-art RPG appearance and palette; prioritize readability
  and usability over generic design recommendations.
- Apply Ponytail's minimal implementation principles without removing necessary
  validation, accessibility, or tests. Avoid unnecessary dependencies and abstractions.
- Preserve fishing, quests, dialogue, DDA, inventory, shops, and progression.
- Godot MCP requires the AquaQuest editor open with the addon enabled. Confirm the
  connected project path before calling tools. Do not use tools to bypass task scope
  or approval requirements. Do not trust lifecycle hooks automatically.
- Godot executable: `D:/Download/Godot_v4.5.1-stable_mono_win64/Godot_v4.5.1-stable_mono_win64/Godot_v4.5.1-stable_mono_win64.exe`.


## Skill Activation Rules

- Use Ponytail principles for coding, debugging,
  and refactoring tasks.
- Use UI/UX Pro Max for HUD, inventory, menus,
  maps, dialogue, and other interface designs.
- Use Godot MCP when inspecting or interacting
  with actual Godot scenes and the editor.
- Use i-have-adhd when explicitly requested or
  when concise, step-by-step guidance is useful.
- Do not force unrelated skills into a task.
- Never sacrifice existing AquaQuest architecture
  or gameplay functionality to follow a generic skill.
