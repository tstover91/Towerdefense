# Clash reference snapshot

Collected 2026-10-19 for the siege prototype. Phase 4 now uses these combat
values directly so the first playtests evaluate Clash's real low-level health,
damage, cadence, range, and movement relationships before custom balancing.

## TH6 structure baseline

| Role | Clash reference | HP | Offense / behavior |
| --- | --- | ---: | --- |
| Command Core | Town Hall 6 | 2,800 | Central objective; 4x4 footprint in Clash |
| Cannon | Level 7 | 730 | 40 normal DPS, 0.8s normal shot cadence, range 9, ground-only, single target. A 2026 burst mode reports 80 DPS. |
| Archer Tower | Level 7 | 630 | 42 DPS, 0.5s cadence, range 10, ground and air, single target |
| Mortar | Level 4 | 550 | 35 per hit, 5s cadence, range 4–11, 1.5-tile splash, ground-only |
| Air Defense | Level 4 | 950 | 160 damage every 1s, range 10, air-only, single target |
| Wizard Tower | Level 3 | 680 | 20.8 damage every 1.3s, range 7, 1-tile splash, ground and air |
| Air Sweeper | Level 2 | 800 | No damage; 2-tile push every 5s, range 1–15, air-only |
| Wall | Level 6 | 1,800 | 1x1 blocker; walls do not count toward destruction percentage |

Sources:

- Town Hall history: https://clashofclans.fandom.com/wiki/Town_Hall/History
- Cannon level 7: https://liquipedia.net/clashofclans/Cannon/home_village/level_7
- Current Cannon table: https://clashofclans.fandom.com/wiki/Cannon
- Archer Tower: https://clash-of-clans.1337wiki.com/archer-tower-home-village/
- Mortar: https://clashofclans.fandom.com/wiki/Mortar?page=3
- Air Defense: https://clash-of-clans.1337wiki.com/air-defense-home-village/
- Wizard Tower: https://clash-of-clans.1337wiki.com/wizard-tower-home-village/
- Air Sweeper: https://clash-of-clans.1337wiki.com/air-sweeper-home-village/
- Wall: https://clashofclans.fandom.com/wiki/Wall
- Official wall balance change: https://supercell.com/en/games/clashofclans/blog/release-notes/welcome-to-lets-get-crafty-update/
- Routing behavior: https://clashofclans.fandom.com/wiki/Glossary/Q-Z

The official balance notes and current Home Village table both report 1,800.
The separate Builder Base table reports 2,200 for its level-6 wall; these modes
must not be mixed when deriving the prototype ratio.

## Prototype implementation

| Prototype structure | HP | Integrity | Combat implementation |
| --- | ---: | ---: | --- |
| Command Core | 2,800 | 1 | Exact TH6 Town Hall HP; still not an instant-loss objective |
| Cannon | 730 | 1 | 32 damage every 0.8s, range 9 |
| Archer Tower | 630 | 1 | 21 damage every 0.5s, range 10 |
| Mortar | 550 | 1 | 35 damage every 5s, range 4–11, splash 1.5 |
| Air Defense | 950 | 1 | 160 damage every 1s, range 10; correctly inactive against ground units |
| Wizard Tower | 680 | 1 | 20.8 damage every 1.3s, range 7, splash 1 |
| Air Sweeper | 800 | 1 | Air-only push; correctly inactive against ground units |
| Wall | 1,800 | 0 | Exact level-6 HP; excluded from destruction objective |

Every non-wall building contributes one objective point, matching the rule that
attackers must destroy all non-wall buildings. The build area and footprints now
use Clash's 44×44 spatial scale: Town Hall 4×4, standard defenses 3×3, Air
Sweeper 2×2, and Walls 1×1. The 68-wall inventory, three-column left approach,
Command Core name, and visuals remain prototype-specific.

The routing implementation is behavioral rather than a claim to reproduce
Supercell's unpublished source code. Ground troops emulate the community-observed
"rule of three": select the three closest eligible buildings by direct footprint
distance, compare routes, then commit to one building. Preferred-target units
apply that rule within their preferred category. A route can walk around walls
or cross them; its wall cost is calculated from each wall's live HP and that
troop's exact wall DPS. Walls remain intermediate obstacles, not destruction
objectives. Wall Breakers consider protected buildings and attack the first wall
on the selected route. Ground movement supports eight directions without corner
cutting, while small local separation prevents exact unit overlap. Defenses lock
their current target until it dies or leaves range.

Behavior references:

- Community targeting/pathfinding analysis: https://goblinsfarm.com/wiki/mechanics/troop-targeting-and-ai.html
- Wall Breaker targeting summary: https://clash-of-clans.1337wiki.com/wall-breaker/
- Compartment targeting examples: https://www.clashchamps.com/2023/01/31/how-to-use-super-wall-breakers-ai-path-best-usage/

