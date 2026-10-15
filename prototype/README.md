# Grid maze prototype

This is the project's only gameplay scene and launches when the project runs.

Run the project or `res://prototype/prototype_main.tscn` in Godot. Tap **Tower**
or **Wall**, tap a grid cell to position the live route preview, then tap that
cell again to build. You can also drag directly from either build button and
release to build immediately. Invalid drops cancel without spending anything.
Tap an existing tower or wall to select it. Towers can be upgraded or sold;
walls can be removed to recover their Wall allowance. Placement is rejected
when it would block a required waypoint route or trap an active enemy.
Later waypoint segments cannot reuse an earlier tile-to-tile connection, so
enemies cannot retrace long sections of the route. A route may revisit a tile
through unused sides, allowing proper crossroads and perpendicular crossings.

Use **Start Wave** to play the ten-wave combat slice. Enemies arrive in planned
groups, rounds finish as soon as all planned enemies are defeated or leak, and
moving enemies adopt recalculated four-direction routes without teleporting.
The economy starts with $500 and five Power. Towers cost $100; upgrades
cost $100, $300, and $800. There is no income per kill. Clearing a wave pays a
base reward that starts at $120 and rises by $20 per wave, plus 5% interest on
the credits held when the wave began. Interest is capped at half the wave's base
reward. The run begins with five Power for towers and four single-tile Walls.
Each tower consumes one Power and each wall consumes one Wall. Clearing every
wave increases both limits by one. A tower sells for its full investment before
participating in combat and 70% afterward.

The prototype is landscape-only and uses a fixed 18 by 9 gameplay grid. Cell
size is calculated uniformly from the device's safe viewport, so every device
receives the same number of gameplay tiles and every tile remains square. The
layout accounts for notches and rounded screen corners, uses a compact HUD on
short displays, and shows a rotate prompt instead of changing the gameplay area
if a portrait viewport is forced.

## Verification

The prototype has focused headless checks for routing and live rerouting,
responsive layout, round lifecycle, economy rules, and end-to-end combat. Run
these scripts through Godot after changing the prototype:

- `res://tools/prototype_grid_routing_smoke.gd`
- `res://tools/prototype_layout_smoke.gd`
- `res://tools/prototype_combat_loop_smoke.gd`
- `res://tools/prototype_economy_smoke.gd`
- `res://tools/prototype_combat_integration_smoke.gd`
