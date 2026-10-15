# Grid maze prototype

This scene is isolated from the current game and does not replace its main scene.

Run `res://prototype/prototype_main.tscn` in Godot. Tap an empty grid cell to
place a blocking tower and tap an existing tower to select it. Use the footer
controls to upgrade or sell the selected tower. Placement is rejected when it
would block the entrance route or trap an active enemy.

Use **Start Wave** to play the ten-wave combat slice. Enemies arrive in planned
groups, rounds finish as soon as all planned enemies are defeated or leak, and
moving enemies adopt recalculated four-direction routes without teleporting.
The economy starts with $500 and five tower slots. Towers cost $100; upgrades
cost $100, $300, and $800. There is no income per kill. Clearing a wave pays a
base reward that starts at $120 and rises by $20 per wave, plus 5% interest on
the credits held when the wave began. Interest is capped at half the wave's base
reward. Capacity increases after waves 2, 4, 6, and 8. A tower sells for its full
investment before participating in combat and 70% afterward.

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
