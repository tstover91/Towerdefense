# Tower Combat Balance — Four-Level Progression

Generated from `tower_monte_carlo.csv` with 250 trials per case, a 30-second combat window, and seed `730241`.

## Scope

- 14 towers
- Four regular tower levels, displayed as Levels 1 through 4
- Final Path A, Path B, and dual-path variants
- Four cases: one normal target, one armored elite, a four-enemy fast pack, and a twelve-enemy horde
- 392 tower/level/path/scenario combinations
- No relic modifiers

The simulation assumes targets are continuously available. Manual zones and area attacks therefore represent favorable uptime. Control, Reveal, movement, target selection, abduction, and similar utility are not assigned a dollar value.

## Changes in This Pass

- Removed the former penultimate regular level from every tower
- Preserved each tower's starting stats, early upgrades, middle upgrade, and former maximum stats
- Final paths now unlock at displayed Level 4
- Recalculated every fixed upgraded sell value without the removed upgrade
- Changed player-facing tower levels from zero-based `0/3` to `1/4`
- Solar Lance duration: 2.0 → 1.25 seconds
- Solar Lance firing interval: 40% longer
- Triple Bloom: three projectiles retained, each at 65% damage
- Void Caller orb blast radii by level: 2.5–4.0 → 2.0–3.0 tiles
- Singularity explosion radius: 4.5 → 4.0 tiles
- Continuous Beam damage: +40%
- Invader attack intervals increased across all levels
- Reaver damage reduced and attack intervals increased across all levels

## Level-0 Baseline

| Tower | Average DPS | DPS per $100 |
|---|---:|---:|
| Invader | 5.3 | 4.27 |
| Slinger | 6.5 | 3.74 |
| Reaver | 5.1 | 3.40 |
| Void Caller | 11.2 | 3.21 |
| Gauss Repeater | 12.1 | 2.69 |
| Energy Core | 6.6 | 2.20 |
| Longshot | 7.5 | 2.15 |
| Orbital Cannon | 13.7 | 1.96 |
| Beholder | 9.3 | 1.86 |
| Hive Mother | 4.4 | 1.74 |
| Brainiac | 4.9 | 1.51 |
| Saucer | 7.7 | 1.47 |
| Mech Bay | 3.0 | 0.61 |
| Drone Depot | 2.7 | 0.50 |

Invader remains the most efficient general-purpose starter, but its average efficiency fell from 5.34 to 4.27 DPS per $100. Reaver fell from 4.06 to 3.40 and now sits below Slinger.

## Affected Final Paths

| Maximum-level option | Average DPS | Single DPS | Horde DPS |
|---|---:|---:|---:|
| Solar Lance | 240.1 | 72.3 | 602.1 |
| Triple Bloom | 113.1 | 135.0 | 121.5 |
| Orb Barrage | 191.3 | 126.7 | 356.2 |
| Invader — no path | 35.4 | 42.4 | 38.1 |
| Dual Pistols | 70.9 | 84.7 | 76.2 |
| Continuous Beam | 45.1 | 53.8 | 48.5 |
| Reaver — no path | 34.6 | 41.3 | 37.2 |
| Assassinate | 53.7 | 64.0 | 57.7 |

## Result

- Solar Lance's ideal horde output fell from about 1,353 to 602 DPS. It remains a strong crowd-specialist path, but Bombardment now competes with it instead of being broadly outclassed.
- Triple Bloom fell from roughly 203 to 135 single-target DPS. It now provides about double the unpathed Hive Mother's output instead of triple.
- The smaller Void Caller explosions reduced Orb Barrage's modeled horde output from about 402 to 356 DPS while preserving its five-orb identity.
- Continuous Beam now deals about 27% more isolated damage than the unpathed level-four Invader. Dual Pistols remains the higher raw-DPS choice, while Beam retains its separate relic synergies.
- Invader and Reaver remain efficient cheap towers without being as far ahead of the early roster.
- Maximum-level Path A costs now range from $2,730 for Invader to $11,800 for Orbital Cannon. Each path is reached one purchase sooner while retaining the former maximum pre-path combat stats.

Spawner towers still require controlled in-game testing because their movement, spawn ramp, recharge, and target access are approximated.
