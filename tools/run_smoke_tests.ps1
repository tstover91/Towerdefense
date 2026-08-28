param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,
    [int]$TimeoutSeconds = 20
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$smokeScenes = Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*_smoke.tscn" |
    Sort-Object Name
$failedScenes = [System.Collections.Generic.List[string]]::new()

foreach ($scene in $smokeScenes) {
    $relativeScene = "res://tools/$($scene.Name)"
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GodotPath
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.Arguments = "--headless --path `"$projectRoot`" `"$relativeScene`""

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
        $process.Kill()
        $process.WaitForExit()
    }

    $stdout = $stdoutTask.Result.Trim()
    $stderr = $stderrTask.Result.Trim()
    $combinedOutput = "$stdout`n$stderr"
    $passed = (
        $completed -and
        $process.ExitCode -eq 0 -and
        $combinedOutput -notmatch "SCRIPT ERROR|ERROR:"
    )
    if ($passed) {
        Write-Host "PASS  $($scene.Name)" -ForegroundColor Green
        continue
    }

    $failedScenes.Add($scene.Name)
    $result = if ($completed) { "FAIL" } else { "TIMEOUT" }
    Write-Host "$result  $($scene.Name)" -ForegroundColor Red
    if ($stdout) {
        Write-Host $stdout
    }
    if ($stderr) {
        Write-Host $stderr
    }
}

if ($failedScenes.Count -gt 0) {
    Write-Error "$($failedScenes.Count) smoke test(s) failed: $($failedScenes -join ', ')"
    exit 1
}

Write-Host "All $($smokeScenes.Count) smoke tests passed." -ForegroundColor Green
exit 0
