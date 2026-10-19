# Clash reference snapshot

Collected 2026-10-19 for the siege prototype. Phase 4 now uses these combat
values directly so the first playtests evaluate Clash's real low-level health,
damage, cadence, range, and movement relationships before custom balancing.

## TH6 structure baseline

| Role | Clash reference | HP | Offense / behavior |
| --- | --- | ---: | --- |
| Command Core | Town Hall 6 | 2,800 | Central objective; 4x4 footprint in Clash |
| Cannon | Level 7 | 730 | 40 normal DPS, 0.8s normal shot cadence, range 9, ground-only, single target. A 2026 burst mode reports 80 DPS. |
| Mortar | Level 4 | 550 | 35 per hit, 5s cadence, range 4–11, 1.5-tile splash, ground-only |
| Wall | Level 6 | 1,800 | 1x1 blocker; walls do not count toward destruction percentage |

Sources:

- Town Hall history: https://clashofclans.fandom.com/wiki/Town_Hall/History
- Cannon level 7: https://liquipedia.net/clashofclans/Cannon/home_village/level_7
- Current Cannon table: https://clashofclans.fandom.com/wiki/Cannon
- Mortar: https://clashofclans.fandom.com/wiki/Mortar?page=3
- Wall: https://clashofclans.fandom.com/wiki/Wall
- Official wall balance change: https://supercell.com/en/games/clashofclans/blog/release-notes/welcome-to-lets-get-crafty-update/
- Routing behavior: https://clashofclans.fandom.com/wiki/Glossary/Q-Z

The official balance notes and current Home Village table both report 1,800.
The separate Builder Base table reports 2,200 for its level-6 wall; these modes
must not be mixed when deriving the prototype ratio.

## Prototype implementation

| Prototype structure | HP | Integrity | Combat implementation |
| --- | ---: | ---: | --- |
| Command Core | 2,800 | 4 | Exact TH6 Town Hall HP; still not an instant-loss objective |
| Cannon | 730 | 1 | 32 damage every 0.8s, range 9 |
| Mortar | 550 | 2 | 35 damage every 5s, range 4–11, splash 1.5 |
| Wall | 1,800 | 0 | Exact level-6 HP; excluded from destruction objective |

Integrity values, the Command Core's objective behavior, the 28×16 geometry,
and the names/visuals remain prototype-specific. They are not Clash stats.

The key routing rule reproduced in Phase 4 is behavioral rather than numeric:
ground units choose a building target and only attack a wall when it blocks the
route to that target. Walls are obstacles, not part of the destruction score.

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
