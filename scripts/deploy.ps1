<#
.SYNOPSIS
    End-to-end validation, deployment, cloud sync, and Git push pipeline for DynamicSuite.

.DESCRIPTION
    1. Resolves luac5.1.exe and git.exe even when missing from the default non-interactive PATH.
    2. Validates all .lua files under DynamicSuite\ with luac5.1 -p.
    3. Verifies strict pure ASCII (no bytes > 127) and no UTF-8 BOM across .lua, .toc, .ps1, and CHANGELOG.md.
    4. Verifies internal planning files (AGENTS.md, DESIGN_SYSTEM.md, TASKS.md, Design/) are ignored and untracked.
    5. Optionally builds and verifies Marketing\DynamicMarker-<Version>.zip (-BuildReleaseZip).
    6. Runs D:\DriveSync\Push-DynamicSuiteSync.cmd (WoW AddOns + Google Drive sync; never touches SavedVariables).
    7. Stages public changes, commits (when dirty), and pushes to origin/main.
#>
[CmdletBinding()]
param(
    [string] $CommitMessage = "",
    [string] $ReleaseTag = "",
    [switch] $BuildReleaseZip,
    [switch] $SkipSync,
    [switch] $SkipGit
)

$ErrorActionPreference = "Stop"

if (-not [string]::IsNullOrWhiteSpace($ReleaseTag) -and $SkipGit) {
    throw "Cannot use -ReleaseTag together with -SkipGit."
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$PushCmd  = "D:\DriveSync\Push-DynamicSuiteSync.cmd"

function Resolve-ToolBinary {
    param(
        [string]   $Name,
        [string[]] $Candidates
    )
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($c in $Candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            return $c
        }
    }
    throw "Required tool '$Name' was not found on PATH or in known locations."
}

# 1. Resolve luac5.1 and git
$luacExe = Resolve-ToolBinary -Name "luac5.1" -Candidates @(
    "D:\DriveSync\Tools\lua51\luac5.1.exe",
    "C:\Tools\lua51\luac5.1.exe",
    "C:\Program Files (x86)\Lua\5.1\luac5.1.exe",
    "C:\Program Files (x86)\Lua\5.1\luac.exe"
)

$gitExe = Resolve-ToolBinary -Name "git" -Candidates @(
    "C:\Program Files\Git\cmd\git.exe",
    "C:\Program Files (x86)\Git\cmd\git.exe",
    "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe",
    "$env:USERPROFILE\scoop\shims\git.exe"
)

$gitDir = Split-Path -Parent $gitExe
if (-not (($env:PATH -split ";") -contains $gitDir)) {
    $env:PATH = "$gitDir;$env:PATH"
}

Write-Host "[TOOL] luac5.1: $luacExe" -ForegroundColor DarkCyan
Write-Host "[TOOL] git:     $gitExe" -ForegroundColor DarkCyan

# 2. Lua 5.1 syntax validation
$luaFiles = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "DynamicSuite") -Filter "*.lua" -Recurse -File
if ($luaFiles.Count -eq 0) {
    throw "No .lua files found under DynamicSuite\."
}

foreach ($f in $luaFiles) {
    & $luacExe -p $f.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "luac5.1 syntax check failed: $($f.FullName)"
    }
}
Write-Host "[LUAC OK] Validated $($luaFiles.Count) Lua file(s)" -ForegroundColor Green

# 3. Mirror CHANGELOG.md and verify Pure ASCII & No-BOM
$changelogPath = Join-Path $RepoRoot "CHANGELOG.md"
$suiteChangelogPath = Join-Path $RepoRoot "DynamicSuite\CHANGELOG.md"
if (Test-Path -LiteralPath $changelogPath) {
    Copy-Item -LiteralPath $changelogPath -Destination $suiteChangelogPath -Force
}

$asciiTargets = @()
$asciiTargets += $luaFiles
$asciiTargets += Get-ChildItem -LiteralPath (Join-Path $RepoRoot "DynamicSuite") -Filter "*.toc" -Recurse -File
if (Test-Path -LiteralPath (Join-Path $RepoRoot "Packaging")) {
    $asciiTargets += Get-ChildItem -LiteralPath (Join-Path $RepoRoot "Packaging") -Filter "*.toc" -Recurse -File
}
foreach ($docName in @("CHANGELOG.md", "DynamicSuite\CHANGELOG.md", "Packaging\StandaloneTOCs\CHANGELOG_DYNAMICMARKER.md", "README.md", "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICMARKER.md", "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICSUITE.md", "Packaging\StandaloneTOCs\.pkgmeta-dynamicmarker", "AGENTS.md", "DESIGN_SYSTEM.md", "TASKS.md", ".pkgmeta", ".pkgmeta-dynamicmarker", ".github\workflows\release.yml")) {
    $docPath = Join-Path $RepoRoot $docName
    if (Test-Path -LiteralPath $docPath) {
        $asciiTargets += Get-Item -LiteralPath $docPath
    }
}
$asciiTargets += Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.ps1" -File
$marketingDir = Join-Path $RepoRoot "Marketing"
if (Test-Path -LiteralPath $marketingDir) {
    $asciiTargets += Get-ChildItem -LiteralPath $marketingDir -Filter "*.md" -File
}
$designHtml = Join-Path $RepoRoot "Design\DynamicSuite_Full_Brand_Showcase.html"
if (Test-Path -LiteralPath $designHtml) {
    $asciiTargets += Get-Item -LiteralPath $designHtml
}
$designLogosDir = Join-Path $RepoRoot "Design\Logos"
if (Test-Path -LiteralPath $designLogosDir) {
    $asciiTargets += Get-ChildItem -LiteralPath $designLogosDir -Filter "*.svg" -File
}

$asciiFailures = @()
foreach ($f in $asciiTargets) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $nonAscii = 0
    foreach ($b in $bytes) {
        if ($b -gt 127) { $nonAscii++ }
    }
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if ($nonAscii -gt 0 -or $hasBom) {
        $asciiFailures += "$($f.FullName) (NonASCII=$nonAscii, HasBOM=$hasBom)"
    }
}
if ($asciiFailures.Count -gt 0) {
    throw ("ASCII/BOM verification failed:`n - " + ($asciiFailures -join "`n - "))
}
Write-Host "[ASCII OK] Verified $($asciiTargets.Count) file(s) (NonASCII=0, HasBOM=False)" -ForegroundColor Green

# 3b. Public doc leak guard & Lockstep Suite <-> Standalone parity checks
$leakPattern = 'AGENTS\.md|DESIGN_SYSTEM\.md|TASKS\.md|Design/|scripts/'
$pubDocs = @("README.md", "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICMARKER.md", "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICSUITE.md", "CHANGELOG.md", "DynamicSuite\CHANGELOG.md")
if (Test-Path -LiteralPath $marketingDir) {
    foreach ($mf in (Get-ChildItem -LiteralPath $marketingDir -Filter "*.md" -File)) {
        $pubDocs += "Marketing\$($mf.Name)"
    }
}
foreach ($pubDoc in $pubDocs) {
    $pubPath = Join-Path $RepoRoot $pubDoc
    if (-not (Test-Path -LiteralPath $pubPath)) {
        throw "Required public document missing: $pubPath"
    }
    $leakMatches = Select-String -Path $pubPath -Pattern $leakPattern
    if ($leakMatches) {
        throw "Internal file reference leaked in public doc $pubDoc (line $($leakMatches[0].LineNumber))"
    }
}

$suiteTocPath = Join-Path $RepoRoot "DynamicSuite\DynamicSuite.toc"
$suiteTocLines = Get-Content -LiteralPath $suiteTocPath
$suiteVerLine = ($suiteTocLines | Where-Object { $_ -match '^##\s*Version:\s*(.+?)\s*$' } | Select-Object -First 1)
$suiteIfaceLine = ($suiteTocLines | Where-Object { $_ -match '^##\s*Interface:\s*(.+?)\s*$' } | Select-Object -First 1)
if (-not ($suiteVerLine -match '^##\s*Version:\s*(.+?)\s*$')) { throw "Missing ## Version in DynamicSuite.toc" }
$suiteVer = $Matches[1].Trim()
if (-not ($suiteIfaceLine -match '^##\s*Interface:\s*(.+?)\s*$')) { throw "Missing ## Interface in DynamicSuite.toc" }
$suiteIface = $Matches[1].Trim()

