param(
    [string]$GodotPath = "",
    [int]$Workers = 0,
    [int]$Level = 10,
    [int]$Iterations = 1,
    [int]$MaxTotalReportMB = 4096,
    [int]$MaxTotalOutlierMB = 4096,
    [switch]$OutliersOnly,
    [switch]$Resume,
    [switch]$Stop,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$auditRoot = Join-Path $projectRoot "balance_reports\item_combinations_overnight"
$latestRunPath = Join-Path $auditRoot "latest_run.txt"

if ($Stop) {
    if (-not (Test-Path -LiteralPath $latestRunPath)) {
        throw "No previous audit run was found."
    }
    $savedRelativeOutput = (Get-Content -LiteralPath $latestRunPath -Raw).Trim()
    $savedOutputDirectory = Join-Path $projectRoot ($savedRelativeOutput -replace "/", "\")
    $statePath = Join-Path $savedOutputDirectory "run_state.json"
    if (-not (Test-Path -LiteralPath $statePath)) {
        throw "The latest audit has no run-state file."
    }
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $stopped = 0
    foreach ($processId in @($state.process_ids)) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if ($null -ne $process -and $process.ProcessName -like "Godot*") {
            Stop-Process -Id $process.Id -Force
            $stopped++
        }
    }
    $state.status = "stopped"
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath
    Write-Host "Stopped $stopped audit workers. Run again with -Resume to continue from the latest completed tower/path checkpoints."
    exit 0
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\Godot_v4.7.1-stable_win64.exe"))
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot was not found at: $GodotPath`nPass its location with -GodotPath."
}

$logicalCores = [Environment]::ProcessorCount
if ($Resume) {
    if (-not (Test-Path -LiteralPath $latestRunPath)) {
        throw "No previous audit run was found to resume."
    }
    $relativeOutput = (Get-Content -LiteralPath $latestRunPath -Raw).Trim()
    $outputDirectory = Join-Path $projectRoot ($relativeOutput -replace "/", "\")
    $statePath = Join-Path $outputDirectory "run_state.json"
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $Workers = [int]$state.workers
    $Level = [int]$state.level
    $Iterations = [int]$state.iterations
    $MaxTotalReportMB = [int]$state.max_total_report_mb
    $MaxTotalOutlierMB = [int]$state.max_total_outlier_mb
    $OutliersOnly = [bool]$state.outliers_only
} else {
    if ($Workers -le 0) {
        $Workers = [Math]::Max(1, [Math]::Floor($logicalCores * 0.75))
    }
    $Workers = [Math]::Max(1, [Math]::Min($Workers, $logicalCores))
    $Level = [Math]::Max(1, [Math]::Min($Level, 20))
    $Iterations = [Math]::Max(1, $Iterations)
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $relativeOutput = "balance_reports/item_combinations_overnight/$stamp"
    $outputDirectory = Join-Path $projectRoot ($relativeOutput -replace "/", "\")
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $auditRoot -Force | Out-Null
    if (-not $DryRun) {
        Set-Content -LiteralPath $latestRunPath -Value $relativeOutput
    }
}

$reportMBPerWorker = 0
if ($MaxTotalReportMB -gt 0) {
    $reportMBPerWorker = [Math]::Max(1, [Math]::Floor($MaxTotalReportMB / $Workers))
}
$outlierMBPerWorker = 0
if ($MaxTotalOutlierMB -gt 0) {
    $outlierMBPerWorker = [Math]::Max(1, [Math]::Floor($MaxTotalOutlierMB / $Workers))
}

Write-Host "Tower item audit"
Write-Host "  CPU workers: $Workers of $logicalCores logical cores"
Write-Host "  Tower level: $Level"
Write-Host "  Output folder: $outputDirectory"
Write-Host "  Mode: $(if ($Resume) { 'resume' } else { 'new run' })"
if ($OutliersOnly) {
    Write-Host "  Detailed rows: disabled (outliers only)"
} elseif ($MaxTotalReportMB -gt 0) {
    Write-Host "  Detailed report limit: about $MaxTotalReportMB MB total"
} else {
    Write-Host "  Detailed report limit: unlimited"
}
if ($MaxTotalOutlierMB -gt 0) {
    Write-Host "  Outlier report limit: about $MaxTotalOutlierMB MB total"
} else {
    Write-Host "  Outlier report limit: unlimited"
}

$processes = @()
for ($shardIndex = 0; $shardIndex -lt $Workers; $shardIndex++) {
    $suffix = $shardIndex.ToString("D2")
    $arguments = @(
        "--headless",
        "--path", $projectRoot,
        "--log-file", (Join-Path $outputDirectory "worker_$suffix.log"),
        "--scene", "res://tools/tower_item_combination_audit.tscn",
        "--",
        "--levels=$Level",
        "--iterations=$Iterations",
        "--shard-index=$shardIndex",
        "--shard-count=$Workers",
        "--report-path=res://$relativeOutput/results_$suffix.csv",
        "--outlier-path=res://$relativeOutput/outliers_$suffix.csv",
        "--checkpoint-path=res://$relativeOutput/checkpoint_$suffix.json",
        "--enemy-round=$Level"
    )
    if ($Resume) {
        $arguments += "--resume"
    }
    if ($OutliersOnly) {
        $arguments += "--outliers-only"
    } elseif ($reportMBPerWorker -gt 0) {
        $arguments += "--max-report-mb=$reportMBPerWorker"
    }
    if ($outlierMBPerWorker -gt 0) {
        $arguments += "--max-outlier-mb=$outlierMBPerWorker"
    }
    if ($DryRun) {
        Write-Host "  Would start shard $($shardIndex + 1)/$Workers"
        continue
    }
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
    try { $process.PriorityClass = "BelowNormal" } catch { }
    $processes += $process
}

if ($DryRun) {
    Write-Host "Dry run complete; no audit processes were started."
    exit 0
}

$runState = [ordered]@{
    status = "running"
    workers = $Workers
    level = $Level
    iterations = $Iterations
    max_total_report_mb = $MaxTotalReportMB
    max_total_outlier_mb = $MaxTotalOutlierMB
    outliers_only = [bool]$OutliersOnly
    relative_output = $relativeOutput
    process_ids = @($processes | ForEach-Object { $_.Id })
    started_at = (Get-Date).ToString("o")
}
$statePath = Join-Path $outputDirectory "run_state.json"
$runState | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath

Write-Host "Audit started. Leave this window open overnight. To stop safely from another PowerShell window, run this launcher with -Stop; later use -Resume."
while (($processes | Where-Object { -not $_.HasExited }).Count -gt 0) {
    $complete = ($processes | Where-Object { $_.HasExited }).Count
    Write-Progress -Activity "Tower item audit" -Status "$complete of $Workers workers finished" -PercentComplete (($complete / $Workers) * 100)
    Start-Sleep -Seconds 10
    foreach ($process in $processes) { $process.Refresh() }
}
Write-Progress -Activity "Tower item audit" -Completed

$failed = @($processes | Where-Object { $_.ExitCode -ne 0 })
if ($failed.Count -gt 0) {
	$runState.status = "failed"
	$runState | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath
    Write-Warning "$($failed.Count) worker(s) failed. Check their worker log files in $outputDirectory"
    exit 1
}
$runState.status = "complete"
$runState | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath
Write-Host "Audit complete. Results are in: $outputDirectory"
