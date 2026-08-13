# Project tools

Run the tower balance simulation through its lightweight scene so it uses the
same startup path as the game:

```powershell
Godot.exe --headless --path . res://tools/tower_balance_monte_carlo.tscn -- --iterations=1000 --duration=30
```

Optional arguments are `--seed`, `--towers`, and `--report-path`.

## Run-level balance optimizer

The run-level optimizer searches complete 20-round build policies. It models
staged tower purchases and upgrades, paths, tower and relic drafts, kill and
round income, Dividends, discounts, major relic interactions, enemy growth,
splits, summons, armor, speed, density, control, and roster opportunity cost.
Combat values are sampled across multiple enemy-health scales so early-round
overkill does not inflate later-round DPS. The optimizer also uses the game's
shared role/formation weights, special round variants, paid relic refreshes,
and placement-dependent range and adjacency relics.
It evaluates every possible two-tower starting roster. Saucer is included with
approximations for pursuit uptime, abduction executions, prevented split
children, Homing Rockets, and Specimen Deployment. Hive Mother, Drone Depot,
and Mech Bay remain excluded until their individual balance passes are
complete. Trade Agreement is excluded because none of its affected towers are
in the test pool. Long Term Investment is excluded because the optimizer does
not sell towers, which would otherwise make it a selectable no-op.

Use the smoke preset after changing the optimizer itself:

```powershell
Godot.exe --headless --path . res://tools/run_balance_optimizer.tscn -- --preset=smoke --output-dir=res://balance_reports/overnight/smoke
```

Use the focused early preset after changing opening tower balance. By default
it reuses the completed overnight run's finalist policies, tests baseline
starter pairs through round 10, and writes per-round
purchase and survival data without overwriting the overnight reports:

```powershell
Godot.exe --headless --path . res://tools/run_balance_optimizer.tscn -- --preset=early --output-dir=res://balance_reports/early_round_test --fresh
```

Add `--forced-starter=invader`, `--forced-starter=slinger`, or
`--forced-starter=reaver` to place that tower at level 1 before the optimizer
spends the rest of its starting money.

Use `--forced-starter= --starter-pool=invader,slinger,reaver` to test the
three possible two-tower starter pairs without forcing the first purchase.
Add `--evolve-focused` to evolve fresh purchasing strategies under the current
balance instead of reusing the overnight policies.

Add `--map-geometry` to use the current `main.tscn` path and placement area.
Map combat divides the path into physical segments, advances each enemy type
along them according to its movement speed, and only lets a tower damage the
foremost occupied segment inside that tower's actual range. Damage does not
transfer to enemies on uncovered parts of the path. This also models tower
idle time, overlapping coverage, minimum range, localized overkill, and leaks
at the end of the path. It costs substantially more CPU than aggregate combat,
so use the worker pool and validate optimizer changes with the focused starter
set before starting an overnight run.

Map combat uses quarter-second movement updates and approximately 32-pixel
path segments so fast enemies cannot skip short tower coverage between model
updates. Enemy totals are cached from dry runs of the live wave director, so
formation spacing, group cooldowns, and unspent threat constrain simulated
waves the same way they constrain gameplay.

During map combat, whole dollars of earned kill income are credited once per
simulated second. Policies can immediately build or upgrade with that money,
and those purchases contribute for the remainder of the wave. Fractional
expected income is retained after combat but cannot be spent early.

Use `--live-build-benchmark` to replay the recorded Invader/Gauss/Longshot
opening through round 7. It tests both reported possibilities for the third
Invader (level 2 or level 3), both round-6 variants, and writes normal trace
reports for direct comparison with live play.

Use the standard preset for an intermediate result, or the overnight preset
for the main balance study:

```powershell
Godot.exe --headless --path . res://tools/run_balance_optimizer.tscn -- --preset=overnight --map-geometry
```

