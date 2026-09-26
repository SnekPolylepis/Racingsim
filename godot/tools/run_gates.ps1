# Parallel gate runner for the Racing Sim rebuild (REBUILD-PLAN.md section 9).
#
# Runs the suites in tools/gates.json in parallel Godot processes, each with a timeout (a timeout is a
# failure), and prints a one-screen summary. Exit code 0 only if every selected gate passed.
#
#   tools/run_gates.ps1              suites affected by this branch's changes (vs origin/main) and uncommitted work
#   tools/run_gates.ps1 -All         every gate: required before merging to main
#   tools/run_gates.ps1 -Perf        also re-run the timing suites alone with their µs budgets gating
#   tools/run_gates.ps1 -Features    also the windowed feature suite (needs a real window)
#   tools/run_gates.ps1 -Only road_tool,walls    just those (name prefixes)
#
# Parallel runs share the CPU, so they set RACINGSIM_PERF_GATES=0: timing budgets print but don't gate.
# -Perf gates them in a serial pass afterwards. Run from anywhere; Godot is taken from godot/tools/Godot.exe,
# else $env:RACINGSIM_GODOT, else the main checkout next to this repo.
param(
    [switch]$All,
    [switch]$Perf,
    [switch]$Features,
    [string[]]$Only = @(),
    [int]$Jobs = 16,
    [int]$Timeout = 600,
    [string]$Godot = "",
    [string]$Base = "origin/main"
)
$ErrorActionPreference = "Stop"
$godotDir = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $godotDir -Parent
$manifest = Get-Content (Join-Path $PSScriptRoot "gates.json") -Raw | ConvertFrom-Json

if (-not $Godot) {
    foreach ($candidate in @((Join-Path $godotDir "tools\Godot.exe"), $env:RACINGSIM_GODOT, (Join-Path (Split-Path $repo -Parent) "RacingSim\godot\tools\Godot.exe"))) {
        if ($candidate -and (Test-Path $candidate)) { $Godot = $candidate; break }
    }
}
if (-not $Godot -or -not (Test-Path $Godot)) { Write-Host "Godot.exe not found (copy it to godot/tools/ or set RACINGSIM_GODOT)"; exit 2 }

# Changed files (relative to godot/) since the merge base with $Base, plus uncommitted and untracked work.
function Get-Changed {
    $files = @()
    $mb = (git -C $repo merge-base HEAD $Base 2>$null)
    if ($mb) { $files += (git -C $repo diff --name-only $mb HEAD) }
    $files += (git -C $repo diff --name-only HEAD)
    $files += (git -C $repo ls-files --others --exclude-standard)
    $files | Where-Object { $_ } | ForEach-Object { $_ -replace '^godot/', '' } | Sort-Object -Unique
}

function Get-Deps($suite) {
    $deps = @()
    $except = @()
    foreach ($g in $suite.groups) {
        $deps += $manifest.groups.$g
        if ($g -eq "legacy") { $except += $manifest.groups.legacy_except }
    }
    if ($suite.deps) { $deps += $suite.deps }
    if ($suite.script) { $deps += $suite.script }
    return @{ deps = $deps; except = $except }
}

function Test-Affected($suite, $changed) {
    $d = Get-Deps $suite
    foreach ($f in $changed) {
        $hit = $false
        foreach ($p in $d.deps) { if ($f.StartsWith($p)) { $hit = $true; break } }
        if (-not $hit) { continue }
        $excluded = $false
        foreach ($p in $d.except) { if ($f.StartsWith($p)) { $excluded = $true; break } }
        if (-not $excluded) { return $true }
    }
    return $false
}

