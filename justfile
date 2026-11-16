default:
    @just --list

# Render the holder in each style and layout, and check its solids, size and fit
test:
    python3 tests/test_holder.py

# Render the README pictures into assets/
images:
    @mkdir -p assets
    openscad --render --camera=49,22,6,50,0,20,190 --imgsize=800,480 --colorscheme=Tomorrow -o assets/horizontal-mirrored.png lever_nut_holder.scad
    openscad --render --camera=45,6,11,60,0,200,160 --imgsize=800,480 --colorscheme=Tomorrow -D 'style_config="vertical"' -D 'blocks_config=[5,3,2]' -o assets/vertical.png lever_nut_holder.scad
