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

The fixed benchmark fortress contains the selected Town Hall 6 defensive roster:
three Cannons, three Archer Towers, two Mortars, two Air Defenses, two Wizard
Towers, and the Town Hall objective. Air Sweepers, Hidden Teslas, heroes,
resource buildings, army buildings, and traps are deliberately excluded. The scaled prototype fortress
uses 68 level-6 wall segments instead of Clash's 125.

Spatial values now share Clash's scale as well: the construction area is 44 by
44, the Town Hall is 4 by 4, standard defenses are 3 by 3, and Walls are 1 by 1.
Tower ranges and troop movement remain expressed
directly in Clash tiles, so their proportions and travel times are no longer
inflated by the earlier condensed grid.

Before combat, tap a structure to select it or drag the structure itself to
rearrange it. Dragging empty ground pans the camera, pinching zooms, and tapping
empty ground clears the selection. Starting the attack captures and locks the
chosen layout. Rebuild restores that layout at full health and returns to
editing.

Selecting a Wall exposes every valid adjacent extension arrow. Press or drag
from an arrow to paint one connected path, including corners; dragging backward
removes the last previewed segment. The complete chain stays a green preview
until one confirmation commits it, while cancel leaves the blueprint unchanged.
The placement panel reports both the number drawn and the current Town Hall's
remaining Wall allowance.

Walls placed by a drafted Wall Plan retain that formation as part of the saved
blueprint. Selecting any piece highlights the formation, and dragging that piece
moves the complete formation without changing its shape. Blocked or
out-of-bounds moves return the formation to its previous position.

Selecting any armed structure, including the weakly armed Command Core, draws
its true firing radius over the board. Towers with a blind spot, such as the
Mortar, also draw their minimum-range dead zone; both circles use the same
Clash-scaled cell ranges as combat targeting.

All included defenses now use their exact TH6-level health, damage, cadence,
range, minimum range, target type, and splash behavior. Air Defenses correctly
ignore ground attackers and engage flying attackers.

Resource buildings, army buildings, traps, Tesla, Air Sweeper, and heroes remain
outside the prototype by design.

## Phase 6 Clash-like movement and targeting

Phase 6 supplies the targeting and movement behaviors described in Phase 4:
three-candidate target evaluation, preferred-target filtering, target
commitment, wall-aware weighted routes, protected-building selection for
Sappers, diagonal ground movement, troop separation, and defensive target lock.
These are behavioral emulations because Supercell does not publish its internal
pathfinding weights. Combat numbers remain the exact TH6 snapshot; no hidden
damage, health, range, or speed modifiers were introduced.

## Phase 7 twelve-round run

The Siege Lab has twelve attacks whose enemy compositions advance independently
from the player's Town Hall. The current sequence still introduces flying
Bombers, splash-damage Mages, Healers, Dragons, Minions, and wall-jumping Hog
Riders in the established order, but victories no longer grant an automatic
Town Hall level. Wave sizes are tuned for the condensed TD economy. The wave
roster, unit levels, health, damage, cadence, range, footprints, and movement
speed use the current Clash values recorded in `CLASH_REFERENCE.md`.

Between attacks the player may reposition the whole base, buy an unlocked
defense, or make the large strategic investment in the next Town Hall level.
Town Hall upgrades are immediate and available whenever the player can afford
them. They strengthen the Core, every existing defense, every Wall, and all
future construction; they also raise shared defense capacity, increase the Wall
allowance, unlock defenses, and offer that Town Hall's Wall Plan draft. Ordinary
structures no longer have separate statistical upgrade purchases.

The first permanent tower-role choice is available on the Thermal Projector.
It can become a Plasma Caster, which keeps and strengthens its ground-and-air
splash role, or an Inferno Beam, which keeps ground-and-air coverage but trades
splash for rapid single-target damage that ramps while it holds one enemy. The
choice is made once from the selected-tower controls. Its health and baseline
damage continue to rise with purchased Town Hall levels, so specialization does
not create a second upgrade ladder.

Gold is a deliberately condensed prototype economy; Clash prices and timers
are not used. Wall inventories match Clash at 25/50/75/100/125/175 for TH2-TH7.
As a prototype-specific exception, the low-level Command Core fires the exact
level-one Cannon shot (7 DPS, 0.8-second cadence, 9-tile range).

An attack captures a safe precombat snapshot. Holding earns Gold and advances
one round without changing the Town Hall. Losing earns nothing, loses nothing,
and reconstructs that snapshot for an immediate retry. Run
`res://tools/siege_run_progression_smoke.gd` to validate independent round and
Town Hall progression, rollback, housing budgets, unlocks, global stat refresh,
and exact early-game stat resolution.
Run `res://tools/siege_specialization_smoke.gd` to validate specialization
choice, spending, combat behavior, Town Hall scaling, and blueprint persistence.
