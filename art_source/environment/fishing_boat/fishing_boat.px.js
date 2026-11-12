include("../../palettes/aquaquest.px.js");
// Existing environment wood highlights; exact sampled sources are recorded in palette_reference.json.
pal({ O: "#a96c3f", A: "#a06131" });

const CELL = 128;
const VIEWS = ["top", "three_quarter", "side", "front"];
const LEVELS = ["basic", "equipped", "upgraded"];

// Bamboo outriggers: tapered poles, lit upper edges, and two simple lashing bands.
function pole(c, x0, y0, x1, y1) {
  c.line(x0, y0, x1, y1, "k", 5);
  c.line(x0, y0, x1, y1, "w", 3);
  c.line(x0, y0 - 1, x1, y1 - 1, "h");
  for (const t of [0.23, 0.76]) {
    const x = Math.round(x0 + (x1 - x0) * t);
    const y = Math.round(y0 + (y1 - y0) * t);
    if (Math.abs(y1 - y0) > Math.abs(x1 - x0)) c.hline(x - 2, y, 5, "e");
    else c.vline(x, y - 2, 5, "e");
  }
}

function boom(c, points) {
  for (let i = 0; i < points.length - 2; i += 2) {
    c.line(points[i], points[i + 1], points[i + 2], points[i + 3], "k", 3);
    c.line(points[i], points[i + 1], points[i + 2], points[i + 3], "O");
  }
}

function topHull(c) {
  pole(c, 22, 35, 22, 99); pole(c, 106, 35, 106, 99);
  boom(c, [23, 47, 38, 40, 90, 40, 105, 47]);
  boom(c, [23, 83, 38, 77, 90, 77, 105, 83]);
  c.poly([64,10, 70,18, 76,34, 79,59, 77,86, 71,102, 64,109, 57,102, 51,86, 49,59, 52,34, 58,18], "k");
  c.poly([64,13, 68,20, 74,35, 77,59, 75,85, 69,100, 64,106, 59,100, 53,85, 51,59, 54,35, 60,20], "O");
  const well = [64,24, 70,37, 73,59, 71,83, 66,97, 62,97, 57,83, 55,59, 58,37];
  c.poly(well, "p");
  c.clip(well, () => c.rect(57, 30, 14, 68, "w"));
  for (let y = 35; y < 98; y += 7) c.clip(well, () => {
    c.hline(54, y, 20, "e"); c.hline(57, y + 1, 13, "A");
  });
  c.line(63, 26, 59, 38, "s"); c.line(59, 39, 56, 59, "s");
  c.line(56, 60, 58, 82, "s"); c.line(58, 83, 63, 96, "s");
  c.line(63, 15, 55, 35, "h"); c.line(54, 36, 51, 59, "O");
  c.line(52, 61, 54, 84, "h"); c.line(55, 86, 61, 100, "O");
  c.line(74, 37, 76, 59, "e"); c.line(76, 61, 74, 85, "e");
  for (const y of [43, 75]) {
    c.rect(53, y, 22, 6, "k"); c.rect(54, y, 20, 4, "O");
    c.hline(54, y, 20, "h"); c.hline(55, y + 3, 18, "w");
    c.px(55, y + 1, "p"); c.px(72, y + 1, "p");
  }
  c.poly([61,20, 64,14, 67,20, 66,28, 62,28], "A");
  c.hline(61, 23, 6, "e"); c.hline(60, 99, 8, "e");
  c.line(69, 51, 69, 71, "k", 2); c.vline(69, 51, 19, "h");
  c.poly([67,65, 71,65, 72,71, 70,74, 67,71], "O");
}

function threeQuarterHull(c) {
  pole(c, 41, 39, 116, 16); pole(c, 14, 98, 95, 73);
  boom(c, [49, 38, 45, 49, 32, 74, 25, 93]);
  boom(c, [103, 22, 98, 34, 83, 61, 78, 77]);
  c.poly([19,62, 30,53, 83,34, 104,32, 118,38, 113,52, 98,63, 47,85, 28,87, 20,78], "k");
  c.poly([21,63, 31,55, 84,36, 104,34, 115,39, 110,51, 96,61, 46,83, 29,84, 22,77], "e");
  c.poly([22,63, 32,56, 84,37, 104,35, 115,39, 109,47, 96,56, 44,78, 28,79, 22,73], "O");
  c.poly([26,64, 34,59, 85,41, 101,39, 108,41, 102,47, 92,53, 44,72, 30,74], "p");
  const floor = [29,64, 36,61, 85,43, 99,42, 101,45, 90,51, 44,69, 32,71];
  c.poly(floor, "w");
  for (let x = 35; x < 101; x += 9) {
    c.clip(floor, () => {
      c.line(x, 42, x + 8, 76, "e"); c.line(x + 1, 42, x + 9, 76, "A");
    });
  }
  c.line(28, 60, 84, 39, "h"); c.line(85, 38, 104, 36, "h");
  c.line(24, 66, 25, 73, "h"); c.line(29, 77, 43, 76, "A");
  c.line(47, 77, 96, 56, "p"); c.line(43, 82, 97, 59, "w");
  c.line(51, 79, 98, 59, "A"); c.line(31, 82, 40, 82, "p");
  c.line(111, 43, 106, 50, "w");
  for (const [x, y] of [[38,61], [72,48]]) {
    c.poly([x-1,y, x+5,y-2, x+17,y+7, x+10,y+11, x,y+4], "k");
    c.poly([x,y, x+5,y-1, x+15,y+7, x+10,y+9, x+1,y+3], "O");
    c.line(x, y, x+5, y-1, "h"); c.line(x+5, y-1, x+15, y+7, "h");
    c.px(x+2, y+2, "p"); c.px(x+12, y+7, "p");
  }
  c.poly([90,40, 104,36, 113,39, 104,46, 99,48], "A");
  c.line(97, 40, 106, 38, "O"); c.line(104, 39, 107, 42, "w");
  c.line(40, 67, 68, 57, "k", 2); c.line(40, 66, 67, 56, "h");
  c.poly([38,66, 45,63, 51,64, 44,69, 40,70], "O");
}

