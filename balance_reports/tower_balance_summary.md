# Enemy Pacing and Tower Power — Initial Test Pass

## Runtime enemy scaling

All non-boss archetypes now receive a centralized `1.80` health multiplier and `0.70` movement-speed multiplier. These multiply both base health and per-wave health growth, so normal variants gain exactly 80% underlying health before integer rounding and move 30% slower.

| Variant | Previous health factor | New combined non-boss factor | Change from previous |
|---|---:|---:|---:|
| Normal | 1.00 | 1.80 | +80.0% |
| Horde | 0.70 | 1.80 × 0.55 = 0.99 | +41.4% |
| Elite | 3.00 | 1.80 × 2.25 = 4.05 | +35.0% |
| Payday | 0.65 | 1.80 × 0.50 = 0.90 | +38.5% |

Elite speed is `0.70 × 1.30 = 0.91` of its archetype's original base speed. This is about 20.9% slower than the previous elite speed factor of `1.15`, while keeping elites 30% faster than their new standard counterparts. Boss health and speed are unchanged.

Example base speeds:

- Normal: 100 → 70
- Runner: 160 → 112
- Swarmling: 115 → 80.5
- Bruiser: 70 → 49
- Armored: 75 → 52.5
- Rusher: 90 → 63, increasing to 126 during its existing rush
- Brute boss: remains 40

## Threat and formation pacing

- Threat generation: ×1.40 at every round before existing horde/gauntlet/payday modifiers
- Requested director group size: ×1.25, rounded per group
- Ordinary formation intervals and between-group gaps: ×0.70
- Intentionally spaced formations: ×0.85
- Boss-escort formation spacing: unchanged
- Existing horde group-size multiplier, horde threat multiplier, horde delay multiplier, elite-event timing, active-enemy caps, threat costs, wave durations, and spawn architecture: unchanged

At equal kill rates, `1.40 ÷ 0.70` gives approximately twice the potential ordinary-enemy road occupancy before active-cap effects. Durability should increase occupancy further when defenses cannot immediately clear a group.

## Targeted tower reductions

Only unusually steep late numerical scaling or unusually efficient final mechanics were reduced.

| Tower or mechanic | Change |
|---|---|
| Invader Level 4 | Damage 5 → 4 (-20.0%) |
| Gauss Heavy Accelerator | Heavy-shot multiplier 15× → 12× (-20.0%) |
| Beholder Level 4 | Damage 10 → 8 (-20.0%) |
| Reaver Level 4 | Damage 31 → 25 (-19.4%) |
| Longshot Level 4 | Damage 90 → 70 (-22.2%) |
| Slinger Level 4 | Damage 29 → 23 (-20.7%) |
| Void Caller Level 4 | Damage 38 → 30 (-21.1%) |
| Orb Barrage | Each orb receives an additional 0.80 damage multiplier |
| Orbital Cannon Level 4 | Damage 175 → 135 (-22.9%) |
| Bombardment | Per-strike multiplier 0.45 → 0.36 (-20.0%) |
| Hive Mother Level 4 spores | Unit damage 15 → 12 (-20.0%) |
| Mech Bay Level 4 mechs | Unit damage 40 → 34 (-15.0%) |

Attack intervals, ranges, path costs, upgrade costs, and final-path behaviors were not changed. Brainiac, Energy Core, Saucer, Drone Depot, and Gauss Repeater's normal Level 4 fire retained their numerical stats because their measured marginal efficiency was not excessive or their value is strongly tied to utility and uptime.

Before this pass, Slinger, Invader, Hive Mother, Reaver, Void Caller, and Orbital Cannon had the strongest final numerical jumps. After the pass, Slinger and Invader remain the most efficient late raw upgrades, but their final-upgrade marginal efficiency fell to approximately 2.69 and 2.13 DPS per $100 respectively.

## Intentionally unchanged

- Enemy threat costs and composition weights preserve archetype ratios.
- Enemy cash rewards are unchanged for this first test. More enemies will increase income; this may help fund a broader defense, but economy inflation should be watched closely.
- Defense, leak damage, regeneration, summoning, rush behavior, and speed auras are unchanged.
- Boss stats are unchanged to avoid combining a boss rebalance with the ordinary-road-density test.
- Relics, targeting, tower placement, round structure, and UI are unchanged.

## Next playtest watchpoints

1. Whether 1× speed now feels visually active without making the road permanently saturated.
2. Whether waves form readable clusters and then clear, instead of becoming a continuous unbroken line.
3. Whether normal enemies survive long enough for two or more towers to engage them.
4. Whether AoE, pierce, bounce, chain, and control noticeably outperform single-target fire in dense moments.
5. Whether rounds 1–3 became too punishing before the first tower draft.
6. Whether the 40% additional enemy income lets players max towers just as quickly; if so, reduce per-enemy rewards rather than undoing the density improvements.
7. Whether Slinger and Invader still dominate repeated-upgrade strategies.
