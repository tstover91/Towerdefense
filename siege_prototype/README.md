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

The siege lab now renders a deterministic 28 by 16 landscape arena. The first
column is the enemy deployment front, the second column is a no-build approach
buffer, and the remaining cells form the fortress construction area. Its fixed
starting blueprint contains one 2 by 2 Command Core, two Cannons, and twelve Wall
segments. Four fixed terrain cells break up the otherwise empty board.

The field opens slightly zoomed in to make better use of widescreen phones.
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
Clash combat values. Raiders choose the
nearest objective, Brutes prefer defensive buildings, and Sappers create a
one-contact breach. Attackers use deterministic four-direction grid routing but
move continuously between cell centers.

Units first seek an open route to their intended non-wall building. If none
exists, they route to the reachable wall segment that best advances that same
attack. Once a segment falls, every survivor replans through the opening. This
keeps walls as topology rather than treating them as the real objective.

The two Cannons now acquire the nearest ground attacker within range and fire
at their configured 0.8-second cadence. **Start Attack**, **Rebuild**, and
**1x/2x Speed** controls support repeatable observation without adding active
combat chores.

Run `res://tools/siege_combat_phase4_smoke.gd` to validate routing, target
preferences, wall breaching, tower damage, and deterministic wave completion.

Mortar placement/firing, build-mode editing, economy, upgrades, and procedural
waves remain out of Phase 4.
