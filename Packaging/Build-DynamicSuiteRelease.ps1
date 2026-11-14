<#
.SYNOPSIS
    DynamicSuite CurseForge release packager (bundle + 8 standalone module zips).

.DESCRIPTION
    Builds CurseForge-ready zips from the single master workspace:
      * DynamicSuite-v<ver>.zip          -> DynamicSuite/ (hub + all 8 modules)
      * Dynamic<Module>-v<ver>.zip (x8)  -> Dynamic<Module>/ (standalone TOC + module + assets)

    Pre-flight gates (any failure aborts unless -Force):
      1. Lockstep version: DynamicSuite.toc and all 8 Packaging\StandaloneTOCs\*.toc share
         the same ## Version and ## Interface.
      2. CHANGELOG.md headline mentions v<ver>.
      3. Pure ASCII + no BOM across all .lua / .toc / .md that ship.
      4. Lua 5.1 syntax check (luac5.1 -p) on every shipped .lua.
      5. Every file listed in each staged .toc exists inside its staged folder.

    Output: D:\DriveSync\Releases\DynamicSuite\v<ver>\ (outside the mirrored master root, so
    Push-DynamicSuiteSync never mirrors release zips into Google Drive).
    Also writes SHA256SUMS.txt and RELEASE_NOTES_v<ver>.md (current CHANGELOG section).

    Zips are written with forward-slash entry names (PowerShell 5.1 Compress-Archive writes
    backslashes, which break the CurseForge / WowUp / CurseForge-app extractors).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File Build-DynamicSuiteRelease.ps1
.EXAMPLE
    ... -Only DynamicMarker,DynamicBags -NoBundle
.EXAMPLE
    ... -StageStandalone DynamicMarker
