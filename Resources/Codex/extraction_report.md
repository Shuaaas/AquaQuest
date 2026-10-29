# AquaQuest Codex extraction report

Prepared 2026-10-28 from the five existing PDFs in `res://docs/modules/`. This is a content conversion, not a claim that a Codex gameplay system exists.

## Completion and source inventory

All 48 PDF pages were processed. No source page remains unprocessed. Text and visual inspection were used together. The missing supplementary lectures described below were never included in these PDFs; their absence is not hidden by a completion claim.

| Source | Source module/lesson title | Pages | Codex lessons | Supplied images |
| --- | --- | ---: | ---: | ---: |
| `docs/modules/Module_1.pdf` | INTRODUCTION TO POST-HARVEST FISHERIES | 20 | 4 | 25 |
| `docs/modules/Module_2.pdf` | FISH AND OTHER AQUATIC SPECIES AS RAW MATERIAL | 7 | 4 | 1 |
| `docs/modules/Module_3.pdf` | FISH SPOILAGE | 5 | 7 | 4 |
| `docs/modules/Module_4.pdf` | TRADITIONAL FISH PROCESSING METHODS | 13 | 4 | 11 |
| `docs/modules/Module_5.pdf` | METHODS OF FISH PRESERVATION | 3 | 5 | 0 |

Module 1 uses its printed Lesson 1 title; the cover course title is Post-Harvest Fisheries. Module 2 uses its printed Lesson 2 title. The remaining module titles are printed topic titles. IDs are conversion identifiers, not claims about the source author's lesson numbering.

The duplicate PDFs under `Resources/Lessons/` were not converted a second time. The thesis proposal was not used as educational lesson content.

## Lesson organization

### module_1: INTRODUCTION TO POST-HARVEST FISHERIES

- `module_1_lesson_1` — INTRODUCTION TO POST-HARVEST FISHERIES; PDF pages 3, 4.
- `module_1_lesson_2` — STATUS OF PHILIPPINE FISHERY AND THE CURRENT TRENDS; PDF pages 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16.
- `module_1_lesson_3` — FISHERIES POST HARVEST LOSSES IN THE PHILIPPINES; PDF pages 16, 17.
- `module_1_lesson_4` — POST HARVEST MACHINERIES AND EQUIPMENT; PDF pages 18, 19.

### module_2: FISH AND OTHER AQUATIC SPECIES AS RAW MATERIAL

- `module_2_lesson_1` — FISH COMPOSITION AND MUSCULATURE; PDF pages 2, 3.
- `module_2_lesson_2` — Composition of Fish; PDF pages 3, 4.
- `module_2_lesson_3` — Post mortem Changes and Fish Quality Assurance Methods; PDF pages 4, 5, 6.
- `module_2_lesson_4` — IDEAL FISHING GEAR AND METHODS FOR GOOD QUALITY FISH CATCH; PDF pages 6, 7.

### module_3: FISH SPOILAGE

- `module_3_lesson_1` — Fish Spoilage; PDF pages 1.
- `module_3_lesson_2` — BACTERIA; PDF pages 1, 2.
- `module_3_lesson_3` — MOLDS; PDF pages 2, 3.
- `module_3_lesson_4` — YEAST; PDF pages 3.
- `module_3_lesson_5` — ENZYMES; PDF pages 3.
- `module_3_lesson_6` — CHEMICAL SPOILAGE; PDF pages 4.
- `module_3_lesson_7` — Changes of Fish after Death; PDF pages 4.

### module_4: TRADITIONAL FISH PROCESSING METHODS

- `module_4_lesson_1` — FISH CURING; PDF pages 1.
- `module_4_lesson_2` — SALTING; PDF pages 1, 2, 3.
- `module_4_lesson_3` — DRYING; PDF pages 4, 5, 6, 7.
- `module_4_lesson_4` — SMOKING; PDF pages 8, 9, 10, 11, 12, 13.

### module_5: METHODS OF FISH PRESERVATION

- `module_5_lesson_1` — TEMPERATURE CONTROL; PDF pages 1.
- `module_5_lesson_2` — USE OF ADDITIVES; PDF pages 2.
- `module_5_lesson_3` — USE OF PACKAGING TECHNOLOGIES; PDF pages 2.
- `module_5_lesson_4` — REMOVAL OF MOISTURE; PDF pages 2.
- `module_5_lesson_5` — OTHER PROCESSING METHODOLOGIES; PDF pages 2.

