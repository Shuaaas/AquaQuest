# Codex reading-first design

The approved visual concept is implemented with native Godot controls in
Scene/UI/CodexUI.tscn. Wood navigation and a parchment page reuse existing HUDReference
textures and the existing book icon. Lesson text uses dark brown on parchment, smooth
font rendering, a bounded reading column and additional line spacing. No raster mockup
is pasted over the interface. Its ornamental illustration is a visual reference;
the implementation uses the project's current editable frames and graphics.

## Reading controls

- A− / A+ adjust base body text from 16 to 28 pixels in steps of two. The default is
  20 pixels; headings scale relative to it, while metadata stays at least 16 pixels.
  The setting remains in this persistent scene while playing; no new save setting
  or project configuration was added.
- Lessons hides/shows the sidebar. It remains visible when navigation is hidden.
- Previous lesson / Next lesson navigate within the selected module, including honest
  locked-lesson screens. Buttons disable at module boundaries. No controls unlock
  lessons or award progress.
- Module names and full wrapped lesson titles replace truncated one-line navigation.
  Existing review/locked status remains visible. On portrait layouts, navigation
  stacks above the reading page; hiding it gives the lesson more reading space.
- Close and Escape retain the existing pause ownership and focus restoration.

Overview and key concepts come first, followed by the full original lesson sections,
illustrations, examples, table rows and references. Definitions, examples and table
rows have distinct study cards. Tables retain the existing vertical field/value
representation so narrow devices do not need sideways scrolling.

All educational wording and source references remain in their existing data files.
No lesson JSON, PDFs, source images, CodexManager rules, region mappings, quest
requirements, gameplay, scoring, DDA or save schema changed. Missing-material notices,
missing-image fallbacks and locked-content protection remain. The concept's proposed
Study focus panel was not populated with invented lesson-specific objectives.

## Editing in Godot

Open CodexUI.tscn in the 2D workspace. The static hierarchy is:
- Margin > Panel > Book > Header: title, book icon and Close.
- Book > Columns > NavigationPanel > Navigation: module selector/title and lesson list.
- Columns > ReadingPanel > Reader: reading tools, content scroll and lesson navigation.
- Reader > ContentScroll > ReadingWidth > Content: data-generated reading blocks.

The root's local Theme contains wood/paper/button textures, selected/focus styles and
StudyCard panel styling. Edit those resources in the Inspector to adjust colors,
frames and padding. Preserve nine-slice texture margins. PixelUIStyle is no longer
attached to this scene because it would overwrite its reader-specific theme and font
smoothing. The existing font family is reused with grayscale antialiasing locally;
no new font dependency was installed and no shared UI theme was changed.

The script creates lesson buttons and source-driven RichTextLabels/cards, retaining
BBCode-disabled plain text. Full course content is not baked into the scene. Keep
unique names used by the script. Responsive code controls sidebar width/visibility,
reading width and image heights. The lesson column caps at 800 pixels and recenters
when the sidebar is hidden. The scroll container suppresses its horizontal bar;
reading width is recalculated to fit instead of retaining a desktop minimum width.

## Files changed

- Scene/UI/CodexUI.tscn: editable wooden/parchment scene, local Theme, reading controls.
- Scripts/UI/CodexUI.gd: display cards, font resizing, sidebar and lesson navigation.
- test/unit/test_codex_ui.gd: recursive text checks and five additional tests.
- docs/CODEX_READER_DESIGN.md: this guide.

## Verification

Godot 4.5.1: all 15 Codex UI tests pass. Existing tests cover inventory handoff,
module selection, locked content, source text/images/references/tables, region unlock
refresh, image fallbacks, pause safety, Escape, fishing/loading guards and layout.
New checks cover font-size limits and nested cards, sidebar reopening, next/previous
bounds and locks, desktop-to-phone resizing, and preservation of every lesson's
sections, definitions and references. BBCode remains disabled for all rendered text.

Full GUT suite: 132/135 pass. The same three unrelated Region 1 layout failures remain
at test/unit/test_region1_layout.gd lines 106, 170 and 189–190. No new UI test failures.
Game renders inspected at 1280x800, 856x428, 720x360 and 390x844, including reading mode
with the sidebar hidden. The live main game opened the new Codex; A+, sidebar collapse,
next-lesson navigation and close/unpause worked while Codex progress stayed unchanged.

Actual Android device testing, physical reading comfort, display cutouts and touch
scroll behavior remain manual validation. The original course wording is preserved,
so correcting grammar or reviewing educational claims is a separate content task.
