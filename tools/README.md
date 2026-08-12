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
Saucer, Hive Mother, Drone Depot, and Mech Bay are currently excluded until
their individual balance passes are complete. Trade Agreement is also excluded
because none of its affected towers are in the test pool.

Use the smoke preset after changing the optimizer itself:

```powershell
Godot.exe --headless --path . res://tools/run_balance_optimizer.tscn -- --preset=smoke --output-dir=res://balance_reports/overnight/smoke
```

Use the standard preset for an intermediate result, or the overnight preset
for the main balance study:

```powershell
Godot.exe --headless --path . res://tools/run_balance_optimizer.tscn -- --preset=overnight
```

On the development PC, the simplest launcher is:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_overnight_balance.ps1
```

The launcher finds the neighboring Godot executable, keeps its own progress
log in `balance_reports/overnight/optimizer.log`, and waits until the reports
are complete. Use `-Preset smoke` for a short validation run or `-Preset
standard` for a smaller but useful search. For a long run, keep the PC plugged
in and temporarily prevent Windows from sleeping.

Progress is saved to two alternating checkpoint files after every evolution
generation and throughout finalist testing. Running the same command again
automatically resumes the newest intact checkpoint. Checkpoints are accepted
only when the preset, seed, sample counts, and sensitivity profiles match, and
they are removed after all reports finish successfully. Add `-Fresh` to the
launcher (or `--fresh` to the Godot command) when you intentionally want to
discard an interrupted run and start over.

The overnight preset evolves 120 policies for 16 generations, then tests 16
finalists 80 times against each of 43 economy and enemy-stat profiles. Runtime
depends on the machine, but it is intentionally sized as a several-hour run.

Available overrides are `--population`, `--generations`, `--runs`,
`--final-runs`, `--finalists`, `--combat-samples`, `--seed`, and
`--output-dir`.

Reports include:

- `summary.txt`: concise top builds and sensitivity results.
- `build_dominance.csv`: repeated winning builds and clear-choice flags.
- `tower_value.csv` and `relic_value.csv`: usage, win-rate deltas, and flags.
- `sensitivity.csv`: results for each economy and enemy-stat multiplier.
- `recommended_ranges.csv`: estimated healthy ranges for global parameters.
- `strategy_results.csv` and `top_policies.json`: reproducible evolved policy
  parameters.
- `finalist_runs.csv`: raw final evaluation data.
- `manifest.json`: exact run settings and model assumptions.

This is a decision-finding model, not a replacement for playtesting. Map
geometry, manual aiming skill, selling behavior, and exact spawn timing are
approximated. Treat a flag as strong evidence to test the build in-game, and
use larger samples before making narrow numerical changes.