#>
[CmdletBinding()]
param(
    [string]   $MasterRoot      = '',
    [string]   $OutRoot         = 'D:\DriveSync\Releases\DynamicSuite',
    [string]   $LuacPath        = '',
    [string[]] $Only            = @(),
    [Alias('StageStandaloneToWoW')]
    [string[]] $StageStandalone = @(),
    [string]   $WoWAddOnsRoot   = 'C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns',
    [switch]   $NoBundle,
    [switch]   $NoStandalone,
    [switch]   $SkipLuac,
    [switch]   $Force
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# PowerShell 5.1 does not populate $PSScriptRoot inside param() defaults, so resolve here.
if (-not $MasterRoot) {
    $here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $MasterRoot = Split-Path -Parent $here
}
$MasterRoot = (Resolve-Path -LiteralPath $MasterRoot).Path.TrimEnd('\')

$AddonSrc   = Join-Path $MasterRoot 'DynamicSuite'
$TocTplDir  = Join-Path $MasterRoot 'Packaging\StandaloneTOCs'
$Changelog  = Join-Path $MasterRoot 'CHANGELOG.md'
$Modules    = @('DynamicLoad','DynamicPrep','DynamicMarker','DynamicZoom','DynamicFPS','DynamicGroup','DynamicBags','DynamicChat')
$ExcludeRx  = '(\.bak|\.tmp|\.orig|\.rej|Thumbs\.db|\.DS_Store|desktop\.ini)$'

$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
function Fail([string]$m) { $script:Failures.Add($m); Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Warn([string]$m) { $script:Warnings.Add($m); Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Ok([string]$m)   { Write-Host "  [ OK ] $m" -ForegroundColor Green }
function Step([string]$m) { Write-Host ""; Write-Host "== $m" -ForegroundColor Cyan }

function Get-TocField([string]$path, [string]$field) {
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        if ($line -match "^##\s*$([regex]::Escape($field))\s*:\s*(.+?)\s*$") { return $Matches[1] }
    }
    return $null
}
function Get-TocFiles([string]$path) {
    [IO.File]::ReadAllLines($path) | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
}
function Test-AsciiFile([string]$path) {
    $b = [IO.File]::ReadAllBytes($path)
    $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
    $n = 0; foreach ($x in $b) { if ($x -gt 127) { $n++ } }
    return @{ NonAscii = $n; Bom = $bom }
}
function Find-Luac {
    if ($LuacPath -and (Test-Path -LiteralPath $LuacPath)) { return $LuacPath }
    if ($env:DS_LUAC -and (Test-Path -LiteralPath $env:DS_LUAC)) { return $env:DS_LUAC }
    foreach ($n in 'luac5.1','luac51','luac') {
        $c = Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { return $c.Source }
    }
    foreach ($p in @('D:\DriveSync\Tools\lua51\luac5.1.exe', (Join-Path $MasterRoot '..\Tools\lua51\luac5.1.exe'))) {
        if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
    }
    return $null
}
function New-ForwardSlashZip([string]$stageRoot, [string]$folderName, [string]$zipPath) {
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    $src = Join-Path $stageRoot $folderName
    $fs = [IO.File]::Open($zipPath, [IO.FileMode]::CreateNew)
    try {
        $zip = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
        try {
            $files = Get-ChildItem -LiteralPath $src -Recurse -File | Sort-Object FullName
            foreach ($f in $files) {
                $rel = $f.FullName.Substring($stageRoot.TrimEnd('\').Length + 1).Replace('\','/')
                $entry = $zip.CreateEntry($rel, [IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = [DateTimeOffset]$f.LastWriteTime
                $es = $entry.Open()
                try { $in = [IO.File]::OpenRead($f.FullName); try { $in.CopyTo($es) } finally { $in.Dispose() } }
                finally { $es.Dispose() }
            }
        } finally { $zip.Dispose() }
    } finally { $fs.Dispose() }
}
function Copy-Into([string]$src, [string]$dstDir, [string]$rel) {
    $dst = Join-Path $dstDir $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

# ---------------------------------------------------------------------------
Write-Host "DynamicSuite Release Packager" -ForegroundColor White
Write-Host "Master: $MasterRoot"
if (-not (Test-Path -LiteralPath (Join-Path $AddonSrc 'DynamicSuite.toc'))) { throw "DynamicSuite.toc not found under $AddonSrc" }

$targets = if ($Only.Count -gt 0) { $Modules | Where-Object { $Only -contains $_ } } else { $Modules }
foreach ($o in $Only) { if ($Modules -notcontains $o) { throw "Unknown module in -Only: $o" } }

$stageSet = @()
if ($StageStandalone.Count -gt 0) {
    if ($NoStandalone) { throw "Cannot combine -StageStandalone with -NoStandalone" }
    $normalizedStage = @($StageStandalone | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    foreach ($s in $normalizedStage) {
        if ($s -eq '*' -or $s -ieq 'All') {
            $stageSet = @($targets)
            break
        }
        if ($Modules -notcontains $s) { throw "Unknown module in -StageStandalone: $s" }
        if ($targets -notcontains $s) { throw "-StageStandalone module '$s' is excluded by -Only" }
        if ($stageSet -notcontains $s) { $stageSet += $s }
    }
}

# 1. Lockstep version ------------------------------------------------------------------
Step "1. Lockstep version check"
$hubToc  = Join-Path $AddonSrc 'DynamicSuite.toc'
$Version = Get-TocField $hubToc 'Version'
$Iface   = Get-TocField $hubToc 'Interface'
if (-not $Version) { throw "No ## Version in DynamicSuite.toc" }
Ok "DynamicSuite.toc  Version $Version  Interface $Iface"
foreach ($m in $Modules) {
    $t = Join-Path $TocTplDir "$m.toc"
    if (-not (Test-Path -LiteralPath $t)) { Fail "$m.toc template missing"; continue }
    $v = Get-TocField $t 'Version'; $i = Get-TocField $t 'Interface'
    if ($v -ne $Version) { Fail "$m.toc Version '$v' != '$Version'" }
    elseif ($i -ne $Iface) { Fail "$m.toc Interface '$i' != '$Iface'" }
    else { Ok "$m.toc" }
    $icon = Get-TocField $t 'IconTexture'
    if ($icon -and $icon -notmatch "AddOns\\$m\\") { Fail "$m.toc IconTexture points outside its own folder: $icon" }
}

# 2. Changelog --------------------------------------------------------------------------
Step "2. Changelog check"
$notes = $null
if (Test-Path -LiteralPath $Changelog) {
    $cl = [IO.File]::ReadAllText($Changelog)
    $head = ($cl -split "`n" | Select-Object -First 8) -join "`n"
    if ($head -match [regex]::Escape("v$Version")) { Ok "CHANGELOG.md headline is v$Version" } else { Fail "CHANGELOG.md headline does not mention v$Version" }
    $sec = [regex]::Match($cl, "(?ms)^## [^\r\n]*v$([regex]::Escape($Version))\b.*?(?=^---\s*$|\z)")
    if ($sec.Success) { $notes = $sec.Value.Trim() } else { Warn "No '## ... v$Version' section found for release notes" }
} else { Fail "CHANGELOG.md not found" }

# 3. ASCII / BOM ------------------------------------------------------------------------
Step "3. ASCII / BOM check"
$shipText = @(Get-ChildItem -LiteralPath $AddonSrc -Recurse -File | Where-Object { $_.Extension -match '^\.(lua|toc|md)$' }) + @(Get-ChildItem -LiteralPath $TocTplDir -File -Filter *.toc)
$asciiBad = 0
foreach ($f in $shipText) {
    $r = Test-AsciiFile $f.FullName
    if ($r.NonAscii -gt 0 -or $r.Bom) { $asciiBad++; Fail ("{0}: NonASCII={1} BOM={2}" -f $f.FullName.Substring($MasterRoot.Length + 1), $r.NonAscii, $r.Bom) }
}
if ($asciiBad -eq 0) { Ok "$($shipText.Count) files pure ASCII, no BOM" }

# 4. Lua 5.1 syntax ---------------------------------------------------------------------
Step "4. Lua 5.1 syntax check"
$luaFiles = Get-ChildItem -LiteralPath $AddonSrc -Recurse -File -Filter *.lua
if ($SkipLuac) { Warn "Skipped (-SkipLuac)" }
else {
    $luac = Find-Luac
    if (-not $luac) { Fail "luac5.1 not found (use -LuacPath, `$env:DS_LUAC, PATH, or D:\DriveSync\Tools\lua51\luac5.1.exe)" }
    else {
        Write-Host "  luac: $luac"
        foreach ($f in $luaFiles) {
            $out = & $luac -p $f.FullName 2>&1
            if ($LASTEXITCODE -ne 0) { Fail "$($f.Name): $out" } else { Ok $f.Name }
        }
    }
}

if ($script:Failures.Count -gt 0 -and -not $Force) {
    Write-Host ""; Write-Host "Pre-flight failed ($($script:Failures.Count) issue(s)). Fix them or re-run with -Force." -ForegroundColor Red
    exit 1
}

# 5. Stage + zip ------------------------------------------------------------------------
$OutDir   = Join-Path $OutRoot "v$Version"
$StageDir = Join-Path $OutDir '_stage'
if (Test-Path -LiteralPath $StageDir) { Remove-Item -LiteralPath $StageDir -Recurse -Force }
if (Test-Path -LiteralPath $OutDir) {
    if (-not $NoBundle) {
        Get-ChildItem -LiteralPath $OutDir -File -Filter 'DynamicSuite-*.zip' -ErrorAction SilentlyContinue | Remove-Item -Force
    }
    if (-not $NoStandalone) {
        foreach ($m in $targets) {
            Get-ChildItem -LiteralPath $OutDir -File -Filter "$m-*.zip" -ErrorAction SilentlyContinue | Remove-Item -Force
        }
    }
    Get-ChildItem -LiteralPath $OutDir -File -Filter 'SHA256SUMS.txt' -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -LiteralPath $OutDir -File -Filter 'RELEASE_NOTES_*.md' -ErrorAction SilentlyContinue | Remove-Item -Force
}
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null
$built = New-Object System.Collections.Generic.List[string]

function Test-StagedToc([string]$folder, [string]$tocName) {
    $toc = Join-Path $folder $tocName
    $missing = @(Get-TocFiles $toc | Where-Object { -not (Test-Path -LiteralPath (Join-Path $folder $_)) })
    foreach ($x in $missing) { Fail "$tocName lists missing file: $x" }
    return ($missing.Count -eq 0)
}

if (-not $NoBundle) {
    Step "5a. Bundle: DynamicSuite-v$Version.zip"
    $dst = Join-Path $StageDir 'DynamicSuite'
    Get-ChildItem -LiteralPath $AddonSrc -Recurse -File | Where-Object { $_.Name -notmatch $ExcludeRx } | ForEach-Object {
        Copy-Into $_.FullName $dst $_.FullName.Substring($AddonSrc.Length + 1)
    }
    if (Test-StagedToc $dst 'DynamicSuite.toc') {
        $zip = Join-Path $OutDir "DynamicSuite-v$Version.zip"
        New-ForwardSlashZip $StageDir 'DynamicSuite' $zip
        $built.Add($zip); Ok ("{0} ({1:N0} KB)" -f (Split-Path -Leaf $zip), ((Get-Item $zip).Length / 1KB))
    }
}

if (-not $NoStandalone) {
    Step "5b. Standalone modules"
    $iconDir  = Join-Path $AddonSrc 'Media\Icons'
    $fontsDir = Join-Path $AddonSrc 'Fonts'
    foreach ($m in $targets) {
        $dst = Join-Path $StageDir $m
        $tpl = Join-Path $TocTplDir "$m.toc"
        Copy-Into $tpl $dst "$m.toc"
        foreach ($rel in (Get-TocFiles $tpl)) {
            $cand = @((Join-Path $AddonSrc "Modules\$rel"), (Join-Path $AddonSrc $rel)) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if ($cand) { Copy-Into $cand $dst $rel } else { Fail "$m.toc lists $rel but it is not in DynamicSuite\Modules" }
        }
        # Addon-list icon + full Media\Icons set (modules build some icon paths dynamically).
        $rootIcon = Join-Path $AddonSrc 'icon.tga'
        if (Test-Path -LiteralPath $rootIcon) { Copy-Into $rootIcon $dst 'icon.tga' } else { Warn "${m}: DynamicSuite\icon.tga missing" }
        if (Test-Path -LiteralPath $iconDir) {
            Get-ChildItem -LiteralPath $iconDir -File | Where-Object { $_.Name -notmatch $ExcludeRx } | ForEach-Object { Copy-Into $_.FullName $dst ("Media\Icons\" + $_.Name) }
        }
        # Bundled fonts: only the ones this module's source actually references (game fonts are skipped).
        $modSrc = Join-Path $dst "$m.lua"
        if ((Test-Path -LiteralPath $modSrc) -and (Test-Path -LiteralPath $fontsDir)) {
            $txt = [IO.File]::ReadAllText($modSrc)
            $refs = [regex]::Matches($txt, '\\\\Fonts\\\\([^"\\|]+?\.(?:ttf|otf))', 'IgnoreCase') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
            foreach ($fn in $refs) {
                $fp = Get-ChildItem -LiteralPath $fontsDir -File | Where-Object { $_.Name -ieq $fn } | Select-Object -First 1
                if ($fp) { Copy-Into $fp.FullName $dst ("Fonts\" + $fp.Name) }
            }
        }
        if (Test-Path -LiteralPath (Join-Path $AddonSrc 'CHANGELOG.md')) { Copy-Into (Join-Path $AddonSrc 'CHANGELOG.md') $dst 'CHANGELOG.md' }
        if (Test-StagedToc $dst "$m.toc") {
            $zip = Join-Path $OutDir "$m-v$Version.zip"
            New-ForwardSlashZip $StageDir $m $zip
            $built.Add($zip); Ok ("{0} ({1:N0} KB)" -f (Split-Path -Leaf $zip), ((Get-Item $zip).Length / 1KB))
            if ($stageSet -contains $m) {
                if (-not (Test-Path -LiteralPath $WoWAddOnsRoot)) {
                    Fail "Cannot stage $m to WoW AddOns: folder not found ($WoWAddOnsRoot)"
                } else {
                    $wowModDir = Join-Path $WoWAddOnsRoot $m
                    if (Test-Path -LiteralPath $wowModDir) {
                        $wowItem = Get-Item -LiteralPath $wowModDir -Force
                        if ($wowItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                            cmd /c rmdir "$wowModDir" | Out-Null
                        } else {
                            Remove-Item -LiteralPath $wowModDir -Recurse -Force
                        }
                    }
                    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $WoWAddOnsRoot)
                    if (Test-StagedToc $wowModDir "$m.toc") {
                        Ok "Staged standalone $m -> $wowModDir (WTF untouched)"
                    }
                }
            }
        }
    }
}

# 6. Manifest + notes -------------------------------------------------------------------
Step "6. Manifest"
$sums = foreach ($z in $built) { "{0}  {1}" -f (Get-FileHash -Algorithm SHA256 -LiteralPath $z).Hash.ToLower(), (Split-Path -Leaf $z) }
[IO.File]::WriteAllText((Join-Path $OutDir 'SHA256SUMS.txt'), (($sums -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
Ok "SHA256SUMS.txt ($($built.Count) zips)"
if ($notes) {
    [IO.File]::WriteAllText((Join-Path $OutDir "RELEASE_NOTES_v$Version.md"), ($notes + "`n"), (New-Object Text.UTF8Encoding($false)))
    Ok "RELEASE_NOTES_v$Version.md"
}
Remove-Item -LiteralPath $StageDir -Recurse -Force

Write-Host ""
if ($script:Failures.Count -gt 0) {
    Write-Host "Built with $($script:Failures.Count) failure(s) (-Force). Output: $OutDir" -ForegroundColor Yellow
    exit 2
}
Write-Host "Release v$Version ready: $OutDir  ($($built.Count) zips, $($script:Warnings.Count) warning(s))" -ForegroundColor Green
exit 0