$standaloneTocs = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "Packaging\StandaloneTOCs") -Filter "*.toc" -File
foreach ($toc in $standaloneTocs) {
    $lines = Get-Content -LiteralPath $toc.FullName
    $vLine = ($lines | Where-Object { $_ -match '^##\s*Version:\s*(.+?)\s*$' } | Select-Object -First 1)
    $iLine = ($lines | Where-Object { $_ -match '^##\s*Interface:\s*(.+?)\s*$' } | Select-Object -First 1)
    if (-not ($vLine -match '^##\s*Version:\s*(.+?)\s*$') -or $Matches[1].Trim() -ne $suiteVer) {
        throw "Version mismatch in $($toc.Name): expected '$suiteVer'"
    }
    if (-not ($iLine -match '^##\s*Interface:\s*(.+?)\s*$') -or $Matches[1].Trim() -ne $suiteIface) {
        throw "Interface mismatch in $($toc.Name): expected '$suiteIface'"
    }
}

$changelogHead = (Get-Content -LiteralPath $changelogPath -TotalCount 5) -join "`n"
if ($changelogHead -notmatch [regex]::Escape("Release: v$suiteVer")) {
    throw "CHANGELOG.md header does not match lockstep version v$suiteVer"
}
$markerChangelogPath = Join-Path $RepoRoot "Packaging\StandaloneTOCs\CHANGELOG_DYNAMICMARKER.md"
if (-not (Test-Path -LiteralPath $markerChangelogPath)) {
    throw "Missing standalone DynamicMarker changelog at $markerChangelogPath"
}
$markerChangelogHead = (Get-Content -LiteralPath $markerChangelogPath -TotalCount 5) -join "`n"
if ($markerChangelogHead -notmatch [regex]::Escape("Release: v$suiteVer")) {
    throw "Packaging\StandaloneTOCs\CHANGELOG_DYNAMICMARKER.md header does not match lockstep version v$suiteVer"
}
$markerChangelogRaw = [System.IO.File]::ReadAllText($markerChangelogPath)
$forbiddenMarkerChangelogTerms = @("DynamicGroup", "DynamicPrep", "DynamicBags", "DynamicLoad", "DynamicChat", "DynamicFPS", "DynamicZoom", "All 8 Modules")
$foundBleed = @()
foreach ($term in $forbiddenMarkerChangelogTerms) {
    if ($markerChangelogRaw -match [regex]::Escape($term)) {
        $foundBleed += $term
    }
}
if ($foundBleed.Count -gt 0) {
    throw ("Standalone DynamicMarker changelog bleed detected in Packaging\StandaloneTOCs\CHANGELOG_DYNAMICMARKER.md (forbidden terms: " + ($foundBleed -join ", ") + ")")
}
$readmeText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot "README.md"))
if ($readmeText -notmatch [regex]::Escape("v$suiteVer")) {
    throw "README.md does not match lockstep version v$suiteVer"
}
$cfStandaloneDoc = Join-Path $RepoRoot "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICMARKER.md"
$cfMarketingDoc = Join-Path $RepoRoot "Marketing\CurseForge_DynamicMarker.md"
foreach ($markerDoc in @($cfStandaloneDoc, $cfMarketingDoc)) {
    if (-not (Test-Path -LiteralPath $markerDoc)) {
        throw "Missing required DynamicMarker storefront document: $markerDoc"
    }
    $markerDocText = [System.IO.File]::ReadAllText($markerDoc)
    if ($markerDocText -match '(?m)^(?:\*\*Version:\*\*|> \*\*Version:\*\*|## Section 2: CurseForge File Changelog Block)') {
        throw "Storefront document must remain evergreen (no version/date/changelog block): $markerDoc"
    }
}
$normMarkerStandalone = ([System.IO.File]::ReadAllText($cfStandaloneDoc)).Replace("`r`n", "`n").TrimEnd()
$normMarkerMarketing = ([System.IO.File]::ReadAllText($cfMarketingDoc)).Replace("`r`n", "`n").TrimEnd()
if ($normMarkerStandalone -ne $normMarkerMarketing) {
    throw "Marketing\CurseForge_DynamicMarker.md and Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICMARKER.md have diverged."
}
$cfSuiteStandaloneDoc = Join-Path $RepoRoot "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICSUITE.md"
$cfSuiteMarketingDoc = Join-Path $RepoRoot "Marketing\CurseForge_DynamicSuite.md"
foreach ($suiteDoc in @($cfSuiteStandaloneDoc, $cfSuiteMarketingDoc)) {
    if (-not (Test-Path -LiteralPath $suiteDoc)) {
        throw "Missing required DynamicSuite storefront document: $suiteDoc"
    }
    $suiteDocText = [System.IO.File]::ReadAllText($suiteDoc)
    if ($suiteDocText -match '(?m)^(?:\*\*Version:\*\*|> \*\*Version:\*\*|## Section 2: CurseForge File Changelog Block)') {
        throw "Storefront document must remain evergreen (no version/date/changelog block): $suiteDoc"
    }
    if ($suiteDocText -notmatch '1804382' -or $suiteDocText -notmatch [regex]::Escape("https://www.curseforge.com/wow/addons/dynamicsuite")) {
        throw "$suiteDoc is missing verified CurseForge project ID 1804382 or live URL."
    }
}
$normSuiteStandalone = ([System.IO.File]::ReadAllText($cfSuiteStandaloneDoc)).Replace("`r`n", "`n").TrimEnd()
$normSuiteMarketing = ([System.IO.File]::ReadAllText($cfSuiteMarketingDoc)).Replace("`r`n", "`n").TrimEnd()
if ($normSuiteStandalone -ne $normSuiteMarketing) {
    throw "Marketing\CurseForge_DynamicSuite.md and Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICSUITE.md have diverged."
}

$noComingSoonTargets = @(
    "DynamicSuite\DynamicSuite_Core.lua",
    "DynamicSuite\DynamicSuite_UI.lua",
    "DynamicSuite\Modules\DynamicMarker.lua",
    "README.md",
    "Marketing\CurseForge_DynamicSuite.md",
    "Marketing\CurseForge_DynamicMarker.md",
    "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICSUITE.md",
    "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICMARKER.md"
)
foreach ($relCheck in $noComingSoonTargets) {
    $absCheck = Join-Path $RepoRoot $relCheck
    if ([System.IO.File]::ReadAllText($absCheck) -match '(?i)Coming\s+Soon') {
        throw "Forbidden placeholder 'Coming Soon' found in $relCheck"
    }
}
foreach ($clRel in @("CHANGELOG.md", "DynamicSuite\CHANGELOG.md")) {
    $clAbs = Join-Path $RepoRoot $clRel
    if ([System.IO.File]::ReadAllText($clAbs) -match '(?i)(dynamicsuite\s*\(Coming\s+Soon\)|DynamicSuite\s*-\s*Coming\s+Soon)') {
        throw "Forbidden active placeholder link found in $clRel"
    }
}

