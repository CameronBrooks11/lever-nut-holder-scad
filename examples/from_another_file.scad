// A standing holder for one 221-415 and two 221-413s, built from another file
use <../lever_nut_holder.scad>

// A used file's $fn doesn't reach its modules, so set it here.
$fn = 64;

lever_nut_holder(blocks=[5, 3, 3], style="vertical", tab_width=12);
