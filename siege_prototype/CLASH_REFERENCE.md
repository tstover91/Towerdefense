# Clash reference snapshot

Collected 2026-10-19 for the siege prototype. These values are design
references, not copied balance. Clash has a much larger battlefield, longer
attacks, and years of economy/stat inflation, so direct values would produce a
slow prototype.

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

## Prototype conversion

The shared HP multiplier is approximately `900 / 2800 = 0.321`. Values are
rounded to readable increments:

| Prototype structure | HP | Integrity | Purpose |
| --- | ---: | ---: | --- |
| Command Core | 900 | 4 | Durable centerpiece, not an instant-loss Town Hall |
| Cannon | 235 | 1 | Fragile single-target defense |
| Mortar | 180 | 2 | Fragile high-impact splash defense for a later phase |
| Wall | 580 | 0 | Very durable blocker; excluded from destruction objective |

Weapon timings are separately compressed for 20–35 second rounds. The Cannon
keeps its recognizable 0.8s cadence but uses 18 damage and 5 cells of range.
The Mortar uses 55 damage every 3s, 2–6 cells of range, and 1.25-cell splash.
These are hypotheses for combat testing, not claims about Clash.

The key routing rule reproduced in Phase 4 is behavioral rather than numeric:
ground units choose a building target and only attack a wall when it blocks the
route to that target. Walls are obstacles, not part of the destruction score.

## TH6 attacker behavior baseline

| Prototype role | Clash reference | Clash reference stats | Prototype stats |
| --- | --- | --- | --- |
| Raider | Level-3 Barbarian | 65 HP, 14 DPS, no preferred building | 70 HP, 22 damage each 1s, 2.2 cells/s |
| Brute | Level-3 Giant | 600 HP, 20 DPS, 2s attack, 1.5 tiles/s, defenses preferred | 280 HP, 36 damage each 2s, 1.5 cells/s, defenses preferred |
| Sapper | Level-3 Wall Breaker | 29 HP, 1,000 contact damage to walls plus death damage, 3 tiles/s, walls preferred | 42 HP, 600 wall damage, 3 cells/s, self-destructs |

Attacker sources:

- Barbarian: https://clashofclans.fandom.com/wiki/Barbarian
- Giant: https://clashofclans.fandom.com/wiki/Giant
- Wall Breaker: https://clashofclans.fandom.com/wiki/Wall_Breaker?page=2
- Movement conversion: https://clashofclans.fandom.com/wiki/Troop_Movement_Speed

The prototype deliberately compresses the Giant's HP advantage so Cannons can
resolve a wave quickly. The Sapper is tuned to destroy one full-health wall in
one successful contact, making the breach readable and strategically decisive.