## Extraction and preservation decisions

- Full lesson text was retained between explicitly identified topic boundaries, rather than replaced by summaries. The conversion checked that all cleaned text spans were assigned before representing the table and fraction in structured/plain-text form. A section can span several pages; `page_coverage.json` accounts separately for every source page.
- Repeated running headers, repeated decorative cover artwork, blank lines, and tiny bullet images were excluded from educational content. Module objectives and author/institution credits are retained as metadata. Presentation bullets were normalized and wrapped lines rejoined; original wording, percentages, ratios, scientific spellings and source typographical errors were otherwise retained.
- Some PDF headings appear after their body in the extracted text order. Their placement was restored through lesson/section metadata. A short EPA/DHA callout on Module 2 page 3 was placed in the fat/lipids section, with the source wording retained.
- The source fraction in Module 4 page 4 is represented as `%Moisture = (Wd / Wf) x 100`, with its original variable labels. A faithful image is also supplied. No replacement scientific formula was invented.
- The ten-row fresh/stale comparison on Module 3 page 4 is available both as structured table data and a faithful image. Its source values, including pH and water-test statements, were preserved and flagged for review.
- The other statistical tables are embedded raster graphics. They are preserved as PNG assets, not transcribed into invented or uncertain numeric rows. Original split-table parts remain separate assets. A future viewer must show the supplied images to present their full numerical content.
- Every exported visual is a crop of the original PDF rendered at 216 dpi. No diagram was redrawn or reconstructed. Source caption/credit text is retained where present. Image checksums and bounding boxes are in `asset_manifest.json`.
- Bibliographies contain 31 printed entries across the five modules. The module-wide scope is explicit. The Module 4 page 3 list belongs to salting; drying/smoking retain their inline citations but have no separate reference list in the supplied pages.
- Original activities were retained only in `source_activities`: Module 1 pages 2 and 19, Module 2 page 7, and Module 3 page 5. These include the existing pre-test and quiz, not newly generated questions. No answer keys, gameplay questions, or rewards were added.

## Missing source material and extraction limitations

1. **Module 5 page 1:** chilling and freezing each say "Please refer to the attached file for the lecture part." Those lecture attachments are absent from the supplied five PDFs. The temperature-control lesson is explicitly partial.
2. **Module 5 page 2:** additives contains only the same attachment instruction. Its lesson is explicitly a source placeholder, not a completed additives lesson.
3. **Module 1 pages 5–16:** statistical table and chart numbers are in raster images. They are visually preserved, but no claim is made that every tiny cell can be read reliably on a mobile screen. The original resolution limits the available detail; enlarging a PNG does not recover missing detail. The map on page 4 and loss diagram on page 17 have the same native-resolution limitation.
4. **Module 2 page 3; Module 3 pages 2–3; Module 4 pages 6 and 9–12:** illustration labels and embedded credits inherit source raster quality. They are supplied as images; tiny labels were not converted into unverified glossary entries.
5. No entire page was blank/unreadable or required invented OCR text. The remaining issues are local raster legibility, original wording/typography, and missing external attachments. Words split by the source typesetting may remain awkward in a few passages; no unverified word repair was applied.
6. Bibliographic text and printed links are retained as supplied, including wrapped URLs, broad website-only image credits, duplicate years, and spelling errors. Link availability, bibliographic accuracy, reuse permissions, and the underlying scientific claims were not independently verified.
7. Module 1 reuses Figure 5 for different graphics. Keep source numbering and use the unique asset IDs to distinguish them. Module 4 pages 11–12 have embedded figure numbers **21, 19 and 20**, not a continuation renumbered by this conversion. Their printed credits are Trinidad (1997), Espejo (1980), and Espejo-Hermes (1996); full matching bibliographic entries are not provided in those pages.

## Instructor review queue

These are source statements or ambiguities identified during inspection. They are not silently corrected and are not independent factual conclusions. Related lesson `review_flags` record the same concerns.

