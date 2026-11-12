# Fishing and Regional Examination screens

Open `res://Scene/UI/fishing_ui.tscn` or `res://Scene/UI/exam_ui.tscn` to edit the native Godot controls. Both use the existing wood, button, and parchment textures. The local Theme and StyleBox resources are editable in the Inspector; no generated mockup bitmap is used as a panel.

Panel/Layout contains Title, StatusRow, Paper, and Footer. Paper/ScrollContainer/Content contains QuestionLabel, optional QuestionImage, and ChoicesContainer. Answer buttons are created from the original choices, in the original order, with A/B/C/D display labels and at least 52 pixels height. Longer lists continue with letters or numeric labels beyond Z. The first answer receives keyboard focus, while the question opens scrolled to the top so focus does not skip the reading text. Long questions and answers scroll vertically.

`Scripts/UI/QuestionCardPresentation.gd` shares only font setup, safe-area layout, choice construction, optional image display, and initial focus. It uses Godot's bundled font family with an independent smooth font cache. It contains no grading, timers, points, quest, or progression rules. The two existing UI scripts retain their manager/event connections. Both roots still process while gameplay is paused.

## Fishing

Points initialize from FishingManager when the card opens. Difficulty remains the current DDA tier. The separate Review Question banner identifies mini quests without changing question text. HintPanel shows only the authored hint after the existing DDA-controlled Hint button is pressed. Hint availability is still evaluated once per displayed question, preserving the Medium-tier frequency counter. No new hints or educational content were authored.

Answering hides the card before calling the existing main/mini submission method. Wrong answers can immediately display a related review question; correct mini answers restore the original question. Correct main answers preserve the reeling animation. ToastUI shows the authored explanation after a main or review answer. For a successful catch it appears after reeling, and the item notification waits until the explanation closes. Dismiss, a click or tap anywhere, or the reading timeout closes the explanation.

QuestionImage now exists for the image field already supported by FishingUI. Missing or non-texture resources leave the slot hidden. The existing `r1_001` question references missing `res://Assets/Sprites/Questions/iced_fish.png`; no replacement image was invented.

## Regional examination

The header shows the actual question number and total. The progress bar counts answered questions, so the final unanswered question does not imply the exam is complete. Results use the manager-provided pass/fail, percentage, correct count, and existing progression/retry message. Continue closes the existing result overlay. No early-exit button, hints, countdown, new attempt limits, passing thresholds, or automatic retry were added. ExamManager remains responsible for scoring, unlocking, history, and pause state.

## Validation

Six focused GUT tests cover Easy/Medium/Hard hints and their frequency, image fallback, main-to-review-to-original fishing flow, hiding before reeling, duplicate submission guard, actual passing/failing exam history and scores, focus, scroll reset, and desktop/landscape/portrait bounds. Renders at 1200×760, 720×360, and 390×844 were inspected for both question screens and exam results. Physical Android touch, device safe areas, and font rendering remain manual validation.