$versionLuaTargets = @()
$versionLuaTargets += Get-Item -LiteralPath (Join-Path $RepoRoot "DynamicSuite\DynamicSuite_Core.lua")
$versionLuaTargets += Get-ChildItem -LiteralPath (Join-Path $RepoRoot "DynamicSuite\Modules") -Filter "Dynamic*.lua" -File
$expectedVerCall = "ResolveAddonVersion(ADDON_FOLDER, `"$suiteVer`")"
$expectedFbLine  = "local fb = fallback or `"$suiteVer`""
$expectedYieldFb = "or `"$suiteVer`""
foreach ($lf in $versionLuaTargets) {
    $raw = [System.IO.File]::ReadAllText($lf.FullName)
    if ($raw.IndexOf($expectedVerCall, [System.StringComparison]::Ordinal) -lt 0) {
        throw "$($lf.Name) is missing lockstep fallback '$expectedVerCall'"
    }
    if ($raw.IndexOf($expectedFbLine, [System.StringComparison]::Ordinal) -lt 0) {
        throw "$($lf.Name) is missing lockstep helper fallback '$expectedFbLine'"
    }
    if ($lf.Name -ne "DynamicSuite_Core.lua" -and $raw.IndexOf($expectedYieldFb, [System.StringComparison]::Ordinal) -lt 0) {
        throw "$($lf.Name) is missing lockstep ShouldYieldToOtherInstall fallback '$expectedYieldFb'"
    }
    if ($raw -match 'ResolveAddonVersion\(ADDON_FOLDER,\s*"(\d+\.\d+\.\d+)"\)' -and $Matches[1] -ne $suiteVer) {
        throw "$($lf.Name) has stale ResolveAddonVersion fallback '$($Matches[1])' (expected '$suiteVer')"
    }
}

$suiteUiText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot "DynamicSuite\DynamicSuite_UI.lua"))
$suiteCoreText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot "DynamicSuite\DynamicSuite_Core.lua"))
$markerLuaText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot "DynamicSuite\Modules\DynamicMarker.lua"))
$parityTokens = @(
    "UI-ChatIM-SizeGrabber-Up",
    "UI-ChatIM-SizeGrabber-Highlight",
    '"RIGHT", footer, "RIGHT", -32, 0',
    "https://ko-fi.com/dentee",
    "https://www.curseforge.com/wow/addons/dynamicsuite",
    "denteedev@gmail.com",
    "\\Media\\Icons\\icon_white.tga",
    "\\Media\\Icons\\icon_accent.tga",
    "Reset HUD Positions",
    "DynamicSuiteSnapGuideOverlay",
    "EDGE_SNAP_THRESHOLD",
    "BAR_SNAP_THRESHOLD"
)
foreach ($tok in $parityTokens) {
    if ($suiteUiText.IndexOf($tok, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicSuite_UI.lua missing Suite/Standalone parity token: $tok"
    }
    if ($markerLuaText.IndexOf($tok, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicMarker.lua missing Suite/Standalone parity token: $tok"
    }
}
foreach ($suiteCoexistReq in @("EnforceStandaloneDynamicMarkerExclusion", 'C_AddOns.DisableAddOn, "DynamicMarker"', "ShowMarkerConflictReloadModal", "DynamicSuiteMarkerConflictModal", "standaloneMarkerWasEnabledAtBoot", "ScrubStandaloneDynamicMarkerFromLoadDB")) {
    if ($suiteCoreText.IndexOf($suiteCoexistReq, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicSuite_Core.lua missing standalone DynamicMarker mutual-exclusion token: $suiteCoexistReq"
    }
}
if ($suiteCoreText -notmatch '(?s)elseif\s+event\s*==\s*"PLAYER_ENTERING_WORLD"\s+then.*?EnforceStandaloneDynamicMarkerExclusion\(true\).*?ShowMarkerConflictReloadModal\(\)') {
    throw "DynamicSuite_Core.lua PLAYER_ENTERING_WORLD handler must trigger EnforceStandaloneDynamicMarkerExclusion(true) and ShowMarkerConflictReloadModal()."
}
$loadLuaPath = Join-Path $RepoRoot "DynamicSuite\Modules\DynamicLoad.lua"
$loadLuaText = [System.IO.File]::ReadAllText($loadLuaPath)
foreach ($loadCoexistReq in @("local function IsStandaloneMarkerExcludedBySuite", "DL_NS.IsStandaloneMarkerExcludedBySuite = IsStandaloneMarkerExcludedBySuite")) {
    if ($loadLuaText.IndexOf($loadCoexistReq, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicLoad.lua missing top-level IsStandaloneMarkerExcludedBySuite declaration: $loadCoexistReq"
    }
}
$loadLocalFuncs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($m in [regex]::Matches($loadLuaText, '(?m)^\s*local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')) {
    [void]$loadLocalFuncs.Add($m.Groups[1].Value)
}
$loadBytecode = & $luacExe -p -l $loadLuaPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "luac5.1 -p -l failed on DynamicLoad.lua: $loadBytecode"
}
$badLoadGlobals = @()
foreach ($bcLine in $loadBytecode) {
    if ($bcLine -match 'GETGLOBAL\s+\d+\s+-?\d+\s+;\s+([A-Za-z_][A-Za-z0-9_]*)$') {
        $gName = $Matches[1]
        if ($loadLocalFuncs.Contains($gName)) {
            $badLoadGlobals += "$gName ($($bcLine.Trim()))"
        }
    }
}
if ($badLoadGlobals.Count -gt 0) {
    throw ("DynamicLoad.lua contains forward-referenced or out-of-scope local function calls resolved as GETGLOBAL:`n - " + ($badLoadGlobals -join "`n - "))
}
$loadLines = Get-Content -LiteralPath $loadLuaPath
$loadDeclLines = @{}
for ($li = 0; $li -lt $loadLines.Count; $li++) {
    $ln = $loadLines[$li]
    if ($ln -match '^\s*local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(') {
        $fn = $Matches[1]
        if (-not $loadDeclLines.ContainsKey($fn)) { $loadDeclLines[$fn] = $li + 1 }
    } elseif ($ln -match '^\s*local\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*$') {
        foreach ($part in ($Matches[1] -split ',')) {
            $fn = $part.Trim()
            if ($fn -and -not $loadDeclLines.ContainsKey($fn)) { $loadDeclLines[$fn] = $li + 1 }
        }
    }
}
$earlyLoadCalls = @()
for ($li = 0; $li -lt $loadLines.Count; $li++) {
    $codeLine = ($loadLines[$li] -replace '"(?:\\.|[^"\\])*"', '""' -replace "'(?:\\.|[^'\\])*'", "''" -replace '--.*$', '')
    if ($codeLine -match '^\s*local\s+function\s+') { continue }
    foreach ($cm in [regex]::Matches($codeLine, '(?<![\.\:\w])([A-Za-z_][A-Za-z0-9_]*)\s*\(')) {
        $fn = $cm.Groups[1].Value
        if ($loadDeclLines.ContainsKey($fn) -and ($li + 1) -lt $loadDeclLines[$fn]) {
            $earlyLoadCalls += "$fn called at line $($li + 1) before declaration at line $($loadDeclLines[$fn])"
        }
    }
}
if ($earlyLoadCalls.Count -gt 0) {
    throw ("DynamicLoad.lua contains local function call(s) on a line earlier than their local declaration:`n - " + ($earlyLoadCalls -join "`n - "))
}
if (-not $loadDeclLines.ContainsKey("IsStandaloneMarkerExcludedBySuite")) {
    throw "DynamicLoad.lua missing local function IsStandaloneMarkerExcludedBySuite declaration."
}
$allLuaCheckFiles = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "DynamicSuite") -Filter "*.lua" -Recurse -File
foreach ($luaCheck in $allLuaCheckFiles) {
    $luaCheckText = [System.IO.File]::ReadAllText($luaCheck.FullName)
    if ($luaCheckText.IndexOf("DYNAMICSUITE_MARKER_CONFLICT_RELOAD", [System.StringComparison]::Ordinal) -ge 0) {
        throw "$($luaCheck.Name) still contains forbidden legacy StaticPopup token DYNAMICSUITE_MARKER_CONFLICT_RELOAD"
    }
}
foreach ($modalTok in @("ShowMarkerConflictReloadModal", "DynamicSuiteMarkerConflictModal", "0.043, 0.051, 0.071, 0.96", "0.976, 0.451, 0.086")) {
    if ($suiteCoreText.IndexOf($modalTok, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicSuite_Core.lua missing custom dark-obsidian coexistence modal token: $modalTok"
    }
    if ($markerLuaText.IndexOf($modalTok, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicMarker.lua missing custom dark-obsidian coexistence modal token: $modalTok"
    }
}
if ($suiteCoreText -notmatch '(?s)(local function EnforceStandaloneDynamicMarkerExclusion\(.*?\r?\nend(?=\r?\n))') {
    throw "DynamicSuite_Core.lua missing complete EnforceStandaloneDynamicMarkerExclusion block."
}
$suiteExclusionBody = $Matches[1]
if ($suiteExclusionBody -match 'IsAutoYielding|autoYield|acknowledgedConflicts') {
    throw "EnforceStandaloneDynamicMarkerExclusion in DynamicSuite_Core.lua must not be gated by third-party auto-yield settings."
}
if ($markerLuaText -notmatch '(?s)\A(.*?)local function ResolveAddonVersion') {
    throw "DynamicMarker.lua missing top-of-file pre-ResolveAddonVersion section."
}
$markerTopGuardBody = $Matches[1]
if ($markerTopGuardBody.IndexOf('C_AddOns.IsAddOnLoaded("DynamicSuite")', [System.StringComparison]::Ordinal) -lt 0 -or
    $markerTopGuardBody.IndexOf('C_AddOns.DisableAddOn', [System.StringComparison]::Ordinal) -lt 0) {
    throw "DynamicMarker.lua top-of-file guard missing unconditional DynamicSuite IsAddOnLoaded / DisableAddOn exclusion."
}
if ($markerTopGuardBody -match 'IsAutoYielding|autoYield') {
    throw "DynamicMarker.lua top-of-file guard must not depend on third-party auto-yield settings."
}
if ($markerLuaText -notmatch '(?s)(local function ShouldYieldToOtherInstall\(.*?\r?\nend(?=\r?\n))') {
    throw "DynamicMarker.lua missing ShouldYieldToOtherInstall block."
}
if ($Matches[1] -match 'IsAutoYielding|autoYield') {
    throw "DynamicMarker.lua ShouldYieldToOtherInstall must not depend on third-party auto-yield settings."
}
foreach ($markerCoexistReq in @('C_AddOns.IsAddOnLoaded("DynamicSuite")', "IsRunningInSuite", "ResetSingleHUDPosition", "DynamicMarkerGridOverlay", "SetBarCenterPoint", "GetCanonicalHUDPosition")) {
    if ($markerLuaText.IndexOf($markerCoexistReq, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicMarker.lua missing coexistence / standalone HUD Edit token: $markerCoexistReq"
    }
}
foreach ($suiteCanonReq in @("SetBarCenterPoint", "GetCanonicalHUDPosition")) {
    if ($suiteUiText.IndexOf($suiteCanonReq, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicSuite_UI.lua missing canonical UIParent-local HUD coordinate token: $suiteCanonReq"
    }
}
foreach ($markerForbiddenHudTok in @("DynamicSuiteGridOverlay", "DynamicSuite HUD Edit Mode", 'CreateFrame("Frame", "DynamicSuiteEditModeModal"', 'CreateFrame("Frame", "DynamicSuiteSnapGridOverlay"')) {
    if ($markerLuaText.IndexOf($markerForbiddenHudTok, [System.StringComparison]::Ordinal) -ge 0) {
        throw "DynamicMarker.lua contains forbidden duplicate Suite HUD frame/title token: $markerForbiddenHudTok"
    }
}
$readmeSupportDocs = @(
    "README.md",
    "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICMARKER.md",
    "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICSUITE.md",
    "Marketing\CurseForge_DynamicMarker.md",
    "Marketing\CurseForge_DynamicSuite.md"
)
$requiredDocTokens = @(
    "[![Support Me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/dentee)",
    "https://www.curseforge.com/wow/addons/dynamicsuite",
    "https://www.curseforge.com/wow/addons/dynamicmarker",
    "denteedev@gmail.com",
    "## Slash Commands",
    "## Support & Contact"
)
foreach ($docRel in $readmeSupportDocs) {
    $docAbs = Join-Path $RepoRoot $docRel
    $docContent = [System.IO.File]::ReadAllText($docAbs)
    foreach ($reqTok in $requiredDocTokens) {
        if ($docContent.IndexOf($reqTok, [System.StringComparison]::Ordinal) -lt 0) {
            throw "$docRel missing required Ko-fi / CurseForge / Support & Contact parity token: $reqTok"
        }
    }
}
foreach ($suiteUiReq in @("ClampHudCoordsToScreen", "ResetAllHudPositions", "SyncBarScaleAndSizeToDB", "GetVisibleContainerExtents")) {
    if ($suiteUiText.IndexOf($suiteUiReq, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicSuite_UI.lua missing required HUD safety helper: $suiteUiReq"
    }
}
foreach ($markerReq in @("ClampHUDPositionToScreen", "ResetHUDPositions", 'cmd == "resethud"', "SyncBarScaleAndSizeToDB", "ConvertAnchorToCenterLocal", "WriteHUDCoordsToDB")) {
    if ($markerLuaText.IndexOf($markerReq, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicMarker.lua missing required HUD safety helper/command: $markerReq"
    }
}
$chatLuaText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot "DynamicSuite\Modules\DynamicChat.lua"))
foreach ($chatReq in @("GetVisibleContainerExtents", "GetLiveOuterBottomLeft")) {
    if ($chatLuaText.IndexOf($chatReq, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicChat.lua missing required HUD safety helper: $chatReq"
    }
}
if ($chatLuaText.IndexOf("cf:SetClampedToScreen(true)", [System.StringComparison]::Ordinal) -ge 0) {
    throw "DynamicChat.lua must not call cf:SetClampedToScreen(true)"
}
foreach ($slashTok in @('SLASH_DYNAMICMARKER1 = "/dm"', 'SLASH_DYNAMICMARKER3 = "/fm"', 'SlashCmdList["DYNAMICMARKER"]')) {
    if ($markerLuaText.IndexOf($slashTok, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicMarker.lua missing required slash command token: $slashTok"
    }
}
if ($suiteCoreText.IndexOf('["DYNAMICMARKER"] = "DynamicMarker"', [System.StringComparison]::Ordinal) -lt 0) {
    throw "DynamicSuite_Core.lua missing DYNAMICMARKER suite slash routing entry."
}
if ($suiteCoreText.IndexOf('cmd == "resethud"', [System.StringComparison]::Ordinal) -lt 0) {
    throw "DynamicSuite_Core.lua missing /ds resethud slash command handler."
}
$qqAuditFiles = @(
    "README.md",
    "CHANGELOG.md",
    "DynamicSuite\CHANGELOG.md",
    "Marketing\CurseForge_DynamicSuite.md",
    "Marketing\CurseForge_DynamicMarker.md",
    "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICSUITE.md",
    "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICMARKER.md"
)
foreach ($docRel in $qqAuditFiles) {
    $docText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot $docRel))
    if ($docText -match '(?i)(?<![a-z0-9_])/qq(?![a-z0-9_])') {
        throw "$docRel still contains removed slash command '/qq'."
    }
}
foreach ($luaCheck in $allLuaCheckFiles) {
    $luaRel = $luaCheck.FullName.Substring($RepoRoot.Length).TrimStart('\')
    $luaText = [System.IO.File]::ReadAllText($luaCheck.FullName)
    if ($luaText -match '(?i)(?<![a-z0-9_])/qq(?![a-z0-9_])') {
        throw "$luaRel still contains removed slash command '/qq'."
    }
}
$registeredSlashCmds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$markerSlashCmds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($luaCheck in $allLuaCheckFiles) {
    $luaText = [System.IO.File]::ReadAllText($luaCheck.FullName)
    foreach ($sm in [regex]::Matches($luaText, '(?m)^\s*(?:_G\.)?SLASH_([A-Za-z0-9_]+)\d+\s*=\s*["''](/[a-zA-Z0-9]+)["'']')) {
        $slashKey = $sm.Groups[1].Value
        $slashCmd = $sm.Groups[2].Value
        $null = $registeredSlashCmds.Add($slashCmd)
        if ($slashKey -eq "DYNAMICMARKER") {
            $null = $markerSlashCmds.Add($slashCmd)
        }
    }
}
if ($registeredSlashCmds.Count -eq 0 -or $markerSlashCmds.Count -eq 0) {
    throw "Dynamic SLASH_* extraction found 0 commands; audit regex failed."
}
foreach ($docRel in @("README.md", "Marketing\CurseForge_DynamicSuite.md", "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICSUITE.md")) {
    $docText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot $docRel))
    foreach ($cmd in $registeredSlashCmds) {
        $cmdPat = '(?i)(?<![a-z0-9_])' + [regex]::Escape($cmd) + '(?![a-z0-9_])'
        if ($docText -notmatch $cmdPat) {
            throw "$docRel is missing active registered slash command: $cmd"
        }
    }
}
foreach ($docRel in @("Marketing\CurseForge_DynamicMarker.md", "Packaging\StandaloneTOCs\CURSEFORGE_DYNAMICMARKER.md")) {
    $docText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot $docRel))
    foreach ($cmd in $markerSlashCmds) {
        $cmdPat = '(?i)(?<![a-z0-9_])' + [regex]::Escape($cmd) + '(?![a-z0-9_])'
        if ($docText -notmatch $cmdPat) {
            throw "$docRel is missing active DynamicMarker slash command: $cmd"
        }
    }
}
Write-Host "[AUDIT OK] Verified $($registeredSlashCmds.Count) active SLASH_* commands ($($markerSlashCmds.Count) DynamicMarker), 0 '/qq' refs" -ForegroundColor Green
Write-Host "[PARITY OK] Lockstep v$suiteVer ($suiteIface), public docs clean, Suite <-> DynamicMarker UI parity verified" -ForegroundColor Green

$pkgMetaSuitePath = Join-Path $RepoRoot ".pkgmeta"
$pkgMetaMarkerRootPath = Join-Path $RepoRoot ".pkgmeta-dynamicmarker"
$pkgMetaMarkerPkgPath = Join-Path $RepoRoot "Packaging\StandaloneTOCs\.pkgmeta-dynamicmarker"
foreach ($reqMeta in @($pkgMetaSuitePath, $pkgMetaMarkerRootPath, $pkgMetaMarkerPkgPath)) {
    if (-not (Test-Path -LiteralPath $reqMeta)) {
        throw "Missing required packager config: $reqMeta"
    }
}

$pkgMetaSuiteText = [System.IO.File]::ReadAllText($pkgMetaSuitePath)
if ($pkgMetaSuiteText -notmatch '(?m)^package-as:\s*DynamicSuite\s*$') {
    throw ".pkgmeta must specify 'package-as: DynamicSuite'."
}
if ($pkgMetaSuiteText -notmatch '(?m)^\s*DynamicSuite/DynamicSuite:\s*DynamicSuite\s*$') {
    throw ".pkgmeta must map 'DynamicSuite/DynamicSuite: DynamicSuite' under move-folders:."
}
if ($pkgMetaSuiteText -notmatch '(?m)^\s*filename:\s*\.release-changelog\.md\s*$') {
    throw ".pkgmeta manual-changelog must target '.release-changelog.md'."
}
foreach ($suiteIgnore in @('\.github', '\.pkgmeta', '\.pkgmeta-dynamicmarker', '\.release-changelog\.md', 'AGENTS\.md', 'DESIGN_SYSTEM\.md', 'TASKS\.md', 'Design', 'Marketing', 'Packaging', 'scripts')) {
    if ($pkgMetaSuiteText -notmatch "(?m)^\s*-\s*$suiteIgnore\s*$") {
        throw ".pkgmeta must exclude '$suiteIgnore' under ignore:."
    }
}

$pkgMetaMarkerText = [System.IO.File]::ReadAllText($pkgMetaMarkerPkgPath)
$normMarkerRoot = ([System.IO.File]::ReadAllText($pkgMetaMarkerRootPath)).Replace("`r`n", "`n").TrimEnd()
$normMarkerPkg = $pkgMetaMarkerText.Replace("`r`n", "`n").TrimEnd()
if ($normMarkerRoot -ne $normMarkerPkg) {
    throw ".pkgmeta-dynamicmarker and Packaging\StandaloneTOCs\.pkgmeta-dynamicmarker have diverged."
}
if ($pkgMetaMarkerText -notmatch '(?m)^package-as:\s*DynamicMarker\s*$') {
    throw "Packaging\StandaloneTOCs\.pkgmeta-dynamicmarker must specify 'package-as: DynamicMarker'."
}
if ($pkgMetaMarkerText -notmatch '(?m)^\s*DynamicMarker/Packaging/StandaloneTOCs:\s*DynamicMarker\s*$') {
    throw "Packaging\StandaloneTOCs\.pkgmeta-dynamicmarker must map 'DynamicMarker/Packaging/StandaloneTOCs: DynamicMarker' under move-folders:."
}
if ($pkgMetaMarkerText -notmatch '(?m)^\s*filename:\s*\.release-changelog\.md\s*$') {
    throw "Packaging\StandaloneTOCs\.pkgmeta-dynamicmarker manual-changelog must target '.release-changelog.md'."
}
foreach ($markerIgnore in @('\.release-changelog\.md', 'DynamicSuite', 'Packaging', 'Marketing', 'scripts', '\.github', 'Design', 'AGENTS\.md', 'DESIGN_SYSTEM\.md', 'TASKS\.md')) {
    if ($pkgMetaMarkerText -notmatch "(?m)^\s*-\s*$markerIgnore\s*$") {
        throw "Packaging\StandaloneTOCs\.pkgmeta-dynamicmarker must exclude '$markerIgnore' under ignore:."
    }
}

