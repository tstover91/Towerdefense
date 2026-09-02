# Performance stress test

Run this from PowerShell without Codex:

```powershell
.\tools\run_performance_stress.ps1
```

The default run holds a representative late-game roster at level 20 while
increasing the live enemy count through 1, 30, 60, and 90. Each stage lasts
eight seconds. A final cleanup stage removes all enemies and ends combat so
objects or processing that persist after a wave remain visible in the report.

Reports are written to `balance_reports/performance_stress_<timestamp>.csv`.
The runner prints a summary table when it finishes.

Useful options:

```powershell
.\tools\run_performance_stress.ps1 -StageDuration 15 -EnemyStages "1,30,60,90,120"
.\tools\run_performance_stress.ps1 -GodotPath "C:\path\to\Godot.exe"
.\tools\run_performance_stress.ps1 -OutputPath ".\balance_reports\my_phone_comparison.csv"
```

Interpretation:

- `average_process_ms` measures script and normal frame processing.
- `average_physics_ms` measures physics and overlap processing.
- `worst_frame_ms` and `frames_over_33ms` expose stutters hidden by average FPS.
- Object columns show projectiles, units, effects, resolvers, hooks, Saucers,
  and total nodes at the end of each stage.
- In `cleanup`, enemies, projectiles, spawned units, resolvers, and hooks should
  return to zero or their intentional idle baseline. Total nodes should return
  close to the `enemies_1` baseline.
- A high cleanup processing time with low object counts points to persistent
  per-tower work. Growing object counts point to a cleanup or pooling problem.

Desktop and mobile results should be compared by ratios between stages rather
than raw FPS because each device and build can have a different frame cap.
