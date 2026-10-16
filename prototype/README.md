# Grid maze prototype

This is the project's only gameplay scene and launches when the project runs.

Each run generates a seeded entrance, exit, and three interior waypoints. Their
order may turn away from the exit, creating deliberate backward and sideways
route sections, but a route can never reuse the same tile-to-tile edge. The seed
is shown in the header and included in exported telemetry.
Use **New Map** to reset the run and immediately generate another layout.

Run the project or `res://prototype/prototype_main.tscn` in Godot. Tap **Gun**,
**Mortar**, **Beam**, or **Wall**, tap a grid cell to position the live route preview, then tap that
cell again to build. You can also drag directly from either build button and
release to build immediately. Invalid drops cancel without spending anything.
Tap an existing tower or wall to select it. Towers can be upgraded or sold;
walls can be removed to recover their Wall allowance. Placement is rejected
when it would block a required waypoint route or trap an active enemy.
Later waypoint segments cannot reuse an earlier tile-to-tile connection, so
enemies cannot retrace long sections of the route. A route may revisit a tile
through unused sides, allowing proper crossroads and perpendicular crossings.
If a square would force an active enemy to backtrack, it remains rejected for
the rest of that placement gesture instead of changing while enemies move.

Use **Start Wave** to play the twenty-wave combat run. Enemies arrive in planned
formations, rounds finish as soon as all planned enemies are defeated or leak,
and moving enemies adopt recalculated four-direction routes without teleporting.
Direct-fire towers acquire the closest enemy and retain that target while it
remains valid. The Gun supplies reliable direct damage, the Mortar selects and
damages clusters, and the Beam ramps while it stays locked onto one target.
Soldiers remain behind slower formation leaders, Runners break formation,
Giants lead and absorb direct fire, and defeated Carriers release four Soldiers.
Enemy pacing favors smaller, durable formations: Soldiers move at 0.9 tiles per
second, Runners at 1.2, Giants at 0.6, and Carriers at 0.68. A Giant has over
seven times a Soldier's base health, so tank-led groups behave more like a
deliberate Clash-style push than a fast TD swarm.
Separate formations arrive several seconds apart, while larger same-type groups
are divided into two pushes. If the field clears early, the director advances
the next push after a short 1.25-second breather rather than leaving dead time.
The opening wave contains nine enemies at a forgiving health scale. Later waves
replace part of the weak swarms with compact Giant-led formations, so durability
continues rising without filling the board with additional bodies.
The economy starts with $500, four tower slots, and five free Walls. Guns cost
$150, Mortars cost $350, and Beams cost $750. Their three upgrades use
tower-specific prices that grow sharply toward the level-four capstone. There is
no income per kill. Wave rewards rise from $150 to $2,700 on a triangular
cumulative-income curve, with no unusable payout after wave 20. Each wave also
pays 3% interest on credits held when it began, capped at one quarter of that
wave's base reward. Each tower consumes one tower slot and each free wall
consumes one Wall allowance. Capacity grows at scheduled milestones, reaching
22 tower slots and 14 Walls after wave 20. A tower sells for its full investment before
participating in combat and 70% afterward.

The prototype is landscape-only and uses a fixed 19 by 10 gameplay grid. Cell
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
- `res://tools/prototype_map_layout_smoke.gd`
- `res://tools/prototype_layout_smoke.gd`
- `res://tools/prototype_combat_loop_smoke.gd`
- `res://tools/prototype_economy_smoke.gd`
- `res://tools/prototype_combat_integration_smoke.gd`
- `res://tools/prototype_phase1_combat_smoke.gd`