$requiredSuiteAssets = @(
    "DynamicSuite\DynamicSuite.toc",
    "DynamicSuite\DynamicSuite_Core.lua",
    "DynamicSuite\DynamicSuite_UI.lua",
    "DynamicSuite\icon.tga",
    "DynamicSuite\Media\Icons\icon_white.tga",
    "DynamicSuite\Media\Icons\icon_accent.tga",
    "DynamicSuite\CHANGELOG.md",
    "README.md"
)
$requiredStandaloneAssets = @(
    "Packaging\StandaloneTOCs\DynamicMarker.toc",
    "DynamicSuite\Modules\DynamicMarker.lua",
    "DynamicSuite\icon.tga",
    "DynamicSuite\Media\Icons\icon_white.tga",
    "DynamicSuite\Media\Icons\icon_accent.tga",
    "Packaging\StandaloneTOCs\CHANGELOG_DYNAMICMARKER.md"
)
foreach ($assetRel in ($requiredSuiteAssets + $requiredStandaloneAssets | Sort-Object -Unique)) {
    $assetAbs = Join-Path $RepoRoot $assetRel
    if (-not (Test-Path -LiteralPath $assetAbs)) {
        throw "Missing required release asset: $assetRel"
    }
}

$workflowPath = Join-Path $RepoRoot ".github\workflows\release.yml"
if (-not (Test-Path -LiteralPath $workflowPath)) {
    throw "Missing release workflow at $workflowPath"
}
$workflowText = [System.IO.File]::ReadAllText($workflowPath)
foreach ($yamlFile in @($workflowPath, $pkgMetaSuitePath, $pkgMetaMarkerRootPath, $pkgMetaMarkerPkgPath)) {
    $yamlLines = Get-Content -LiteralPath $yamlFile
    for ($li = 0; $li -lt $yamlLines.Count; $li++) {
        if ($yamlLines[$li] -match '^[ ]*\t') {
            throw "YAML indentation error (tab character) in $yamlFile at line $($li + 1)."
        }
    }
}
foreach ($yamlKey in @('(?m)^name:\s*\S+', '(?m)^on:\s*$', '(?m)^jobs:\s*$', '(?m)^\s+steps:\s*$')) {
    if ($workflowText -notmatch $yamlKey) {
        throw "release.yml missing required YAML section matching '$yamlKey'."
    }
}
$pyCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pyCmd -and $pyCmd.Source -notmatch 'WindowsApps') {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $yamlCheck = & $pyCmd.Source -c "import sys; import yaml; [yaml.safe_load(open(p, encoding='utf-8')) for p in sys.argv[1:]]" $workflowPath $pkgMetaSuitePath $pkgMetaMarkerRootPath $pkgMetaMarkerPkgPath 2>&1
    $pyExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($pyExit -eq 0) {
        Write-Host "[YAML OK] PyYAML parsed release.yml, .pkgmeta, and .pkgmeta-dynamicmarker configs cleanly" -ForegroundColor DarkCyan
    } elseif ($yamlCheck -notmatch "No module named 'yaml'") {
        throw "PyYAML validation failed: $yamlCheck"
    }
}
if ($workflowText -notmatch [regex]::Escape("-p 1804382 -m .pkgmeta")) {
    throw "release.yml must package Project ID 1804382 (DynamicSuite) with .pkgmeta."
}
if ($workflowText -notmatch [regex]::Escape("-p 1331651 -m Packaging/StandaloneTOCs/.pkgmeta-dynamicmarker")) {
    throw "release.yml must package Project ID 1331651 (DynamicMarker) with Packaging/StandaloneTOCs/.pkgmeta-dynamicmarker."
}
if ($workflowText -notmatch '\.release-changelog\.md') {
    throw "release.yml must slice CHANGELOG.md into .release-changelog.md to prevent GitHub Release HTTP 422 body-limit failures."
}
if ($workflowText -notmatch '120000') {
    throw "release.yml must enforce the 120,000-character fail-fast guard on .release-changelog.md."
}
if ($workflowText -match 'cp\s+Packaging/StandaloneTOCs/DynamicMarker\.toc\s+DynamicMarker\.toc') {
    throw "release.yml must not copy DynamicMarker.toc to the repository root."
}
if ($workflowText -notmatch [regex]::Escape("Packaging/StandaloneTOCs/CHANGELOG_DYNAMICMARKER.md")) {
    throw "release.yml must use Packaging/StandaloneTOCs/CHANGELOG_DYNAMICMARKER.md for standalone DynamicMarker (1331651) packaging."
}
foreach ($chanToken in @("CF_RELEASE_TYPE", '"-alpha"', '"-beta"', '"-rc"', "GITHUB_RELEASE_PRERELEASE")) {
    if ($workflowText.IndexOf($chanToken, [System.StringComparison]::Ordinal) -lt 0) {
        throw "release.yml is missing required automatic CurseForge release-channel token: $chanToken"
    }
}
Write-Host "[PACKAGING GUARD OK] Verified YAML, .pkgmeta (1804382), .pkgmeta-dynamicmarker (1331651), and release.yml channel routing" -ForegroundColor Green

