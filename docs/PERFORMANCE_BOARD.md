# Performance Board reference design

The board uses native Control nodes in `Scene/UI/performance_board.tscn`: dark brown
header/footer, warm brown content, rounded summary cards, cream/gold typography,
region status badges, exam history and quest records. All static styles and layout
remain editable in the Godot Inspector. `PixelUIStyle` is no longer attached to this
scene because its runtime pixel theme would override this board-specific design.
No shared theme or other interface was changed.

The reference says Completion, but the existing value measures answer accuracy.
The card therefore says Answer accuracy. Its progress bar represents correct answers
out of answered questions. The other performance totals are lifetime stats.
Latest quest AQPI shows “—” until a quest with recorded answers is turned in.
The score uses answers recorded while the quest was active. Up to 2 minutes of
answering earns the full 20 time points, which then decrease by 2.5 per minute
until reaching zero at 10 minutes. DDA uses the finished quest's score to select
a tier. Five correct answers in a row can still raise the tier during play.

Actual region names/unlock states come from RegionManager. Future undefined regions
are omitted. Existing known quest/exam ID lists remain unchanged, so this redesign
does not claim complete coverage of future content. Quest records include tracked
statuses rather than claiming every displayed quest is completed. Empty sections
show honest empty-state messages. Refresh removes old rows from their containers
before queuing them for deletion, preventing duplicate rows and stale empty counts.

On narrow windows below 440 pixels the cards stack into one column and the header's
Player Record badge hides. Content scrolls vertically; the Close button stays outside
the scroll area with a 48-pixel minimum height. The existing CSV export callback and
hidden Export button remain. The existing Quest Journal shortcut still scrolls to
the QuestContainer, and closing releases the HUD-owned pause as before.

Files changed:
- Scene/UI/performance_board.tscn: editable scene layout and local theme.
- Scripts/UI/PerformanceBoard.gd: card presentation, responsive columns, record rows.
- Assets/UI/HUDReference/performance-region.svg, performance-exam.svg,
  performance-journal.svg: original small gold line icons, plus Godot import metadata.
- test/unit/test_performance_board.gd: updated bindings and three additional tests.
- docs/PERFORMANCE_BOARD.md: this guide.

Verification: all five focused Performance Board tests pass. Full GUT suite:
122/125 pass; the same three Region 1 layout failures remain unrelated to this work
(test/unit/test_region1_layout.gd:106,170,189-190). Automated checks cover visible
startup, reopening, actual tracker bindings, absence of scoring side effects,
row replacement/empty states, responsive columns, scrolling and the Close button.
Desktop renders inspected at 390x844, 600x900, 856x428 and 1280x720. The real Godot
editor loads the scene and the main game's HUD opens the redesigned board. Actual
Android device usability, display cutouts and long populated histories remain manual
checks. No dependencies, settings, managers, gameplay scenes or scoring rules changed.

## Shared UI consistency pass
The outer frame now uses Assets/UI/HUDReference/wood.svg. Buttons use
Assets/UI/HUDReference/button.svg with 12-pixel nine-slice borders and subtle
hover/pressed tinting, matching the newer Shop and Quest Journal framing.
The board uses the same bundled font family with smooth anti-aliasing and an
independent glyph cache, matching the newer question screens. Local card styles,
layout, data, scoring, and progression are unchanged. No shared theme file changed.