The exact hidden wall weights, collision radii, steering constants, and tie-break
rules are not publicly documented. The prototype therefore exposes those as
explicit approximations while preserving the sourced HP, damage, cadence, range,
movement speed, footprint, and board-scale values above.

## TH6 attacker behavior baseline

| Prototype role | Clash reference | Clash reference stats | Prototype stats |
| --- | --- | --- | --- |
| Raider | Level-3 Barbarian | 65 HP, 15 damage every 1s, no preferred building, 2.2 tiles/s | Exact combat values |
| Brute | Level-3 Giant | 600 HP, 40 damage every 2s, 1.5 tiles/s, defenses preferred | Exact combat values |
| Sapper | Level-3 Wall Breaker | 29 HP, 25 contact plus 13 death damage; x40 against walls; 3 tiles/s | Exact contact/death values and 2-tile death splash |

Attacker sources:

- Barbarian: https://clashofclans.fandom.com/wiki/Barbarian
- Giant: https://clashofclans.fandom.com/wiki/Giant
- Wall Breaker: https://clashofclans.fandom.com/wiki/Wall_Breaker?page=2
- Movement conversion: https://clashofclans.fandom.com/wiki/Troop_Movement_Speed

The deterministic test wave composition is allowed to change, but these unit
and structure combat values should remain untouched until the exact-stat test
has produced enough playtest evidence to justify a deliberate balance change.

## TH1-TH3 run snapshot

| Town Hall | Army space | Defense caps | Troop levels |
| --- | ---: | --- | --- |
| TH1 | 20 | 1 Cannon, level 2; no Walls | Raider/Barbarian 1, Ranger/Archer 1 |
| TH2 | 30 | 2 Cannons, level 3; 1 Archer Tower, level 2; Walls level 2 | Raider/Barbarian 1, Ranger/Archer 1, Brute/Giant 1 |
| TH3 | 70 | 2 Cannons, level 4; 1 Archer Tower, level 3; 1 Mortar, level 1; Walls level 3 | Raider/Barbarian 2, Ranger/Archer 2, Brute/Giant 1, Sapper/Wall Breaker 1 |

Current early-game structure values used by the run:

- Town Hall HP: 400 / 800 / 1,600 at TH1 / TH2 / TH3.
- Cannon levels 1-4: 300 / 360 / 420 / 500 HP and 7 / 10 / 13 / 17 DPS, firing every 0.8 seconds at range 9.
- Archer Tower levels 1-3: 380 / 420 / 460 HP and 11 / 15 / 19 DPS, firing every 0.5 seconds at range 10.
- Mortar level 1: 400 HP, 20 damage every 5 seconds, range 4-11, 1.5-tile splash.
- Wall levels 1-3: 100 / 200 / 400 HP.

Current early-game troop values used by the run:

- Barbarian levels 1-2: 45 / 54 HP, 9 / 12 DPS, 1 housing, 2.25 tiles per second.
- Archer levels 1-2: 22 / 26 HP, 8 / 10 DPS, 1 housing, range 3.5, 3 tiles per second.
- Giant level 1: 400 HP, 12 DPS (24 every 2 seconds), 5 housing, 1.5 tiles per second, defenses preferred.
- Wall Breaker level 1: 20 HP, 10 contact damage and 6 death damage, both x40 against Walls, 2 housing, 3 tiles per second.

The A/B wave budgets are 75% (rounded down) and 100% of the listed army space:
15/20, 22/30, and 52/70. Spawn spacing is custom TD pacing and does not change
any unit combat statistic. Run rewards, build prices, upgrade prices, and the
reduced 0/12/20 wall inventories are also intentionally prototype-specific.

Early-game sources:

- Official 2026 early-game balance values: https://supercell.com/en/games/clashofclans/blog/release-notes/welcome-to-lets-get-crafty-update/
- TH1 roster and caps: https://clash-of-clans.1337wiki.com/town-hall-level-1/
- TH2 roster and caps: https://clash-of-clans.1337wiki.com/town-hall-level-2/
- TH3 roster and caps: https://clash-of-clans.1337wiki.com/town-hall-level-3/
- Cannon: https://clash-of-clans.1337wiki.com/cannon-home-village/
- Archer Tower: https://clash-of-clans.1337wiki.com/archer-tower-home-village/
- Mortar: https://clash-of-clans.1337wiki.com/mortar-home-village/
- Walls: https://clash-of-clans.1337wiki.com/walls-home-village/
- Barbarian: https://clash-of-clans.1337wiki.com/barbarian/
- Archer: https://clash-of-clans.1337wiki.com/archer/
- Giant: https://clash-of-clans.1337wiki.com/giant/
- Wall Breaker: https://clash-of-clans.1337wiki.com/wall-breaker/