function sideHull(c) {
  // The opposite outrigger is occluded in this orthographic view.
  boom(c, [34, 71, 37, 92]); boom(c, [92, 65, 89, 92]);
  pole(c, 20, 96, 108, 96);
  c.poly([13,54, 18,55, 29,65, 80,62, 104,51, 116,46, 114,59, 107,76, 94,88, 73,94, 39,92, 23,83, 16,69], "k");
  c.poly([16,58, 29,68, 81,65, 105,54, 113,50, 110,64, 102,77, 92,86, 72,91, 40,89, 25,81, 19,68], "w");
  c.poly([24,69, 42,76, 76,77, 102,64, 109,57, 104,73, 92,84, 72,89, 40,87, 27,79], "e");
  c.poly([30,67, 45,65, 80,64, 99,57, 101,62, 79,71, 44,73], "p");
  c.poly([32,67, 46,66, 79,66, 95,60, 95,64, 78,70, 44,71], "A");
  c.line(17, 57, 29, 66, "h"); c.line(30, 66, 79, 63, "O");
  c.line(81, 63, 106, 52, "O"); c.line(106, 52, 114, 49, "h");
  c.line(25, 72, 41, 79, "A"); c.line(41, 79, 75, 81, "A");
  c.line(76, 81, 99, 70, "w"); c.line(25, 78, 41, 85, "p");
  c.line(42, 85, 73, 87, "p"); c.line(74, 87, 96, 77, "p");
  c.hline(44, 80, 17, "O"); c.hline(63, 87, 8, "w");
  c.line(32, 72, 36, 76, "p"); c.line(87, 72, 90, 69, "p");
  for (const x of [43, 74]) {
    c.rect(x, 64, 4, 8, "k"); c.rect(x, 64, 3, 6, "O"); c.hline(x, 64, 3, "h");
  }
  c.line(50, 67, 67, 66, "h");
}

function frontHull(c) {
  // Curved crossbeams and end-on bamboo floats retain the bangka silhouette.
  boom(c, [22, 81, 36, 64, 48, 61, 80, 61, 92, 64, 106, 81]);
  for (const x of [22, 106]) {
    c.ellipse(x, 85, 5, 9, "k"); c.ellipse(x, 84, 3, 8, "w");
    c.ellipse(x-1, 79, 2, 3, "h"); c.hline(x-3, 86, 6, "e");
  }
  c.poly([47,57, 52,51, 76,51, 82,57, 81,76, 75,88, 65,97, 54,89, 48,76], "k");
  c.poly([49,58, 53,53, 75,53, 80,58, 79,75, 73,86, 65,94, 56,87, 50,75], "w");
  c.poly([51,57, 55,54, 74,54, 78,58, 75,64, 55,64], "p");
  c.poly([54,57, 57,56, 72,56, 75,58, 73,61, 56,61], "A");
  c.poly([65,65, 78,63, 77,76, 71,86, 65,93], "e");
  c.line(50, 57, 54, 53, "h"); c.hline(54, 53, 21, "O");
  c.line(50, 62, 64, 67, "O"); c.line(65, 67, 79, 62, "w");
  c.line(51, 71, 64, 76, "A"); c.line(65, 76, 78, 71, "p");
  c.line(54, 81, 64, 85, "e"); c.line(65, 85, 74, 81, "p");
  c.line(64, 66, 64, 92, "O"); c.px(53, 64, "p"); c.px(75, 64, "p");
  c.hline(55, 59, 17, "h");
}

sprite("_rope", { w: 11, h: 9 },
  ellipse(5,4,5,4,"k"), ellipse(5,3,4,3,"h"), ellipse(5,3,2,1,"p"),
  line(3,6,8,6,"w"), line(8,4,9,7,"t"));
