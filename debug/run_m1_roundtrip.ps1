param(
    [string]$GodotPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Godot_v4.7.2-stable_win64_console.exe')
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$appDataRoot = Join-Path $root '.m1_test_userdata'
$env:APPDATA = Join-Path $appDataRoot 'Roaming'
$env:LOCALAPPDATA = Join-Path $appDataRoot 'Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot executable not found: $GodotPath" }
& $GodotPath --headless --path $root --script 'res://debug/m1_roundtrip_test.gd' -- save
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $GodotPath --headless --path $root --script 'res://debug/m1_roundtrip_test.gd' -- load
exit $LASTEXITCODE