- **module_1, pages 3, 4 — `source_nutrition_claims`:** Nutrition and health claims and taxonomic spellings are retained from the source; instructor review is pending.
- **module_1, pages 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 — `historical_statistics`:** Statistics and program dates are historical source claims, not verified current data. The source mixes years in narrative and table captions; preserve the stated years.
- **module_1, pages 15 — `source_consumption_unit`:** The source says "93.90% grams per day". This unusual unit is retained verbatim; obtain instructor clarification.
- **module_2, pages 2, 3, 4, 5, 6 — `source_nutrition_and_postmortem`:** Health claims, species comparisons, and some incomplete or awkward post-mortem statements are retained from the source; instructor review is pending.
- **module_3, pages 2, 3, 4 — `source_bacterial_claims`:** Review the stated microbial growth/heat claims, spoilage-stage explanations, pH values and water test before assessment use. These are transcribed source statements, not independently verified findings.
- **module_4, pages 2 — `source_salting_ratio`:** Kench salting is printed as 1:7, explicitly 1 part fish to 7 parts salt. Retained as written, pending instructor confirmation.
- **module_4, pages 2, 3, 4, 7, 9, 12, 13 — `source_processing_instructions`:** Food-processing ratios, chemical treatments, temperatures and storage durations are preserved course text, not independently validated operating guidance. Source typos include "brain" and "called" in the smoking procedure.
- **module_4, pages 4 — `source_drying_formula`:** The source labels (Wd/Wf) x 100 as %Moisture, with Wd = weight of dried fish and Wf = weight of fresh fish. Do not substitute a different formula without instructor approval.
- **module_4, pages 4, 7 — `source_moisture_thresholds`:** This source states 20% and 15% moisture conditions; Module 5 page 2 states 10%. These statements need contextual reconciliation by the instructor.
- **module_4, pages 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 — `source_incomplete_citations`:** These topics contain inline citations and image credits but no separate bibliography in their pages. The page 3 bibliography belongs to the salting topic.
- **module_5, pages 1 — `source_missing_chilling_freezing`:** The separate chilling and freezing lecture files referenced here were not supplied.
- **module_5, pages 1, 2 — `source_preservation_claims`:** Heat-treatment, packaging gas ratios, ozone, irradiation and pickling statements are retained source claims pending instructor review; the drying threshold differs from Module 4.
- **module_5, pages 2 — `source_missing_additives`:** The separate additives lecture file referenced here was not supplied.

## Unresolved gameplay configuration

- All 24 quest IDs are empty. Existing project quest IDs were not assumed to unlock specific lessons. Empty IDs must remain unconfigured until an explicit mapping is approved.
- Unlock state, save/load changes, UI scenes, player interactions, DDA, exams, scoring, and gameplay managers were not changed. The JSON database is not yet connected to the running game.
- No export preset exists in the current project. JSON export inclusion and mobile image readability require a later approved export/UI task.

## Validation results

- Strict UTF-8 JSON parsing: all eight JSON files passed; no duplicate keys, comments, trailing commas or non-finite numbers.
- Identity and ownership: five modules, 24 unique lesson IDs, 63 non-empty sections, 41 unique image IDs, and matching index/module entries.
- Page checks: all nested source-page values are within their module's PDF bounds; all 48 pages have exactly one coverage entry.
- References: all 41 image files exist, their PNGs decode, dimensions agree with the manifest, source/asset SHA-256 checksums match, and section references resolve to the appropriate lesson assets. There are zero missing image assets. Missing lecture attachments are a separate source-content issue.
- Godot 4.5.1 stable .NET with GUT 9.5.0: **20 tests passed, 861 assertions, exit code 0**, including three new Codex tests and all 17 existing tests. The save test deliberately produces an expected unavailable-player error; it is caught by the existing regression test. The final run had no GUT warnings.
- GDScript Toolkit: the new test script parsed and linted successfully. No formatter was applied to existing files.
- Visual QA: all 41 crops were inspected in contact sheets; the full fresh/stale table, source formula, and embedded smokehouse captions were additionally checked at readable size and corrected before final validation.
- These are automated data/engine checks and visual source/crop inspection. No manual in-game Codex test, Android build, export-package test, educational fact validation, or instructor sign-off was performed.

## Files added and existing work preserved

- Added eight JSON files, this report and README under `Resources/Codex/`.
- Added 41 PNG images under `Assets/Codex/`.
- Added `test/unit/test_codex_data.gd`; no existing test or runtime script was changed for this conversion.
- Existing modified files, untracked materials, source PDFs, scenes, project settings and Git changes were preserved. No dependencies were installed and no commits or pushes were made.

## Recommended next task

Review and approve the 24-lesson outline and the instructor review queue, and obtain the missing chilling, freezing and additives lectures. Once content and quest mappings are agreed, implement a separately scoped read-only Codex viewer. Keep unlock/save integration as an explicit part of that later task rather than guessing it during extraction.