sprite("_net", { w: 16, h: 13 },
  poly([1,2, 12,0, 15,9, 5,12, 0,8],"k"),
  poly([2,3, 11,1, 13,8, 5,10, 2,8],"d"),
  line(3,3,6,10,"m"), line(6,2,9,9,"m"), line(9,2,12,8,"m"),
  line(2,5,12,3,"h"), line(3,8,13,6,"w"), line(6,10,13,8,"h"),
  px(2,2,"t"), px(12,1,"h"));
sprite("_fish_box", { w: 13, h: 11 },
  rect(0,0,13,11,"k"), rect(1,1,11,9,"A"), rect(2,2,9,5,"p"),
  hline(1,1,11,"O"), hline(1,8,11,"e"), vline(4,8,2,"w"), vline(8,8,2,"w"),
  line(4,4,8,4,"t"), px(9,3,"c"), px(9,5,"c"), px(3,4,"d"));
sprite("_basket", { w: 10, h: 9 },
  poly([0,1, 9,1, 8,8, 2,8],"k"), rect(1,2,8,3,"O"), rect(2,5,6,2,"w"),
  hline(2,2,6,"p"), hline(2,6,6,"e"), vline(3,3,4,"h"), vline(6,3,4,"e"));

const hulls = { top: topHull, three_quarter: threeQuarterHull, side: sideHull, front: frontHull };
const gear = {
  top: { rope:[58,86], net:[57,53], box:[58,61], extra:[58,31] },
  three_quarter: { rope:[32,63], net:[55,53], box:[78,45], extra:[49,58] },
  side: { rope:[30,69], net:[52,70], box:[78,66], extra:[66,70] },
  front: { rope:[54,63], net:[61,71], box:[59,57], extra:[61,81] },
};

function equipment(c, view, level) {
  const g = gear[view];
  // Gear is stowed inside the boat: all three levels keep precisely the same alpha silhouette.
  c.clip((x,y) => c.is(x,y,"*"), () => {
    c.stamp("_rope", ...g.rope);
    if (level !== "basic") c.stamp("_net", ...g.net);
    if (level === "upgraded") {
      c.stamp("_fish_box", ...g.box); c.stamp("_basket", ...g.extra);
      const braces = {
        top: [[52,55,54,61], [75,86,72,92]],
        three_quarter: [[50,53,54,57], [93,57,97,60]],
        side: [[36,77,38,85], [91,70,88,78]],
        front: [[52,69,56,72], [73,72,77,69]],
      };
      for (const [x0,y0,x1,y1] of braces[view]) {
        c.line(x0,y0,x1,y1,"p",3); c.line(x0,y0,x1,y1,"O");
        c.px(x0,y0,"h"); c.px(x1,y1,"s");
      }
    }
  });
}

for (const view of VIEWS) {
  sprite("_hull_" + view, { w:CELL, h:CELL }, hulls[view]);
  for (const level of LEVELS) {
    sprite("boat_" + level + "_" + view, { base:"_hull_" + view },
      (c) => equipment(c, view, level));
  }
}

sheet("fishing_boat_views", VIEWS.map(view => "boat_basic_" + view), { cols:4, pad:0 });
sheet("fishing_boat_variations", LEVELS.flatMap(level => VIEWS.map(view => "boat_" + level + "_" + view)), { cols:4, pad:0 });

// Whole-pixel floating: the shared boat image is translated, never scaled or deformed.
for (const level of LEVELS) {
  anim("boat_idle_" + level, { w:CELL, h:CELL, frames:4, fps:4 }, (c) => {
    const bob = [0,1,2,1][c.frame];
    c.stamp("boat_" + level + "_three_quarter", 0, bob);
    if (level !== "basic") {
      // One loose net tie sways within the existing net, not outside the hull.
      c.px(62 + (c.frame === 2 ? 1 : 0), 60 + bob, "h");
    }
  });
}
sheet("fishing_boat_animation", LEVELS.map(level => "boat_idle_" + level), { cols:4, pad:0 });

// A labeled review image; only this presentation scene has a background.
scene("preview", { w:512, h:472, bg:"d" },
  text(14,12,"AQUAQUEST / FISHING BANGKA","b",{scale:2}),
  text(14,32,"ONE HULL / THREE LOADOUTS / FOUR VIEWS","t"),
  text(64,51,"TOP","h",{align:"c"}),
  text(192,51,"THREE-QUARTER","h",{align:"c"}),
  text(320,51,"SIDE","h",{align:"c"}),
  text(448,51,"FRONT","h",{align:"c"}),
  ...LEVELS.flatMap((level,row) => [
    text(10,64+row*128,level.toUpperCase(),"t"),
    ...VIEWS.map((view,col) => stamp("boat_"+level+"_"+view,col*128,64+row*128)),
  ]),
  text(14,456,"128X128 CELLS / 1PX DETAIL / EXISTING AQUAQUEST COLORS","t")
);
