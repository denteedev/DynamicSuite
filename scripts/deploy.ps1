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
foreach ($docName in @("CHANGELOG.md", "DynamicSuite\CHANGELOG.md", "README.md", "AGENTS.md", "DESIGN_SYSTEM.md", "TASKS.md", ".pkgmeta", ".pkgmeta-dynamicmarker", ".github\workflows\release.yml")) {
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
$pubDocs = @("README.md", "CHANGELOG.md", "DynamicSuite\CHANGELOG.md")
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
$readmeText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot "README.md"))
if ($readmeText -notmatch [regex]::Escape("v$suiteVer")) {
    throw "README.md does not match lockstep version v$suiteVer"
}

$versionLuaTargets = @()
$versionLuaTargets += Get-Item -LiteralPath (Join-Path $RepoRoot "DynamicSuite\DynamicSuite_Core.lua")
$versionLuaTargets += Get-ChildItem -LiteralPath (Join-Path $RepoRoot "DynamicSuite\Modules") -Filter "Dynamic*.lua" -File
$expectedVerCall = "ResolveAddonVersion(ADDON_FOLDER, `"$suiteVer`")"
foreach ($lf in $versionLuaTargets) {
    $raw = [System.IO.File]::ReadAllText($lf.FullName)
    if ($raw.IndexOf($expectedVerCall, [System.StringComparison]::Ordinal) -lt 0) {
        throw "$($lf.Name) is missing lockstep fallback '$expectedVerCall'"
    }
}

$suiteUiText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot "DynamicSuite\DynamicSuite_UI.lua"))
$markerLuaText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot "DynamicSuite\Modules\DynamicMarker.lua"))
$parityTokens = @(
    "UI-ChatIM-SizeGrabber-Up",
    "UI-ChatIM-SizeGrabber-Highlight",
    '"RIGHT", footer, "RIGHT", -32, 0',
    "https://ko-fi.com/dentee",
    "https://www.curseforge.com/wow/addons/dynamicsuite (Coming Soon)",
    "denteedev@gmail.com",
    "\\Media\\Icons\\icon_white.tga",
    "\\Media\\Icons\\icon_accent.tga"
)
foreach ($tok in $parityTokens) {
    if ($suiteUiText.IndexOf($tok, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicSuite_UI.lua missing Suite/Standalone parity token: $tok"
    }
    if ($markerLuaText.IndexOf($tok, [System.StringComparison]::Ordinal) -lt 0) {
        throw "DynamicMarker.lua missing Suite/Standalone parity token: $tok"
    }
}
Write-Host "[PARITY OK] Lockstep v$suiteVer ($suiteIface), public docs clean, Suite <-> DynamicMarker UI parity verified" -ForegroundColor Green

if (-not [string]::IsNullOrWhiteSpace($ReleaseTag)) {
    if ($ReleaseTag -notmatch '^v\d+\.\d+\.\d+$') {
        throw "ReleaseTag '$ReleaseTag' must match semantic tag format 'vX.Y.Z'."
    }
    if ($ReleaseTag -ne "v$suiteVer") {
        throw "ReleaseTag '$ReleaseTag' does not match lockstep .toc version 'v$suiteVer'."
    }
    $pkgMetaMarkerPath = Join-Path $RepoRoot ".pkgmeta-dynamicmarker"
    if (-not (Test-Path -LiteralPath $pkgMetaMarkerPath)) {
        throw "Missing .pkgmeta-dynamicmarker at $pkgMetaMarkerPath"
    }
    $pkgMetaMarkerText = [System.IO.File]::ReadAllText($pkgMetaMarkerPath)
    if ($pkgMetaMarkerText -notmatch '(?m)^package-as:\s*DynamicMarker\s*$') {
        throw ".pkgmeta-dynamicmarker must specify 'package-as: DynamicMarker'."
    }
    if ($pkgMetaMarkerText -notmatch '(?m)^\s*DynamicMarker/Packaging/StandaloneTOCs:\s*DynamicMarker\s*$') {
        throw ".pkgmeta-dynamicmarker must map 'DynamicMarker/Packaging/StandaloneTOCs: DynamicMarker' under move-folders:."
    }
    if ($pkgMetaMarkerText -notmatch '(?m)^\s*filename:\s*\.release-changelog\.md\s*$') {
        throw ".pkgmeta-dynamicmarker manual-changelog must target '.release-changelog.md'."
    }
    if ($pkgMetaMarkerText -notmatch '(?m)^\s*-\s*\.release-changelog\.md\s*$') {
        throw ".pkgmeta-dynamicmarker must exclude '.release-changelog.md' under ignore:."
    }
    if ($pkgMetaMarkerText -notmatch '(?m)^\s*-\s*DynamicSuite\s*$') {
        throw ".pkgmeta-dynamicmarker must exclude 'DynamicSuite' under ignore:."
    }

    $markerTocPath = Join-Path $RepoRoot "Packaging\StandaloneTOCs\DynamicMarker.toc"
    $requiredStandaloneAssets = @(
        "Packaging\StandaloneTOCs\DynamicMarker.toc",
        "DynamicSuite\Modules\DynamicMarker.lua",
        "DynamicSuite\icon.tga",
        "DynamicSuite\Media\Icons\icon_white.tga",
        "DynamicSuite\Media\Icons\icon_accent.tga",
        "DynamicSuite\CHANGELOG.md"
    )
    foreach ($assetRel in $requiredStandaloneAssets) {
        $assetAbs = Join-Path $RepoRoot $assetRel
        if (-not (Test-Path -LiteralPath $assetAbs)) {
            throw "Missing required standalone DynamicMarker asset: $assetRel"
        }
    }

    $workflowPath = Join-Path $RepoRoot ".github\workflows\release.yml"
    if (-not (Test-Path -LiteralPath $workflowPath)) {
        throw "Missing release workflow at $workflowPath"
    }
    $workflowText = [System.IO.File]::ReadAllText($workflowPath)
    foreach ($yamlFile in @($workflowPath, $pkgMetaMarkerPath, (Join-Path $RepoRoot ".pkgmeta"))) {
        if (Test-Path -LiteralPath $yamlFile) {
            $yamlLines = Get-Content -LiteralPath $yamlFile
            for ($li = 0; $li -lt $yamlLines.Count; $li++) {
                if ($yamlLines[$li] -match '^[ ]*\t') {
                    throw "YAML indentation error (tab character) in $yamlFile at line $($li + 1)."
                }
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
        $yamlCheck = & $pyCmd.Source -c "import sys; import yaml; [yaml.safe_load(open(p, encoding='utf-8')) for p in sys.argv[1:]]" $workflowPath $pkgMetaMarkerPath (Join-Path $RepoRoot ".pkgmeta") 2>&1
        $pyExit = $LASTEXITCODE
        $ErrorActionPreference = $prevEap
        if ($pyExit -eq 0) {
            Write-Host "[YAML OK] PyYAML parsed release.yml, .pkgmeta, and .pkgmeta-dynamicmarker cleanly" -ForegroundColor DarkCyan
        } elseif ($yamlCheck -notmatch "No module named 'yaml'") {
            throw "PyYAML validation failed: $yamlCheck"
        }
    }
    if ($workflowText -notmatch [regex]::Escape("-p 1331651 -m .pkgmeta-dynamicmarker")) {
        throw "release.yml must package Project ID 1331651 with .pkgmeta-dynamicmarker."
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
    Write-Host "[RELEASE GUARD OK] Verified YAML syntax, .pkgmeta-dynamicmarker (DynamicMarker), release.yml (1331651), and standalone assets for $ReleaseTag" -ForegroundColor Green
}

if ($BuildReleaseZip) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    if (-not (Test-Path -LiteralPath $marketingDir)) {
        New-Item -ItemType Directory -Force -Path $marketingDir | Out-Null
    }

    $markerTocSrc = Join-Path $RepoRoot "Packaging\StandaloneTOCs\DynamicMarker.toc"
    $markerLuaSrc = Join-Path $RepoRoot "DynamicSuite\Modules\DynamicMarker.lua"
    $markerIconSrc = Join-Path $RepoRoot "DynamicSuite\icon.tga"
    $mediaIconsSrc = Join-Path $RepoRoot "DynamicSuite\Media\Icons"
    $mediaFontsSrc = Join-Path $RepoRoot "DynamicSuite\Media\Fonts"
    $rootFontsSrc = Join-Path $RepoRoot "DynamicSuite\Fonts"
    $suiteChangelogSrc = Join-Path $RepoRoot "DynamicSuite\CHANGELOG.md"

    foreach ($reqFile in @($markerTocSrc, $markerLuaSrc, $suiteChangelogSrc)) {
        if (-not (Test-Path -LiteralPath $reqFile)) {
            throw "Missing required standalone release file: $reqFile"
        }
    }

    $releaseZipPath = Join-Path $marketingDir ("DynamicMarker-{0}.zip" -f $suiteVer)
    $stageTmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("DynamicMarker_Stage_" + [guid]::NewGuid().ToString("N"))
    $verifyTmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("DynamicMarker_Verify_" + [guid]::NewGuid().ToString("N"))

    try {
        $stageAddonDir = Join-Path $stageTmpRoot "DynamicMarker"
        New-Item -ItemType Directory -Force -Path $stageAddonDir | Out-Null

        Copy-Item -LiteralPath $markerTocSrc -Destination (Join-Path $stageAddonDir "DynamicMarker.toc") -Force
        Copy-Item -LiteralPath $markerLuaSrc -Destination (Join-Path $stageAddonDir "DynamicMarker.lua") -Force
        Copy-Item -LiteralPath $suiteChangelogSrc -Destination (Join-Path $stageAddonDir "CHANGELOG.md") -Force
        if (Test-Path -LiteralPath $markerIconSrc) {
            Copy-Item -LiteralPath $markerIconSrc -Destination (Join-Path $stageAddonDir "icon.tga") -Force
        }

        $skipAssetRx = '(\.bak|\.tmp|\.orig|\.rej|Thumbs\.db|\.DS_Store|desktop\.ini)$'
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

        # Verify archive entry format and clean extraction
        $checkArc = [System.IO.Compression.ZipFile]::OpenRead($releaseZipPath)
        try {
            foreach ($e in $checkArc.Entries) {
                if ($e.FullName -match '\\' -or $e.FullName -notmatch '^DynamicMarker/') {
                    throw "Invalid release ZIP entry path in $($releaseZipPath): $($e.FullName)"
                }
            }
        } finally {
            $checkArc.Dispose()
        }

        [System.IO.Compression.ZipFile]::ExtractToDirectory($releaseZipPath, $verifyTmpRoot)
        $topEntries = @(Get-ChildItem -LiteralPath $verifyTmpRoot)
        if ($topEntries.Count -ne 1 -or -not $topEntries[0].PSIsContainer -or $topEntries[0].Name -ne "DynamicMarker") {
            throw "Release ZIP must extract strictly to top-level DynamicMarker/ folder."
        }

        $extractedAddonDir = $topEntries[0].FullName
        $extractedTocPath = Join-Path $extractedAddonDir "DynamicMarker.toc"
        if (-not (Test-Path -LiteralPath $extractedTocPath)) {
            throw "Extracted release ZIP is missing DynamicMarker/DynamicMarker.toc."
        }

        $extTocLines = Get-Content -LiteralPath $extractedTocPath
        $extVer = ($extTocLines | Where-Object { $_ -match '^##\s*Version:\s*(.+?)\s*$' } | Select-Object -First 1)
        $extIface = ($extTocLines | Where-Object { $_ -match '^##\s*Interface:\s*(.+?)\s*$' } | Select-Object -First 1)
        if (-not ($extVer -match '^##\s*Version:\s*(.+?)\s*$') -or $Matches[1].Trim() -ne $suiteVer) {
            throw "Extracted DynamicMarker.toc version mismatch (expected $suiteVer)."
        }
        if (-not ($extIface -match '^##\s*Interface:\s*(.+?)\s*$') -or $Matches[1].Trim() -ne $suiteIface) {
            throw "Extracted DynamicMarker.toc interface mismatch (expected $suiteIface)."
        }
        $extIconLine = ($extTocLines | Where-Object { $_ -match '^##\s*IconTexture:\s*(.+?)\s*$' } | Select-Object -First 1)
        if ($extIconLine -match '^##\s*IconTexture:\s*Interface\\AddOns\\DynamicMarker\\(.+?)\s*$') {
            $iconRel = $Matches[1].Trim()
            if (-not (Test-Path -LiteralPath (Join-Path $extractedAddonDir $iconRel))) {
                throw "Extracted DynamicMarker.toc IconTexture missing: $iconRel"
            }
        }
        foreach ($tocEntry in ($extTocLines | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' })) {
            $relPath = $tocEntry.Trim()
            if (-not (Test-Path -LiteralPath (Join-Path $extractedAddonDir $relPath))) {
                throw "Extracted DynamicMarker.toc references missing file: $relPath"
            }
        }

        $extractedAll = Get-ChildItem -LiteralPath $verifyTmpRoot -Recurse -File
        foreach ($ef in $extractedAll) {
            $relNorm = $ef.FullName.Substring($verifyTmpRoot.Length + 1).Replace('\', '/')
            if ($ef.Extension -ieq ".lua" -and $ef.Name -cne "DynamicMarker.lua") {
                throw "Forbidden Lua file found in standalone DynamicMarker ZIP: $relNorm"
            }
            if ($ef.Extension -match '^\.(ps1|cmd)$') {
                throw "Forbidden script file found in standalone DynamicMarker ZIP: $relNorm"
            }
            if ($ef.Name -match '^(AGENTS|DESIGN_SYSTEM|TASKS|README)\.md$' -or $relNorm -match '/Design/') {
                throw "Forbidden internal/non-package doc found in standalone DynamicMarker ZIP: $relNorm"
            }
        }

        $zipKb = [math]::Round(((Get-Item -LiteralPath $releaseZipPath).Length / 1KB), 1)
        Write-Host "[ZIP OK] Built and verified Marketing\DynamicMarker-$suiteVer.zip ($zipKb KB, $($extractedAll.Count) file(s))" -ForegroundColor Green
    }
    finally {
        if (Test-Path -LiteralPath $stageTmpRoot) { Remove-Item -LiteralPath $stageTmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $verifyTmpRoot) { Remove-Item -LiteralPath $verifyTmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
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
            & $gitExe tag -a $ReleaseTag -m "Release $ReleaseTag (Standalone DynamicMarker)"
            if ($LASTEXITCODE -ne 0) { throw "git tag -a $ReleaseTag failed." }
            & $gitExe push origin $ReleaseTag
            if ($LASTEXITCODE -ne 0) { throw "git push origin $ReleaseTag failed." }
            Write-Host "[TAG PUSHED] Annotated tag $ReleaseTag pushed to origin" -ForegroundColor Green
        }
    } else {
        Write-Host "[GIT SKIPPED] -SkipGit specified" -ForegroundColor Yellow
    }
}
finally {
    Pop-Location
}
