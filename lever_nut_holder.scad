// Lever-nut holder: a printable tray for WAGO 221 lever connectors, one slot
// per connector, in one row or two back to back, lying flat or standing up,
// with a screw tab at each end. MIT licence; see LICENSE.

/* [Holder] */

// Conductors per connector, one entry per slot: 2, 3 or 5 for the 221-412, 221-413 and 221-415
blocks_config = [2, 2, 2, 2, 2];

// One row or two back to back, lying flat (wires leave sideways) or standing up (wires leave upward)
style_config = "horizontal_mirrored"; // [horizontal, horizontal_mirrored, vertical, vertical_mirrored]

/* [Screw tabs] */

tabs = true;

// Length and width of each tab, mm
tab_width = 10;

// Radius of the screw hole, mm
tab_radius = 2.6;

// Thickness of each tab, mm
tab_height = 4;

/* [Fit] */

// Clearance added to the connector's width, depth and height, mm
allowance = 0.2;

/* [Hidden] */

// "holder", or for the checks: "fit" (the holder where it meets connectors at
// datasheet size; empty when they fit) and "grip" (where it meets connectors
// 1 mm taller; the lips that hold them down)
part = "holder";

$fn = $preview ? 32 : 64;

// WAGO 221 sizes from its datasheets, mm. The width grows 5.6 mm per
// conductor: 13.1 for the 221-412, 18.7 for the 221-413, 29.9 for the 221-415.
function connector_width(n) = 1.9 + 5.6 * n;
connector_depth = 18.6;
connector_height = 8.3;

wall = 2; // rails and back wall
floor_t = 2; // under the connectors
lip_t = 1.6; // thickness of the lip over the back edge
back_lip = 2; // how far the lip reaches over the connector
front_stop = 0.8; // height of the front stop above the floor
rail = 4; // height of the side rails above the floor

STYLES = ["horizontal", "horizontal_mirrored", "vertical", "vertical_mirrored"];

function slot_width(n, a) = connector_width(n) + a;
// x of slot i's left side, and the row's length with a rail at each end.
function slot_x(blocks, a, i) =
    i == 0 ? wall : slot_x(blocks, a, i - 1) + slot_width(blocks[i - 1], a) + wall;
function row_length(blocks, a) = slot_x(blocks, a, len(blocks));

// One row, front at y = 0, back wall at y = depth, floor at z = 0.
module row(blocks, a) {
    d = connector_depth + a;
    h = connector_height + a;
    length = row_length(blocks, a);
    translate([0, -wall, 0]) cube([length, d + 2 * wall, floor_t]);
    translate([0, d, 0]) cube([length, wall, floor_t + h + lip_t]);
    translate([0, d - back_lip, floor_t + h]) cube([length, back_lip + wall, lip_t]);
    translate([0, -wall, 0]) cube([length, wall, floor_t + front_stop]);
    for (i = [0:len(blocks)])
        translate([slot_x(blocks, a, i) - wall, -wall, 0])
            cube([wall, d + 2 * wall, floor_t + rail]);
}

// Connectors at datasheet size in a row's slots, optionally made taller. They
// are 0.01 mm smaller on every face, so resting on the floor doesn't count as
// meeting the holder.
module connectors(blocks, a, grow = 0) {
    e = 0.01;
    for (i = [0:len(blocks) - 1])
        translate([slot_x(blocks, a, i) + a / 2 + e, a / 2 + e, floor_t + e])
            cube([connector_width(blocks[i]) - 2 * e, connector_depth - 2 * e, connector_height + grow - 2 * e]);
}

// Places its child, a row, in the chosen style, with the part on z = 0 and
// starting at x = 0, y = 0. Adds the screw tabs when asked.
module arrange(blocks, style, a, tabs, tab_width, tab_radius, tab_height, with_tabs) {
    d = connector_depth + a;
    h = floor_t + connector_height + a + lip_t;
    length = row_length(blocks, a);
    shift = tabs ? tab_width : 0;
    upright = style == "vertical" || style == "vertical_mirrored";
    double = style == "horizontal_mirrored" || style == "vertical_mirrored";
    // Where the tabs' centres sit across the part.
    tab_y =
        !upright ? (double ? d + 1.5 * wall : (d + 2 * wall) / 2)
        : (double ? h - floor_t / 2 : h / 2);

    translate([shift, 0, 0]) {
        if (!upright) {
            translate([0, wall, 0]) {
                children();
                // The second row turns about the back wall, so the two share it.
                if (double) translate([0, 2 * d + wall, 0]) mirror([0, 1, 0]) children();
            }
        } else {
            // Standing on the back wall: the floor is upright and wires leave upward.
            lift = double ? h - floor_t : 0;
            translate([0, lift, d + wall]) {
                rotate([-90, 0, 0]) children();
                // The second row turns about the floor, so the two share it.
                if (double) translate([0, floor_t, 0]) mirror([0, 1, 0]) rotate([-90, 0, 0]) children();
            }
        }
        if (tabs && with_tabs) {
            translate([0, tab_y, 0]) tab(tab_width, tab_radius, tab_height);
            translate([length, tab_y, 0]) mirror([1, 0, 0]) tab(tab_width, tab_radius, tab_height);
        }
    }
}

// A screw tab reaching out from x = 0 towards -x, centred on y = 0. It runs
// under the end rail so it joins the row.
module tab(width, radius, thickness) {
    linear_extrude(thickness) difference() {
            hull() {
                translate([-width / 2, 0]) circle(d=width);
                translate([-width / 2, -width / 2]) square([width / 2 + wall, width]);
            }
            translate([-width / 2, 0]) circle(r=radius);
        }
}

module lever_nut_holder(
    blocks = [2, 2, 2, 2, 2],
    style = "horizontal_mirrored",
    tabs = true,
    tab_width = 10,
    tab_radius = 2.6,
    tab_height = 4,
    allowance = 0.2
) {
    assert(len(blocks) > 0, "lever_nut_holder: blocks needs at least one connector");
    assert(
        len([for (n = blocks) if (n != floor(n) || n < 1) n]) == 0,
        str("lever_nut_holder: each entry in blocks is a whole number of conductors, got ", blocks)
    );
    assert(
        len([for (s = STYLES) if (s == style) s]) == 1,
        str("lever_nut_holder: style is one of ", STYLES, ", got ", style)
    );
    assert(
        !tabs || tab_radius < tab_width / 2,
        "lever_nut_holder: tab_radius has to be less than half of tab_width"
    );
    arrange(blocks, style, allowance, tabs, tab_width, tab_radius, tab_height, true)
        row(blocks, allowance);
}

module checked_part(grow) {
    intersection() {
        lever_nut_holder(blocks_config, style_config, tabs, tab_width, tab_radius, tab_height, allowance);
        arrange(blocks_config, style_config, allowance, tabs, tab_width, tab_radius, tab_height, false)
            connectors(blocks_config, allowance, grow);
    }
}

if (part == "fit")
    checked_part(0);
else if (part == "grip")
    checked_part(1);
else
    lever_nut_holder(blocks_config, style_config, tabs, tab_width, tab_radius, tab_height, allowance);
