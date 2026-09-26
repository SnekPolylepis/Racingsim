# Visual review of track graphics (tests/visual/track_review.gd), separate from the physics gates.
# Each run lands in godot/visual-review/<yyyyMMdd-HHmm>[-label]/ and is diffed against the previous run
# unless -Baseline names another run folder (or -NoBaseline). Windowed: needs a real display.
#   powershell -ExecutionPolicy Bypass -File tools/visual_review.ps1 [-Tracks spa,nordschleife] [-Label look-13]
#       [-Baseline 20260925-1400] [-NoBaseline] [-Night] [-Bonnet]
param(
    [string]$Tracks = "",
    [string]$Label = "",
    [string]$Baseline = "",
    [switch]$NoBaseline,
    [switch]$Night,
    [switch]$Bonnet
)
$ErrorActionPreference = "Stop"
$godotDir = Split-Path -Parent $PSScriptRoot
$runs = Join-Path $godotDir "visual-review"
New-Item -ItemType Directory -Force $runs | Out-Null
# Keep Godot from importing (and the export from packing) review screenshots.
New-Item -ItemType File -Force (Join-Path $runs ".gdignore") | Out-Null

$name = Get-Date -Format "yyyyMMdd-HHmm"
if ($Label) { $name = "$name-$Label" }
$out = Join-Path $runs $name

$base = ""
if (-not $NoBaseline) {
    if ($Baseline) {
        $base = Join-Path $runs $Baseline
    } else {
        $prev = Get-ChildItem $runs -Directory | Where-Object { $_.Name -ne $name -and (Test-Path (Join-Path $_.FullName "manifest.json")) } |
            Sort-Object Name | Select-Object -Last 1
        if ($prev) { $base = $prev.FullName }
    }
}

. (Join-Path $PSScriptRoot "window_placement.ps1")
$argsList = @(Get-TestWindowArgs) + @("--path", $godotDir, "--script", "tests/visual/track_review.gd", "--", "--v2-flow-test", "--out=$($out -replace '\\','/')")
if ($Tracks) { $argsList += "--tracks=$Tracks" }
if ($base) { $argsList += "--baseline=$($base -replace '\\','/')" }
if ($Night) { $argsList += "--night" }
if ($Bonnet) { $argsList += "--bonnet" }

Write-Host "Visual review -> $out"
if ($base) { Write-Host "Baseline      -> $base" }
$ErrorActionPreference = "Continue"
& (Join-Path $godotDir "tools/Godot.exe") @argsList 2>&1 | Where-Object { $_ -match "VISUAL (SHOT|REVIEW)" } | ForEach-Object { Write-Host $_ }

$manifest = Join-Path $out "manifest.json"
if (-not (Test-Path $manifest)) { Write-Host "VISUAL REVIEW FAILED: no manifest"; exit 1 }
$m = Get-Content $manifest -Raw | ConvertFrom-Json
foreach ($t in $m.tracks.PSObject.Properties) {
    $shots = $t.Value.shots
    $changed = @($shots | Where-Object { $_.changed })
    Write-Host ("{0}: {1} shots, {2} changed vs baseline, mean draw calls {3}" -f $t.Name, $shots.Count, $changed.Count, $t.Value.mean_draws)
    foreach ($s in ($changed | Sort-Object score -Descending)) { Write-Host ("    {0,6}  {1}" -f $s.score, $s.file) }
}
Write-Host "Contact sheets: $out\<track>-sheet.png"
