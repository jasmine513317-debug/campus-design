param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
$projectPath = Split-Path -Parent $PSScriptRoot
$checks = @(
    @("--headless", "--path", $projectPath, "--editor", "--import"),
    @("--headless", "--path", $projectPath, "--script", "res://dev/test_art.gd"),
    @("--headless", "--path", $projectPath, "res://dev/test_game.tscn"),
    @("--headless", "--path", $projectPath, "--script", "res://dev/test_world_safety.gd"),
    @("--headless", "--path", $projectPath, "--script", "res://dev/test_interior_safety.gd"),
    @("--headless", "--path", $projectPath, "--script", "res://dev/test_interior_transition.gd")
)
foreach ($arguments in $checks) {
    $output = & $Godot @arguments 2>&1
    $result = $LASTEXITCODE
    $output | Write-Output
    if ($result -ne 0 -or ($output -match "SCRIPT ERROR:|^ERROR:").Count -gt 0) {
        throw "Campus Hollow verification failed: $($arguments -join ' ')"
    }
}
Write-Output "Campus Hollow: all verification checks passed."
