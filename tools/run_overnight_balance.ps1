param(
    [ValidateSet("smoke", "standard", "overnight")]
    [string]$Preset = "overnight",
    [string]$GodotPath = "",
    [switch]$Fresh
)

$projectPath = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $desktopPath = Split-Path -Parent $projectPath
    $GodotPath = Join-Path $desktopPath "Godot_v4.7.1-stable_win64.exe"
}

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot was not found at '$GodotPath'. Pass its location with -GodotPath."
}

$reportPath = Join-Path $projectPath "balance_reports\overnight"
New-Item -ItemType Directory -Force -Path $reportPath | Out-Null
$logPath = Join-Path $reportPath "optimizer.log"

$godotArguments = @(
    "--headless",
    "--path", $projectPath,
    "--log-file", $logPath,
    "res://tools/run_balance_optimizer.tscn",
    "--",
    "--preset=$Preset",
    "--output-dir=res://balance_reports/overnight"
)

if ($Fresh) {
    $godotArguments += "--fresh"
}

Write-Host "Starting the $Preset balance run."
Write-Host "Reports: $reportPath"
Write-Host "Progress log: $logPath"
Write-Host "Leave this window open until the run finishes."
if (-not $Fresh) {
    Write-Host "A matching interrupted run will resume automatically."
}

$process = Start-Process `
    -FilePath $GodotPath `
    -ArgumentList $godotArguments `
    -WorkingDirectory $projectPath `
    -WindowStyle Hidden `
    -PassThru

Write-Host "Optimizer process ID: $($process.Id)"
$process.WaitForExit()

if ($process.ExitCode -ne 0) {
    throw "The optimizer stopped with exit code $($process.ExitCode). Check '$logPath'."
}

Write-Host "Balance run complete. Open '$reportPath\summary.txt' for the main findings."
