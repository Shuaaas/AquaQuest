# AquaQuest Codex content

This folder contains a lesson database converted from the five existing course PDFs in `res://docs/modules/`. It contains 24 lessons in 63 sections, with 41 PNG assets. Phase 2 now provides a runtime reader and quest-based unlock persistence; see `res://docs/CODEX_SYSTEM.md` for setup, changed files, tests and limitations. The original extraction report describes the content-conversion phase.

## Files and placement

These files are already in their intended project locations:

- `res://Resources/Codex/module_1.json` through `module_5.json`: full lesson text, summaries, concepts, source examples, references, and provenance.
- `res://Resources/Codex/index.json`: module order, lesson order, titles, content status, and module resource paths.
- `res://Resources/Codex/asset_manifest.json`: every supplied image, owner lesson, caption, source page, crop coordinates, dimensions, and SHA-256 checksum.
- `res://Resources/Codex/page_coverage.json`: the disposition of all 48 PDF pages.
- `res://Resources/Codex/extraction_report.md`: extraction decisions, limitations, missing source lectures, and instructor review items.
- `res://Assets/Codex/module_1/` through `module_4/`: actual supplied PNG images. Module 5 has no instructional images in the supplied PDF, so no module 5 image folder is needed.
- `res://test/unit/test_codex_data.gd`: automated GUT checks of the content files. This does not change game behavior.

The downloadable archive preserves these same paths. The PDFs and existing project files are not bundled. Do not replace any existing files when transferring the archive into another checkout without reviewing that checkout first.

## Data contract (schema version 1)

The requested starting schema is preserved and extended with content/provenance fields. All files use UTF-8 strict JSON, without comments, executable code, scene nodes, or UI layout instructions.

- A module has `module_id`, `module_number`, `module_title`, `source`, `objectives`, `references`, `source_activities`, and `lessons`.
- `source` records the original resource path, one-based PDF page count, checksum, author, institution, and printed credits. Source PDF paths are citations; the future runtime need not open the PDFs.
- A lesson has `id`, module identifiers, `title`, `summary`, `sections`, `key_concepts`, `examples`, `tables`, `images`, `source_pages`, `references`, `content_status`, `review_flags`, and `unlock_requirement`.
- Each section has `heading`, plain-text `content`, `source_pages`, and `image_ids`. The IDs identify relevant visuals in the lesson's `images` array and asset manifest. Their sequence is content order, not a prescribed UI layout. An image on the following source page can belong to a section whose prose starts on the preceding page.
- Each concept has `term`, `definition`, and `source_pages`; each example has `title`, `content`, and `source_pages`. These short study entries are based on the source, while the full source explanations remain in sections. Empty arrays mean no separate entry was curated; the lesson prose can still contain examples and terminology.
- Each image has `id`, `path`, `caption`, `source_pages`, and `status`. All 41 referenced images are supplied. Captions and printed credits remain source claims.
- Each bibliography entry has `text`, `source_pages`, and `scope`. `module_bibliography` means the reference list belongs to the whole module; it does not establish that every citation supports every lesson sentence. Module 4's page 3 list is scoped to salting. Other citations remain inline in the lesson text.
- `tables` contains a structured ten-row comparison of fresh/stale fish from Module 3 page 4, plus its faithful image reference. The other source tables are raster images and remain images rather than unreliable numeric transcriptions. A future viewer must render `tables` or the associated image, rather than relying solely on `sections[].content`.
- Module objectives and original assignments/pre-test/quiz are retained separately. `source_activities` is archival course material, not a game question bank. No new questions, answers, or grading rules were generated.

All `source_pages` numbers are one-based PDF pages within that lesson's module, not a combined 48-page document. Summaries and short study entries are source-based paraphrases; the main section content retains source wording with line-wrap and presentation-glyph normalization. The source's fraction is represented in plain text and preserved as an image.

## Unlock configuration and review status

Every lesson now has a region requirement, for example Module 2 uses `unlock_requirement: {"type": "region", "id": "region_1"}`. The approved mapping is **Region 1 → Module 2; Region 2 → Module 3; Region 3 → Module 4; Region 4 → Module 5; Region 5 → Module 1**. All lessons in the assigned module become reviewable when that defined region unlocks. Main unlocks Region 1 on startup. Regions 3–5 are mapped but their definitions are not yet present, so those modules remain locked. `CodexManager` saves unlocked lesson IDs in the existing `codex` save section and reconciles them with region progress after loading. No unlocked booleans are stored in the content JSON.

Most lessons have `content_status: "extracted_requires_instructor_review"`. This records completed extraction without claiming educational fact checking or instructor approval. Module 5's temperature-control lesson is `partial_source_missing_supplement`; its additives lesson is `source_placeholder_only`. See the report before using this material for assessment.

## Godot use and validation

Godot 4.5.1 can read these files through `FileAccess` and `JSON`. Numeric JSON values are parsed as floats by Godot, so cast page numbers to integers when using them as array indexes. Convert a one-based source page to a zero-based index only when needed by a future viewer.

Use section content as plain text. If a future `RichTextLabel` enables BBCode, escape source text appropriately rather than treating it as markup. Load the `res://Assets/Codex/...png` resource paths for visuals. The editor will generate its own image import metadata; no imports or project settings were manually edited for this task.

Run the installed GUT suite using the GUT editor panel, or run the existing Godot executable with these arguments from the project folder:

```text
--headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

The Codex tests check index/module agreement, unique lesson IDs, page bounds, approved region requirements, image presence and decoding, section image references, and complete page accounting. Additional Python checks verified strict JSON, source/asset checksums, nested page ranges, and image ownership. These checks verify structure and extraction traceability, not scientific accuracy.

No export preset currently exists. When an Android/export workflow is approved later, ensure non-resource JSON files in `Resources/Codex/` are included in the export, and test image readability on a physical device. No export settings were changed here. Phase 2 tests cover runtime rendering, unlock persistence and phone-sized layouts; Android packaging and a physical-device playthrough remain untested. See `docs/CODEX_SYSTEM.md` for the corrected startup verification and remaining default-spawn warning.
