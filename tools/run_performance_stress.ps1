param(
    [string]$GodotPath = "",
    [double]$StageDuration = 8,
    [string]$EnemyStages = "1,30,60,90",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $desktopGodot = Join-Path (Split-Path -Parent $projectRoot) "Godot_v4.7.1-stable_win64.exe"
    if (Test-Path -LiteralPath $desktopGodot) {
        $GodotPath = $desktopGodot
    } else {
        $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
        if ($null -eq $godotCommand) {
            throw "Godot was not found. Pass -GodotPath with the full path to the Godot executable."
        }
        $GodotPath = $godotCommand.Source
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputPath = Join-Path $projectRoot "balance_reports\performance_stress_$timestamp.csv"
} elseif (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = [IO.Path]::GetFullPath((Join-Path $projectRoot $OutputPath))
}

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$arguments = @(
    "--headless",
    "--path", $projectRoot,
    "--quit-after", "36000",
    "res://tools/smoke_test_runner.tscn",
    "--",
    "--smoke-script=res://tools/performance_stress_test.gd",
    "--duration=$StageDuration",
    "--enemies=$EnemyStages",
    "--output=$OutputPath"
)

Write-Host "Running performance stress test..."
Write-Host "Enemy stages: $EnemyStages; seconds per stage: $StageDuration"
$logPath = Join-Path $outputDirectory "performance_stress_latest.log"
$arguments = @("--log-file", $logPath) + $arguments
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) {
    if (Test-Path -LiteralPath $logPath) {
        Get-Content -LiteralPath $logPath
    }
    throw "Performance stress test failed with exit code $($process.ExitCode)."
}

Write-Host "Report written to: $OutputPath"
Import-Csv -LiteralPath $OutputPath | Format-Table -AutoSize