$resolvedCfChannel = $null
$resolvedGhReleaseKind = $null
if (-not [string]::IsNullOrWhiteSpace($ReleaseTag)) {
    if ($ReleaseTag -match '^v(\d+\.\d+\.\d+)(?:-(alpha|beta|rc)(?:\.[0-9A-Za-z.-]+|[0-9A-Za-z.-]*)?)?$') {
        $tagBaseVer = $Matches[1]
    } else {
        throw "ReleaseTag '$ReleaseTag' must match clean semantic format 'vX.Y.Z' or pre-release format 'vX.Y.Z-alpha.N', 'vX.Y.Z-beta.N', or 'vX.Y.Z-rc.N'."
    }
    if ($tagBaseVer -ne $suiteVer) {
        throw "ReleaseTag '$ReleaseTag' base version 'v$tagBaseVer' does not match lockstep .toc version 'v$suiteVer'."
    }
    if ($ReleaseTag -match '(?i)-alpha') {
        $resolvedCfChannel = "alpha"
        $resolvedGhReleaseKind = "Pre-release"
    } elseif ($ReleaseTag -match '(?i)-(beta|rc)') {
        $resolvedCfChannel = "beta"
        $resolvedGhReleaseKind = "Pre-release"
    } else {
        $resolvedCfChannel = "release"
        $resolvedGhReleaseKind = "Full Release"
    }
    Write-Host "[RELEASE TAG OK] Validated tag $ReleaseTag (base v$tagBaseVer matches lockstep .toc v$suiteVer)" -ForegroundColor Green
    Write-Host "[RELEASE CHANNEL] Tag '$ReleaseTag' -> CurseForge channel: '$resolvedCfChannel' | GitHub Release: '$resolvedGhReleaseKind' (1804382 DynamicSuite + 1331651 DynamicMarker)" -ForegroundColor Cyan
}

