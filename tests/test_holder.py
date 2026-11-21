"""Render the holder in a set of cases and check its solids, size and fit.

usage: python3 tests/test_holder.py [OPENSCAD]

Each case renders lever_nut_holder.scad to a binary STL with --hardwarnings,
then counts its separate solids (triangles sharing a vertex belong to the same
solid) and measures its bounding box, to within 0.01 mm.

The fit cases render the holder's "fit" part, where it meets connectors at
their datasheet size, and expect it to be empty. The grip cases render the
"grip" part, where it meets connectors 1 mm taller, and expect one piece of
lip over each connector. The example case renders examples/from_another_file.scad
and checks it as a shape case. Any ERROR or WARNING fails a case that should build.
"""

import json
import os
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAD = os.path.join(ROOT, "lever_nut_holder.scad")

# The sizes the holder is built from (see lever_nut_holder.scad).
WALL, FLOOR, LIP, ALLOWANCE = 2, 2, 1.6, 0.2
DEPTH, HEIGHT = 18.6 + ALLOWANCE, 8.3 + ALLOWANCE
TAB = 10


def width(n):
    return 1.9 + 5.6 * n


def expected_size(blocks, style, tabs=True, tab=TAB):
    """The bounding box the holder should have, worked out by hand."""
    length = WALL + sum(width(n) + ALLOWANCE + WALL for n in blocks)
    x = length + (2 * tab if tabs else 0)
    tall = FLOOR + HEIGHT + LIP  # floor to the top of the lip
    deep = DEPTH + 2 * WALL  # front stop to the back wall
    return {
        "horizontal": (x, deep, tall),
        "horizontal_mirrored": (x, 2 * DEPTH + 3 * WALL, tall),
        "vertical": (x, tall, deep),
        "vertical_mirrored": (x, 2 * tall - FLOOR, deep),
    }[style]


def measure(path):
    data = open(path, "rb").read()
    (n,) = struct.unpack_from("<I", data, 80)
    parent = {}

    def find(v):
        while parent[v] != v:
            parent[v] = parent[parent[v]]
            v = parent[v]
        return v

    for i in range(n):
        v = struct.unpack_from("<9f", data, 84 + i * 50 + 12)
        corners = [v[0:3], v[3:6], v[6:9]]
        for c in corners:
            parent.setdefault(c, c)
        root = find(corners[0])
        for c in corners[1:]:
            parent[find(c)] = root
    solids = len({find(v) for v in parent})
    lo = [min(p[i] for p in parent) for i in range(3)]
    size = [max(p[i] for p in parent) - lo[i] for i in range(3)]
    return solids, size, lo


def render(openscad, out, params, scad=SCAD):
    cmd = [openscad, "--hardwarnings", "--export-format", "binstl", "-o", out]
    for name, value in params.items():
        cmd += ["-D", f"{name}={json.dumps(value)}"]
    return subprocess.run(cmd + [scad], capture_output=True, text=True)


STYLES = ["horizontal", "horizontal_mirrored", "vertical", "vertical_mirrored"]
LAYOUTS = [[2, 2, 2, 2, 2], [2], [3], [5], [5, 3, 2]]


def cases():
    for style in STYLES:
        for tabs in (True, False):
            blocks = LAYOUTS[0]
            yield ("shape", f"{style}, tabs {'on' if tabs else 'off'}",
                   {"style_config": style, "tabs": tabs},
                   expected_size(blocks, style, tabs))
        for blocks in LAYOUTS:
            yield ("fit", f"{style}, {blocks} fit at datasheet size",
                   {"style_config": style, "blocks_config": blocks, "part": "fit"}, None)
            rows = 2 if style.endswith("mirrored") else 1
            yield ("grip", f"{style}, {blocks} held by a lip each",
                   {"style_config": style, "blocks_config": blocks, "part": "grip"},
                   rows * len(blocks))
    for blocks in LAYOUTS[1:]:
        yield ("shape", f"horizontal, {blocks}",
               {"style_config": "horizontal", "blocks_config": blocks},
               expected_size(blocks, "horizontal"))
    for label, params, message in [
        ("refuses an unknown style", {"style_config": "diagonal"}, "style is one of"),
        ("refuses no connectors", {"blocks_config": []}, "needs at least one connector"),
        ("refuses a fractional connector", {"blocks_config": [2.5]}, "whole number of conductors"),
        ("refuses a hole wider than the tab", {"tab_radius": 6}, "tab_radius has to be less"),
    ]:
        yield ("refuse", label, params, message)
    # examples/from_another_file.scad: [5, 3, 3], standing up, 12 mm tabs.
    yield ("example", "examples/from_another_file.scad", {}, expected_size([5, 3, 3], "vertical", tab=12))


def main():
    openscad = sys.argv[1] if len(sys.argv) > 1 else "openscad"
    failed = total = 0
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "case.stl")
        for kind, label, params, want in cases():
            total += 1
            if os.path.exists(out):
                os.remove(out)
            scad = os.path.join(ROOT, label) if kind == "example" else SCAD
            result = render(openscad, out, params, scad)
            errors = [l for l in result.stderr.splitlines() if "WARNING" in l or "ERROR" in l]
            if kind == "refuse":
                ok = result.returncode != 0 and errors and want in errors[0]
                got = errors[0] if errors else f"exit {result.returncode}, no error"
            elif kind == "fit":
                ok = result.returncode != 0 and "top level object is empty" in result.stderr \
                    and not errors
                got = "empty" if ok else "the holder meets a connector"
            elif result.returncode != 0 or errors:
                # A failed assert can leave the exit status at 0, so the messages count too.
                ok, got = False, f"openscad exited {result.returncode}: {errors[:1]}"
            elif kind == "grip":
                solids, size, lo = measure(out)
                ok = solids == want
                got = f"{solids} pieces of lip"
            else:
                solids, size, lo = measure(out)
                ok = solids == 1 and all(abs(a - b) <= 0.01 for a, b in zip(size, want)) \
                    and all(abs(v) <= 0.01 for v in lo)
                got = (f"{solids} solids, {' x '.join(f'{s:.2f}' for s in size)} mm, "
                       f"from {', '.join(f'{v:.2f}' for v in lo)}")
                if not ok:
                    got += f"; expected 1 solid, {' x '.join(f'{s:.2f}' for s in want)} mm from 0, 0, 0"
            print(f"{'ok  ' if ok else 'FAIL'} {label}: {got}")
            failed += not ok
    print(f"{total - failed} of {total} cases passed")
    sys.exit(1 if failed else 0)


main()