$changed = @(Get-Changed)
$selected = @()
$skipped = @()
foreach ($s in $manifest.suites) {
    if ($s.script -and -not (Test-Path (Join-Path $godotDir $s.script))) { continue }  # not in this tree yet
    $isFeatures = ($s.kind -eq "features")
    if ($Only.Count -gt 0) {
        $match = $false
        foreach ($o in $Only) { if ($s.name.StartsWith($o)) { $match = $true } }
        if ($match) { $selected += $s }
        continue
    }
    if ($isFeatures -and -not $Features) {
        if (Test-Affected $s $changed) { $skipped += "features (affected: run with -Features before merging)" }
        continue
    }
    if ($All -or (Test-Affected $s $changed)) { $selected += $s } else { $skipped += $s.name }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logs = Join-Path $godotDir "tests\logs\gates\$stamp"
New-Item -ItemType Directory -Force $logs | Out-Null

if (-not (Test-Path (Join-Path $godotDir ".godot"))) {
    Write-Host "Importing (no .godot cache)..."
    $p = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$godotDir`"", "--import") -NoNewWindow -PassThru -RedirectStandardOutput "$logs\import.out" -RedirectStandardError "$logs\import.err"
    $null = $p.Handle
    if (-not $p.WaitForExit(300000)) { $p.Kill(); Write-Host "import timed out"; exit 2 }
}

. (Join-Path $PSScriptRoot "window_placement.ps1")

function Start-Suite($s, $tag, $perfGates) {
    $safe = ($s.name -replace '[^A-Za-z0-9_-]', '_')
    $out = "$logs\$safe$tag.out"
    $err = "$logs\$safe$tag.err"
    $args = @()
    if (-not $s.window) { $args += "--headless" } else { $args += (Get-TestWindowArgs) }
    $args += @("--path", "`"$godotDir`"")
    if ($s.kind -eq "parse") { $args += @("--script", $s.script, "--check-only") }
    elseif ($s.kind -eq "features") { $args += @("--", "--features", "--mute-audio") }
    else {
        $args += @("--script", $s.script)
        $extra = $s.args
        if ($perfGates -and $s.perf_args) { $extra = $s.perf_args }
        if ($extra) { $args += "--"; $args += $extra }
    }
    $env:RACINGSIM_PERF_GATES = $(if ($perfGates) { "1" } else { "0" })
    $p = Start-Process -FilePath $Godot -ArgumentList $args -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    $null = $p.Handle
    return @{ suite = $s; proc = $p; out = $out; err = $err; start = Get-Date; timedOut = $false }
}

function Wait-All($running, $limit) {
    # Start queued runs up to $limit at a time; returns finished runs.
    $done = @()
    while ($running.queue.Count -gt 0 -or $running.active.Count -gt 0) {
        while ($running.queue.Count -gt 0 -and $running.active.Count -lt $limit) {
            $next = $running.queue[0]
            $running.queue = @($running.queue | Select-Object -Skip 1)
            $running.active += (Start-Suite $next.suite $next.tag $next.perf)
        }
        Start-Sleep -Milliseconds 250
        $still = @()
        foreach ($r in $running.active) {
            if ($r.proc.HasExited) { $done += $r; continue }
            if (((Get-Date) - $r.start).TotalSeconds -gt $Timeout) {
                try { $r.proc.Kill() } catch {}
                $r.timedOut = $true
                $done += $r
                continue
            }
            $still += $r
        }
        $running.active = $still
    }
    return $done
}

function Evaluate($r) {
    $s = $r.suite
    $secs = [math]::Round(((Get-Date) - $r.start).TotalSeconds, 0)
    if ($r.timedOut) { return @{ name = $s.name; ok = $false; secs = $Timeout; note = "TIMEOUT after $Timeout s" } }
    $r.proc.WaitForExit()
    $secs = [math]::Round(($r.proc.ExitTime - $r.start).TotalSeconds, 0)
    $code = $r.proc.ExitCode
    $errText = ""
    if (Test-Path $r.err) { $errText = (Get-Content $r.err -Raw -Encoding UTF8) }
    $stderrOk = [string]::IsNullOrWhiteSpace($errText)
    $out = ""
    if (Test-Path $r.out) { $out = (Get-Content $r.out -Raw -Encoding UTF8) }
    if ($s.kind -eq "legacy") {
        $want = (Get-Content (Join-Path $godotDir "docs\rebuild\baseline\$($s.baseline)") -Raw -Encoding UTF8) -replace "`r`n", "`n"
        $same = (($out -replace "`r`n", "`n") -eq $want)
        $wantExit = 0
        if ($null -ne $s.exit) { $wantExit = [int]$s.exit }
        $ok = $same -and $stderrOk -and ($code -eq $wantExit)
        $note = $(if ($same) { "identical to baseline" } else { "DIFFERS from baseline" })
        if ($code -ne $wantExit) { $note += ", exit $code (want $wantExit)" }
        if (-not $stderrOk) { $note += ", stderr not empty" }
        return @{ name = $s.name; ok = $ok; secs = $secs; note = $note }
    }
    if ($s.kind -eq "parse") {
        $ok = ($code -eq 0) -and $stderrOk
        return @{ name = $s.name; ok = $ok; secs = $secs; note = $(if ($ok) { "clean" } else { "exit $code, see $($r.err)" }) }
    }
    # v2 suites and features: the last 'RESULTS {json}' line.
    $line = ($out -split "`n" | Where-Object { $_ -match ' RESULTS \{' } | Select-Object -Last 1)
    if (-not $line) {
        return @{ name = $s.name; ok = $false; secs = $secs; note = "no RESULTS line (exit $code); see $($r.out)" }
    }
    $json = $line.Substring($line.IndexOf("{")) | ConvertFrom-Json
    $fails = @($json.failures)
    $checks = $json.checks
    $ok = ($code -eq 0) -and $stderrOk -and ($fails.Count -eq 0)
    $note = "$checks checks, $($fails.Count) failures"
    if (-not $stderrOk) { $note += ", stderr not empty ($($r.err))" }
    if ($fails.Count -gt 0) { $note += ": " + (($fails | Select-Object -First 2) -join " | ") }
    return @{ name = $s.name; ok = $ok; secs = $secs; note = $note }
}

$t0 = Get-Date
Write-Host ("Gates: {0} selected, {1} skipped as unaffected. Logs: {2}" -f $selected.Count, $skipped.Count, $logs)
$state = @{ queue = @(); active = @() }
foreach ($s in $selected) { $state.queue += @{ suite = $s; tag = ""; perf = $false } }
$results = @(Wait-All $state $Jobs | ForEach-Object { Evaluate $_ })

if ($Perf) {
    $perfSuites = @($selected | Where-Object { $_.perf })
    if ($perfSuites.Count -gt 0) { Write-Host ("Perf pass: {0} timing suites, one at a time" -f $perfSuites.Count) }
    foreach ($s in $perfSuites) {
        $state = @{ queue = @(@{ suite = $s; tag = ".perf"; perf = $true }); active = @() }
        $r = @(Wait-All $state 1)[0]
        $e = Evaluate $r
        $e.name = "$($s.name) [perf]"
        $results += $e
    }
}
Remove-Item Env:RACINGSIM_PERF_GATES -ErrorAction SilentlyContinue

$failed = @($results | Where-Object { -not $_.ok })
foreach ($e in ($results | Sort-Object { -not $_.ok }, name)) {
    $mark = $(if ($e.ok) { "PASS" } else { "FAIL" })
    Write-Host ("{0}  {1,-36} {2,4}s  {3}" -f $mark, $e.name, $e.secs, $e.note)
}
foreach ($k in $skipped) { Write-Host ("skip  {0}" -f $k) }
$wall = [math]::Round(((Get-Date) - $t0).TotalSeconds, 0)
Write-Host ("{0}: {1} gates, {2} failed, {3} s wall clock" -f $(if ($failed.Count -eq 0) { "ALL PASS" } else { "FAILED" }), $results.Count, $failed.Count, $wall)
if ($failed.Count -gt 0) { exit 1 }
exit 0