function New-VerifiedAddonReleaseZip {
    param(
        [Parameter(Mandatory = $true)][string]$AddonName,
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$Interface,
        [Parameter(Mandatory = $true)][string]$MarketingDir,
        [Parameter(Mandatory = $true)][string[]]$RequiredFiles,
        [Parameter(Mandatory = $true)][scriptblock]$StageAction,
        [string]$OnlyAllowedLuaName
    )

    $zipFileName = "{0}-{1}.zip" -f $AddonName, $Version
    $releaseZipPath = Join-Path $MarketingDir $zipFileName
    $stageTmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("{0}_Stage_{1}" -f $AddonName, [guid]::NewGuid().ToString("N"))
    $verifyTmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("{0}_Verify_{1}" -f $AddonName, [guid]::NewGuid().ToString("N"))

    try {
        $stageAddonDir = Join-Path $stageTmpRoot $AddonName
        New-Item -ItemType Directory -Force -Path $stageAddonDir | Out-Null

        & $StageAction $stageAddonDir

        if (Test-Path -LiteralPath $releaseZipPath) {
            Remove-Item -LiteralPath $releaseZipPath -Force
        }

        $stagedFiles = Get-ChildItem -LiteralPath $stageAddonDir -Recurse -File | Sort-Object FullName
        $zipFs = [System.IO.File]::Open($releaseZipPath, [System.IO.FileMode]::CreateNew)
        try {
            $zipArc = New-Object System.IO.Compression.ZipArchive($zipFs, [System.IO.Compression.ZipArchiveMode]::Create)
            try {
                foreach ($sf in $stagedFiles) {
                    $relEntry = $sf.FullName.Substring($stageTmpRoot.TrimEnd('\').Length + 1).Replace('\', '/')
                    $entry = $zipArc.CreateEntry($relEntry, [System.IO.Compression.CompressionLevel]::Optimal)
                    $entry.LastWriteTime = [DateTimeOffset]$sf.LastWriteTime
                    $es = $entry.Open()
                    try {
                        $inFs = [System.IO.File]::OpenRead($sf.FullName)
                        try { $inFs.CopyTo($es) } finally { $inFs.Dispose() }
                    } finally {
                        $es.Dispose()
                    }
                }
            } finally {
                $zipArc.Dispose()
            }
        } finally {
            $zipFs.Dispose()
        }

        $checkArc = [System.IO.Compression.ZipFile]::OpenRead($releaseZipPath)
        try {
            $entryPrefixRx = "^" + [regex]::Escape($AddonName) + "/"
            foreach ($e in $checkArc.Entries) {
                if ($e.FullName -match '\\' -or $e.FullName -notmatch $entryPrefixRx) {
                    throw "Invalid release ZIP entry path in $($releaseZipPath): $($e.FullName)"
                }
            }
        } finally {
            $checkArc.Dispose()
        }

        [System.IO.Compression.ZipFile]::ExtractToDirectory($releaseZipPath, $verifyTmpRoot)
        $topEntries = @(Get-ChildItem -LiteralPath $verifyTmpRoot)
        if ($topEntries.Count -ne 1 -or -not $topEntries[0].PSIsContainer -or $topEntries[0].Name -ne $AddonName) {
            throw "Release ZIP must extract strictly to top-level $AddonName/ folder."
        }

        $extractedAddonDir = $topEntries[0].FullName
        $extractedTocPath = Join-Path $extractedAddonDir "$AddonName.toc"
        if (-not (Test-Path -LiteralPath $extractedTocPath)) {
            throw "Extracted release ZIP is missing $AddonName/$AddonName.toc."
        }

        $extTocLines = Get-Content -LiteralPath $extractedTocPath
        $extVer = ($extTocLines | Where-Object { $_ -match '^##\s*Version:\s*(.+?)\s*$' } | Select-Object -First 1)
        $extIface = ($extTocLines | Where-Object { $_ -match '^##\s*Interface:\s*(.+?)\s*$' } | Select-Object -First 1)
        if (-not ($extVer -match '^##\s*Version:\s*(.+?)\s*$') -or $Matches[1].Trim() -ne $Version) {
            throw "Extracted $AddonName.toc version mismatch (expected $Version)."
        }
        if (-not ($extIface -match '^##\s*Interface:\s*(.+?)\s*$') -or $Matches[1].Trim() -ne $Interface) {
            throw "Extracted $AddonName.toc interface mismatch (expected $Interface)."
        }
        $extIconLine = ($extTocLines | Where-Object { $_ -match '^##\s*IconTexture:\s*(.+?)\s*$' } | Select-Object -First 1)
        $iconPrefixRx = "^##\s*IconTexture:\s*Interface\\AddOns\\" + [regex]::Escape($AddonName) + "\\(.+?)\s*$"
        if ($extIconLine -match $iconPrefixRx) {
            $iconRel = $Matches[1].Trim()
            if (-not (Test-Path -LiteralPath (Join-Path $extractedAddonDir $iconRel))) {
                throw "Extracted $AddonName.toc IconTexture missing: $iconRel"
            }
        }
        foreach ($tocEntry in ($extTocLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' })) {
            $relPath = $tocEntry.Trim()
            if (-not (Test-Path -LiteralPath (Join-Path $extractedAddonDir $relPath))) {
                throw "Extracted $AddonName.toc references missing file: $relPath"
            }
        }
        foreach ($reqRel in $RequiredFiles) {
            if (-not (Test-Path -LiteralPath (Join-Path $extractedAddonDir $reqRel))) {
                throw "Extracted $AddonName ZIP missing required file: $reqRel"
            }
        }

        $extractedAll = Get-ChildItem -LiteralPath $verifyTmpRoot -Recurse -File
        foreach ($ef in $extractedAll) {
            $relNorm = $ef.FullName.Substring($verifyTmpRoot.Length + 1).Replace('\', '/')
            if ($OnlyAllowedLuaName -and $ef.Extension -ieq ".lua" -and $ef.Name -cne $OnlyAllowedLuaName) {
                throw "Forbidden Lua file found in standalone $AddonName ZIP: $relNorm"
            }
            if ($ef.Extension -match '^\.(ps1|cmd|zip)$') {
                throw "Forbidden script/archive file found in $AddonName ZIP: $relNorm"
            }
            if ($ef.Name -match '^(AGENTS|DESIGN_SYSTEM|TASKS)\.md$' -or $ef.Name -match '^CURSEFORGE_.*\.md$' -or $ef.Name -match '^\.pkgmeta' -or $relNorm -match '/(Design|Packaging|Marketing|scripts|\.github)/') {
                throw "Forbidden internal/dev file found in $AddonName ZIP: $relNorm"
            }
            if ($OnlyAllowedLuaName -and $ef.Name -eq "README.md") {
                throw "Unexpected README.md found in standalone $AddonName ZIP: $relNorm"
            }
        }

        $zipKb = [math]::Round(((Get-Item -LiteralPath $releaseZipPath).Length / 1KB), 1)
        Write-Host "[ZIP OK] Built and verified Marketing\$zipFileName ($zipKb KB, $($extractedAll.Count) file(s))" -ForegroundColor Green
    }
    finally {
        if (Test-Path -LiteralPath $stageTmpRoot) { Remove-Item -LiteralPath $stageTmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $verifyTmpRoot) { Remove-Item -LiteralPath $verifyTmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

if ($BuildReleaseZip) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    if (-not (Test-Path -LiteralPath $marketingDir)) {
        New-Item -ItemType Directory -Force -Path $marketingDir | Out-Null
    }

    $skipAssetRx = '(\.bak|\.tmp|\.orig|\.rej|\.ps1|\.cmd|Thumbs\.db|\.DS_Store|desktop\.ini)$'
    $suiteSrcDir = Join-Path $RepoRoot "DynamicSuite"
    $rootReadmeSrc = Join-Path $RepoRoot "README.md"
    $suiteChangelogSrc = Join-Path $RepoRoot "DynamicSuite\CHANGELOG.md"

    New-VerifiedAddonReleaseZip -AddonName "DynamicSuite" -Version $suiteVer -Interface $suiteIface -MarketingDir $marketingDir `
        -RequiredFiles @("DynamicSuite.toc", "DynamicSuite_Core.lua", "DynamicSuite_UI.lua", "icon.tga", "Media\Icons\icon_white.tga", "Media\Icons\icon_accent.tga", "CHANGELOG.md", "README.md") `
        -StageAction {
            param($stageAddonDir)
            Copy-Item -LiteralPath (Join-Path $suiteSrcDir "DynamicSuite.toc") -Destination (Join-Path $stageAddonDir "DynamicSuite.toc") -Force
            Copy-Item -LiteralPath (Join-Path $suiteSrcDir "DynamicSuite_Core.lua") -Destination (Join-Path $stageAddonDir "DynamicSuite_Core.lua") -Force
            Copy-Item -LiteralPath (Join-Path $suiteSrcDir "DynamicSuite_UI.lua") -Destination (Join-Path $stageAddonDir "DynamicSuite_UI.lua") -Force
            Copy-Item -LiteralPath $suiteChangelogSrc -Destination (Join-Path $stageAddonDir "CHANGELOG.md") -Force
            Copy-Item -LiteralPath $rootReadmeSrc -Destination (Join-Path $stageAddonDir "README.md") -Force
            Get-ChildItem -LiteralPath $suiteSrcDir -Filter "*.tga" -File | Where-Object { $_.Name -notmatch $skipAssetRx } | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $stageAddonDir $_.Name) -Force
            }
            $dstModules = Join-Path $stageAddonDir "Modules"
            New-Item -ItemType Directory -Force -Path $dstModules | Out-Null
            Get-ChildItem -LiteralPath (Join-Path $suiteSrcDir "Modules") -Filter "Dynamic*.lua" -File | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dstModules $_.Name) -Force
            }
            $mediaIconsSrc = Join-Path $suiteSrcDir "Media\Icons"
            if (Test-Path -LiteralPath $mediaIconsSrc) {
                $dstIcons = Join-Path $stageAddonDir "Media\Icons"
                New-Item -ItemType Directory -Force -Path $dstIcons | Out-Null
                Get-ChildItem -LiteralPath $mediaIconsSrc -File | Where-Object { $_.Name -notmatch $skipAssetRx } | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dstIcons $_.Name) -Force
                }
            }
            $mediaFontsSrc = Join-Path $suiteSrcDir "Media\Fonts"
            if (Test-Path -LiteralPath $mediaFontsSrc) {
                $dstMediaFonts = Join-Path $stageAddonDir "Media\Fonts"
                New-Item -ItemType Directory -Force -Path $dstMediaFonts | Out-Null
                Get-ChildItem -LiteralPath $mediaFontsSrc -File | Where-Object { $_.Name -notmatch $skipAssetRx } | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dstMediaFonts $_.Name) -Force
                }
            }
            $mediaSoundsSrc = Join-Path $suiteSrcDir "Media\Sounds"
            if (Test-Path -LiteralPath $mediaSoundsSrc) {
                $dstMediaSounds = Join-Path $stageAddonDir "Media\Sounds"
                New-Item -ItemType Directory -Force -Path $dstMediaSounds | Out-Null
                Get-ChildItem -LiteralPath $mediaSoundsSrc -File | Where-Object { $_.Name -notmatch $skipAssetRx } | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dstMediaSounds $_.Name) -Force
                }
            }
            $rootFontsSrc = Join-Path $suiteSrcDir "Fonts"
            if (Test-Path -LiteralPath $rootFontsSrc) {
                $dstRootFonts = Join-Path $stageAddonDir "Fonts"
                New-Item -ItemType Directory -Force -Path $dstRootFonts | Out-Null
                Get-ChildItem -LiteralPath $rootFontsSrc -File | Where-Object { $_.Name -notmatch $skipAssetRx } | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dstRootFonts $_.Name) -Force
                }
            }
        }

    New-VerifiedAddonReleaseZip -AddonName "DynamicMarker" -Version $suiteVer -Interface $suiteIface -MarketingDir $marketingDir `
        -OnlyAllowedLuaName "DynamicMarker.lua" `
        -RequiredFiles @("DynamicMarker.toc", "DynamicMarker.lua", "icon.tga", "Media\Icons\icon_white.tga", "Media\Icons\icon_accent.tga", "CHANGELOG.md") `
        -StageAction {
            param($stageAddonDir)
            $markerTocSrc = Join-Path $RepoRoot "Packaging\StandaloneTOCs\DynamicMarker.toc"
            $markerLuaSrc = Join-Path $suiteSrcDir "Modules\DynamicMarker.lua"
            $markerChangelogSrc = Join-Path $RepoRoot "Packaging\StandaloneTOCs\CHANGELOG_DYNAMICMARKER.md"
            $markerIconSrc = Join-Path $suiteSrcDir "icon.tga"
            $mediaIconsSrc = Join-Path $suiteSrcDir "Media\Icons"
            $mediaFontsSrc = Join-Path $suiteSrcDir "Media\Fonts"
            $rootFontsSrc = Join-Path $suiteSrcDir "Fonts"

            Copy-Item -LiteralPath $markerTocSrc -Destination (Join-Path $stageAddonDir "DynamicMarker.toc") -Force
            Copy-Item -LiteralPath $markerLuaSrc -Destination (Join-Path $stageAddonDir "DynamicMarker.lua") -Force
            Copy-Item -LiteralPath $markerChangelogSrc -Destination (Join-Path $stageAddonDir "CHANGELOG.md") -Force
            if (Test-Path -LiteralPath $markerIconSrc) {
                Copy-Item -LiteralPath $markerIconSrc -Destination (Join-Path $stageAddonDir "icon.tga") -Force
            }
            if (Test-Path -LiteralPath $mediaIconsSrc) {
                $dstIcons = Join-Path $stageAddonDir "Media\Icons"
                New-Item -ItemType Directory -Force -Path $dstIcons | Out-Null
                Get-ChildItem -LiteralPath $mediaIconsSrc -File | Where-Object { $_.Name -notmatch $skipAssetRx } | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dstIcons $_.Name) -Force
                }
            }
            if (Test-Path -LiteralPath $mediaFontsSrc) {
                $dstMediaFonts = Join-Path $stageAddonDir "Media\Fonts"
                New-Item -ItemType Directory -Force -Path $dstMediaFonts | Out-Null
                Get-ChildItem -LiteralPath $mediaFontsSrc -File | Where-Object { $_.Name -notmatch $skipAssetRx } | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dstMediaFonts $_.Name) -Force
                }
            }
            if (Test-Path -LiteralPath $rootFontsSrc) {
                $markerRaw = [System.IO.File]::ReadAllText($markerLuaSrc)
                $fontRefs = [regex]::Matches($markerRaw, '\\\\Fonts\\\\([^"\\|]+?\.(?:ttf|otf))', 'IgnoreCase') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
                foreach ($fn in $fontRefs) {
                    $fp = Get-ChildItem -LiteralPath $rootFontsSrc -File | Where-Object { $_.Name -ieq $fn } | Select-Object -First 1
                    if ($fp) {
                        $dstRootFonts = Join-Path $stageAddonDir "Fonts"
                        New-Item -ItemType Directory -Force -Path $dstRootFonts | Out-Null
                        Copy-Item -LiteralPath $fp.FullName -Destination (Join-Path $dstRootFonts $fp.Name) -Force
                    }
                }
            }
        }
}

# 4. Internal files & .gitignore guard
$internalPatterns = @("AGENTS.md", "DESIGN_SYSTEM.md", "TASKS.md", "Design/")
$gitignorePath = Join-Path $RepoRoot ".gitignore"
if (-not (Test-Path -LiteralPath $gitignorePath)) {
    throw ".gitignore is missing at $gitignorePath"
}
$gitignoreLines = Get-Content -LiteralPath $gitignorePath | ForEach-Object { $_.Trim() }
foreach ($pat in $internalPatterns) {
    if (-not ($gitignoreLines -contains $pat)) {
        throw ".gitignore is missing required internal exclusion: $pat"
    }
}

Push-Location $RepoRoot
try {
    $trackedInternal = & $gitExe ls-files -- "AGENTS.md" "DESIGN_SYSTEM.md" "TASKS.md" "Design" "Design/*"
    if ($LASTEXITCODE -ne 0) { throw "git ls-files failed." }
    if ($trackedInternal) {
        throw ("Internal files must remain untracked in Git:`n - " + ($trackedInternal -join "`n - "))
    }
    Write-Host "[GITIGNORE OK] Internal files verified untracked" -ForegroundColor Green

    # 5. Deploy & Cloud Sync
    if (-not $SkipSync) {
        if (-not (Test-Path -LiteralPath $PushCmd)) {
            throw "Sync script not found: $PushCmd"
        }
        & cmd.exe /c "`"$PushCmd`""
        if ($LASTEXITCODE -ne 0) {
            throw "Push-DynamicSuiteSync.cmd exited with code $LASTEXITCODE"
        }
        $wowStandaloneMarkerDir = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\DynamicMarker"
        if (Test-Path -LiteralPath $wowStandaloneMarkerDir) {
            Copy-Item -LiteralPath (Join-Path $RepoRoot "Packaging\StandaloneTOCs\DynamicMarker.toc") -Destination (Join-Path $wowStandaloneMarkerDir "DynamicMarker.toc") -Force
            Copy-Item -LiteralPath (Join-Path $RepoRoot "DynamicSuite\Modules\DynamicMarker.lua") -Destination (Join-Path $wowStandaloneMarkerDir "DynamicMarker.lua") -Force
            Copy-Item -LiteralPath (Join-Path $RepoRoot "Packaging\StandaloneTOCs\CHANGELOG_DYNAMICMARKER.md") -Destination (Join-Path $wowStandaloneMarkerDir "CHANGELOG.md") -Force
            Write-Host "[STANDALONE SYNCED] DynamicMarker.toc, DynamicMarker.lua, & CHANGELOG.md -> $wowStandaloneMarkerDir" -ForegroundColor DarkCyan
        }
        $driveSyncRoot = "G:\My Drive\DynamicSuite_Sync"
        if (Test-Path -LiteralPath $driveSyncRoot) {
            Copy-Item -LiteralPath (Join-Path $RepoRoot "README.md") -Destination (Join-Path $driveSyncRoot "README.md") -Force
            Copy-Item -LiteralPath (Join-Path $RepoRoot "Marketing\CurseForge_DynamicMarker.md") -Destination (Join-Path $driveSyncRoot "CURSEFORGE_DYNAMICMARKER.md") -Force
            Copy-Item -LiteralPath (Join-Path $RepoRoot "Marketing\CurseForge_DynamicSuite.md") -Destination (Join-Path $driveSyncRoot "CURSEFORGE_DYNAMICSUITE.md") -Force
            $driveMarketingDir = Join-Path $driveSyncRoot "Marketing"
            if (Test-Path -LiteralPath $driveMarketingDir) {
                Copy-Item -LiteralPath (Join-Path $RepoRoot "Marketing\CurseForge_DynamicMarker.md") -Destination (Join-Path $driveMarketingDir "CurseForge_DynamicMarker.md") -Force
                Copy-Item -LiteralPath (Join-Path $RepoRoot "Marketing\CurseForge_DynamicSuite.md") -Destination (Join-Path $driveMarketingDir "CurseForge_DynamicSuite.md") -Force
            }
            $driveModulesTxtDir = Join-Path $driveSyncRoot "ModulesTxt"
            New-Item -ItemType Directory -Force -Path $driveModulesTxtDir | Out-Null
            Copy-Item -LiteralPath (Join-Path $RepoRoot "DynamicSuite\DynamicSuite_Core.lua") -Destination (Join-Path $driveModulesTxtDir "DynamicSuite_Core.lua.txt") -Force
            Copy-Item -LiteralPath (Join-Path $RepoRoot "DynamicSuite\DynamicSuite_UI.lua") -Destination (Join-Path $driveModulesTxtDir "DynamicSuite_UI.lua.txt") -Force
            Get-ChildItem -LiteralPath (Join-Path $RepoRoot "DynamicSuite\Modules") -Filter "*.lua" -File | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $driveModulesTxtDir ($_.Name + ".txt")) -Force
            }
            Write-Host "[TXT MIRRORED] DynamicSuite_Core.lua.txt, DynamicSuite_UI.lua.txt, & 8 Module .lua.txt files -> $driveModulesTxtDir" -ForegroundColor DarkCyan
            Write-Host "[CURSEFORGE DOCS SYNCED] README.md, CURSEFORGE_DYNAMICMARKER.md, & CURSEFORGE_DYNAMICSUITE.md -> $driveSyncRoot" -ForegroundColor DarkCyan
        }
    } else {
        Write-Host "[SYNC SKIPPED] -SkipSync specified" -ForegroundColor Yellow
    }

    # 6. Git stage, commit & push
    if (-not $SkipGit) {
        $status = & $gitExe status --porcelain
        if ($LASTEXITCODE -ne 0) { throw "git status failed." }

        if ($status) {
            & $gitExe add -A
            if ($LASTEXITCODE -ne 0) { throw "git add failed." }

            $stagedInternal = & $gitExe diff --cached --name-only -- "AGENTS.md" "DESIGN_SYSTEM.md" "TASKS.md" "Design" "Design/*"
            if ($stagedInternal) {
                & $gitExe reset HEAD -- $stagedInternal | Out-Null
                throw ("Aborted: internal files were staged:`n - " + ($stagedInternal -join "`n - "))
            }

            $msg = if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
                "chore: validate, sync, and deploy DynamicSuite"
            } else {
                $CommitMessage
            }
            & $gitExe commit -m $msg
            if ($LASTEXITCODE -ne 0) { throw "git commit failed." }
        } else {
            Write-Host "[GIT] Working tree clean; no new commit needed." -ForegroundColor DarkCyan
        }

        & $gitExe push origin main
        if ($LASTEXITCODE -ne 0) { throw "git push origin main failed." }
        Write-Host "[GIT PUSHED] origin/main is up to date" -ForegroundColor Green

        if (-not [string]::IsNullOrWhiteSpace($ReleaseTag)) {
            Write-Host "[RELEASE SUMMARY] Pushing tag '$ReleaseTag' -> CurseForge '$resolvedCfChannel' channel ($resolvedGhReleaseKind) for DynamicSuite (1804382) & DynamicMarker (1331651)..." -ForegroundColor Cyan
            $localTag = & $gitExe tag -l $ReleaseTag
            if ($LASTEXITCODE -ne 0) { throw "git tag -l failed." }
            if ($localTag) {
                & $gitExe tag -d $ReleaseTag | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Failed to delete stale local tag '$ReleaseTag'." }
                Write-Host "[TAG CLEANUP] Deleted stale local tag $ReleaseTag" -ForegroundColor Yellow
            }
            $remoteTag = & $gitExe ls-remote --tags origin "refs/tags/$ReleaseTag"
            if ($LASTEXITCODE -ne 0) { throw "git ls-remote failed." }
            if ($remoteTag) {
                & $gitExe push origin ":refs/tags/$ReleaseTag"
                if ($LASTEXITCODE -ne 0) { throw "Failed to delete stale remote tag '$ReleaseTag'." }
                Write-Host "[TAG CLEANUP] Deleted stale remote tag $ReleaseTag" -ForegroundColor Yellow
            }
            & $gitExe tag -a $ReleaseTag -m "Release $ReleaseTag [$resolvedCfChannel] (DynamicSuite + Standalone DynamicMarker)"
            if ($LASTEXITCODE -ne 0) { throw "git tag -a $ReleaseTag failed." }
            & $gitExe push origin $ReleaseTag
            if ($LASTEXITCODE -ne 0) { throw "git push origin $ReleaseTag failed." }
            Write-Host "[TAG PUSHED] Annotated tag $ReleaseTag pushed to origin (CurseForge target channel: $resolvedCfChannel)" -ForegroundColor Green

            $prevTag = (& $gitExe describe --tags --abbrev=0 "$ReleaseTag^" 2>$null)
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($prevTag)) {
                $storefrontPaths = @(
                    "Marketing/CurseForge_DynamicSuite.md",
                    "Marketing/CurseForge_DynamicMarker.md",
                    "Packaging/StandaloneTOCs/CURSEFORGE_DYNAMICSUITE.md",
                    "Packaging/StandaloneTOCs/CURSEFORGE_DYNAMICMARKER.md"
                )
                $changedStorefront = & $gitExe diff --name-only "$prevTag" "$ReleaseTag" -- @storefrontPaths
                if ($changedStorefront) {
                    $firstChanged = ($changedStorefront | Select-Object -First 1)
                    $firstAbs = Join-Path $RepoRoot ($firstChanged -replace '/', '\')
                    if (Test-Path -LiteralPath $firstAbs) {
                        Get-Content -LiteralPath $firstAbs -Raw | Set-Clipboard
                        Write-Host "[STOREFRONT REMINDER] Storefront Markdown changed since $prevTag ($($changedStorefront -join ', ')). Copied $firstChanged to clipboard for CurseForge Overview update." -ForegroundColor Yellow
                    }
                }
            }
        }
    } else {
        Write-Host "[GIT SKIPPED] -SkipGit specified" -ForegroundColor Yellow
    }
}
finally {
    Pop-Location
}
