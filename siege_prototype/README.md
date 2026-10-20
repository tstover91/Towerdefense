# Siege prototype

This directory is the isolated home of the fortress-autobattler experiment.
The existing grid-maze prototype remains in `res://prototype/` and continues to
run from `res://prototype/prototype_main.tscn` without depending on this mode.

## Phase 1 boundary

- `res://prototype/prototype_mode_select.tscn` is the project entry point.
- **Play Grid Maze** opens the existing prototype scene unchanged.
- **Open Siege Lab** opens `res://siege_prototype/siege_main.tscn`.
- Siege-specific boards, routing, structures, attackers, and balance data belong
  in this directory rather than being added to the grid-maze classes.

## Phase 2 fixed arena

The siege lab now renders Clash's full 44 by 44 Home Village build area, plus a
separate three-column approach on the left for deployment and entry routing.
The enemy deployment front therefore does not consume any of the 44 by 44
construction grid. The field is clear terrain so all of that area remains
available for base editing.

The field opens zoomed in to make the square village readable on widescreen phones.
One-finger or mouse dragging pans the board, two-finger pinching or the mouse
wheel zooms from 0.82x to 2.5x, and **Reset View** restores the opening view.
Panning is clamped to the map edges so the board cannot be lost off-screen.

Run `res://tools/siege_arena_layout_smoke.gd` headlessly to validate the arena,
blueprint, deployment boundary, non-overlap rules, and responsive layout.

## Phase 3 destructible fortress

The placeholder drawings are now real `SiegeStructure` nodes created from the
blueprint. Every structure owns health, a footprint, movement blocking, an
objective-integrity value, damage/destruction state, and a full-health restore.
Destroyed structures become rubble and immediately stop blocking navigation.

`SiegePrototypeBoard` exposes structure lookup, occupied/navigation cells,
damage, remaining non-wall integrity, immutable blueprint copies, and complete
blueprint reconstruction. Reconstruction replaces the structure instances from
the saved layout, so later rounds can reliably restore destroyed or removed
buildings rather than carrying battle damage forward.

The initial values and their Clash-derived rationale live in
`res://siege_prototype/CLASH_REFERENCE.md`. Run
`res://tools/siege_structure_lifecycle_smoke.gd` to validate Phase 3.

## Phase 4 autonomous siege

The test attack now contains Raiders, Brutes, and Sappers using exact TH6-era
Clash combat values. Brutes prefer defensive buildings, while Raiders have no
building preference. Sappers seek walls that protect a building instead of
detonating on exposed, irrelevant wall pieces.

Ground targeting now emulates Clash's observed rule of three: gather the three
nearest eligible buildings by footprint distance, calculate a practical route
to each, and commit to the cheapest result until that building is destroyed.
Eight-direction A* movement permits diagonal travel without cutting through
blocked corners. Routes may walk around walls or cross them; crossing cost is
derived from that wall's current HP and the unit's exact wall DPS, so troops
breach only when the detour would take longer. Once a segment falls, survivors
retain their building target and replan through the new topology. Light local
separation keeps moving troops from collapsing into one point.

Ground-capable defenses acquire the nearest valid attacker and retain that
target until it dies or leaves the tower's minimum/maximum range. They fire at
their exact configured cadence. **Start Attack**, **Rebuild**, and
**1x/2x Speed** controls support repeatable observation without adding active
combat chores.

Run `res://tools/siege_combat_phase4_smoke.gd` to validate routing, target
preferences, wall breaching, tower damage, and deterministic wave completion.

## Phase 5 editable TH6 defense roster

The fixed fortress now contains the full current Town Hall 6 defensive roster:
three Cannons, three Archer Towers, two Mortars, two Air Defenses, two Wizard
Towers, one Air Sweeper, and the Town Hall objective. Resource buildings, army
buildings, and traps are deliberately excluded. The scaled prototype fortress
uses 68 level-6 wall segments instead of Clash's 125.

Spatial values now share Clash's scale as well: the construction area is 44 by
44, the Town Hall is 4 by 4, standard defenses are 3 by 3, the Air Sweeper is
2 by 2, and Walls are 1 by 1. Tower ranges and troop movement remain expressed
directly in Clash tiles, so their proportions and travel times are no longer
inflated by the earlier condensed grid.

Before combat, tap a structure to select it or drag the structure itself to
rearrange it. Dragging empty ground pans the camera, pinching zooms, and tapping
empty ground clears the selection. Starting the attack captures and locks the
chosen layout. Rebuild restores that layout at full health and returns to
editing.

All ground-capable defenses now fire with their exact TH6-level health, damage,
cadence, range, minimum range, and splash behavior. Air Defenses and the Air
Sweeper are present and count as destructible buildings, but correctly ignore
the ground-only test army. They will become active only after flying attackers
are implemented.

Economy, upgrades, resource buildings, army buildings, traps, flying attackers,
and procedural waves remain outside Phase 5.

## Phase 6 Clash-like movement and targeting

Phase 6 supplies the targeting and movement behaviors described in Phase 4:
three-candidate target evaluation, preferred-target filtering, target
commitment, wall-aware weighted routes, protected-building selection for
Sappers, diagonal ground movement, troop separation, and defensive target lock.
These are behavioral emulations because Supercell does not publish its internal
pathfinding weights. Combat numbers remain the exact TH6 snapshot; no hidden
damage, health, range, or speed modifiers were introduced.

## Phase 7 eight-round run

The Siege Lab now runs from TH2 through TH5 rather than dropping directly into
the TH6 benchmark. Each Town Hall has an A and B battle, for eight rounds total.
TH4 introduces flying Bombers and Air Defense; TH5 introduces splash-damage
Mages and the Wizard Tower. Wave sizes are tuned for the condensed TD economy. The wave roster,
unit level, building unlocks, building level caps, health, damage, cadence,
range, footprints, and movement speed all use the current Clash values recorded
in `CLASH_REFERENCE.md`.

Between attacks the player may reposition the whole base, buy an unlocked
defense or wall, and upgrade a selected structure to the current Town Hall cap.
Gold is a deliberately condensed prototype economy; Clash prices and timers
are not used. New level-one Walls are free, matching current Clash, while their
upgrades and all defense construction/upgrades use Gold. Wall inventories now
match Clash at 25/50/75/100 for TH2-TH5. The Command Core advances for free after
each B battle, but every defense and wall keeps the level the player purchased.
As a prototype-specific exception, the low-level Command Core fires the exact
level-one Cannon shot (7 DPS, 0.8-second cadence, 9-tile range).

An attack captures a safe precombat snapshot. Holding earns Gold and advances
one battle. Losing earns nothing, loses nothing, and reconstructs that snapshot
for an immediate retry. Run `res://tools/siege_run_progression_smoke.gd` to
validate round progression, rollback, housing budgets, level caps, and exact
early-game stat resolution.
