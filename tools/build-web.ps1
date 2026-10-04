param([string]$GodotPath = "D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $root "exports/web-project"
$output = Join-Path $root "exports/web"
New-Item -ItemType Directory -Force $stage,$output | Out-Null
# Isolated export source: no editor MCP plugin, no runtime debugging autoload,
# no credentials, tests or private editor data. User's editor stays connected.
foreach($folder in @("scenes","scripts","assets","resources")) {
    $source = Join-Path $root $folder
    if(Test-Path $source){ Copy-Item $source $stage -Recurse -Force }
}
Copy-Item (Join-Path $root "icon.svg") $stage -Force
$config = Get-Content (Join-Path $root "project.godot") -Raw
$config = [regex]::Replace($config, '(?ms)^\[autoload\].*?(?=^\[|\z)', '')
$config = [regex]::Replace($config, '(?ms)^\[editor_plugins\].*?(?=^\[|\z)', '')
# Keep the project's Chinese title unchanged.
[IO.File]::WriteAllText((Join-Path $stage "project.godot"),$config,[Text.UTF8Encoding]::new($false))
$preset = Get-Content (Join-Path $root "export_presets.cfg") -Raw
$preset = $preset.Replace('export_filter="scenes"','export_filter="all_resources"')
[IO.File]::WriteAllText((Join-Path $stage "export_presets.cfg"),$preset,[Text.UTF8Encoding]::new($false))
& $GodotPath --headless --path $stage --export-release Web (Join-Path $output "index.html")
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
# Distribute the font and asset licenses alongside the playable build.
Copy-Item (Join-Path $root "assets/licenses") $output -Recurse -Force
Copy-Item (Join-Path $root "docs/素材来源与许可.md") (Join-Path $output "素材来源与许可.txt") -Force
Push-Location $root
try {
    Get-Content -Raw tools/localize_web.py | py -3.11 -
    if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
    Get-Content -Raw tools/compress_web.py | py -3.11 -
    if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
} finally { Pop-Location }
Get-ChildItem $output -File | Select-Object Name,Length | Format-Table
