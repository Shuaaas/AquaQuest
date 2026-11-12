include("../palettes/aquaquest.px.js");

// A 30px working canvas plus the outline gives a transparent 32px inventory icon.
sprite("test_fishing_rod", { w: 30, h: 30, outline: "k" },
  line(25, 5, 27, 10, "t"),
  line(27, 10, 27, 22, "t"),
  vline(27, 22, 3, "c"),
  hline(25, 25, 3, "c"),
  vline(24, 23, 2, "c"),
  line(5, 25, 25, 3, "w", 2),
  line(5, 24, 24, 3, "h"),
  line(13, 15, 15, 17, "d"),
  line(19, 8, 21, 10, "d"),
  line(23, 4, 25, 6, "c"),
  line(4, 26, 9, 21, "s", 3),
  line(4, 25, 8, 21, "w"),
  line(5, 26, 6, 27, "h"),
  circ(12, 22, 3, "k"),
  circ(12, 22, 2, "d"),
  px(11, 21, "c"),
  px(12, 22, "h"),
  hline(14, 23, 2, "h"),
  px(16, 22, "w")
);

// Same item in a mirrored pose: verifies two-cell packing without changing frame size.
sprite("test_fishing_rod_mirrored", { base: "test_fishing_rod", flip: "x" });
sheet("fishing_rods_test", ["test_fishing_rod", "test_fishing_rod_mirrored"], { cols: 2, pad: 0 });