On the development PC, the simplest launcher is:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_overnight_balance.ps1
```

The launcher finds the neighboring Godot executable, uses the current map
geometry, keeps its own progress log in
`balance_reports/overnight/optimizer.log`, and waits until the reports are
complete. Expensive policy and finalist simulations run on Godot's worker
pool. By default the launcher uses all but one logical processor; on a
12-thread CPU this means 11 workers. Override that with `-Workers 6`, for
example, if you want to leave more capacity for other work. Use `-Preset smoke`
for a short validation run or `-Preset standard` for a smaller but useful
search. For a long run, keep the PC plugged in and temporarily prevent Windows
from sleeping.

Progress is saved to two alternating checkpoint files after every evolution
generation and throughout finalist testing. Running the same command again
automatically resumes the newest intact checkpoint. Checkpoints are accepted
only when the preset, seed, sample counts, and sensitivity profiles match, and
they are removed after all reports finish successfully. Add `-Fresh` to the
launcher (or `--fresh` to the Godot command) when you intentionally want to
discard an interrupted run and start over.

The overnight preset evolves 120 policies for 16 generations using 110 runs
per policy, so every one of the 55 starter pairs is seen twice per policy. It
then tests 16 finalists 220 times against each of 43 economy and enemy-stat
profiles, giving every starter pair four repetitions per policy and profile.
Runtime depends on the machine and is intentionally sized as a detailed
overnight run.

Available overrides are `--population`, `--generations`, `--runs`,
`--final-runs`, `--finalists`, `--combat-samples`, `--workers`, `--seed`, and
`--output-dir`. Focused tests also accept `--round-limit`,
`--source-policies`, `--forced-starter`, `--starter-pool`, `--evolve-focused`,
`--source-policy-limit`, `--map-geometry`, and `--record-round-history`.
`--source-policy-limit` is useful for small parity checks that should sample
only the first few saved policies. Explicit overrides take precedence over
preset defaults.

Reports include:

- `summary.txt`: concise top builds and sensitivity results.
- `build_dominance.csv`: repeated winning builds and clear-choice flags.
- `starter_roster_value.csv`: all starting pairs, win-rate deltas, profile
  coverage, and clear-choice flags.
- `starter_tower_value.csv`: the isolated association between each tower being
  in the starting pair and run success.
- `tower_value.csv` and `relic_value.csv`: usage, win-rate deltas, and flags.
- `sensitivity.csv`: results for each economy and enemy-stat multiplier.
- `recommended_ranges.csv`: estimated healthy ranges for global parameters.
- `strategy_results.csv` and `top_policies.json`: reproducible evolved policy
  parameters.
- `finalist_runs.csv`: raw final evaluation data.
- `manifest.json`: exact run settings and model assumptions.

This is a decision-finding model, not a replacement for playtesting. With
`--map-geometry`, path movement, localized crowd control, tower coverage,
range-changing relics, and adjacency relics are segment/placement based.
Manual aiming, individual projectile timing, exact formation spacing, child
spawn timing, selling behavior, and some triggered relic effects remain
approximations. Treat a flag as strong evidence to test the build in-game, and
use larger samples before making narrow numerical changes.

## Controlled starter calibration

Use the dedicated starter calibration after changing Invader, Reaver, Slinger,
or Gauss Repeater. It tests each tower as a solo roster and all six two-tower
rosters with the same starting cash. Four fixed purchasing strategies cover
building, upgrading, balanced spending, and saving for future upgrades. Relics
are disabled, round 6 is tested separately as fixed Horde and Elite variants,
and matched seeds make strategy comparisons repeatable.

```powershell
Godot.exe --headless --path . res://tools/run_balance_optimizer.tscn -- --starter-calibration --map-geometry --final-runs=20 --output-dir=res://balance_reports/starter_calibration_round7 --fresh
```

The focused output is `starter_calibration.csv`. It includes survival, leaks,
money, spending, path coverage, upgrade and tower counts, first purchases, and
the most common final build for every strategy, roster, and round-6 variant.
