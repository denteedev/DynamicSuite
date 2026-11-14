<#
.SYNOPSIS
    End-to-end validation, deployment, cloud sync, and Git push pipeline for DynamicSuite.

.DESCRIPTION
    1. Resolves luac5.1.exe and git.exe even when missing from the default non-interactive PATH.
    2. Validates all .lua files under DynamicSuite\ with luac5.1 -p.
    3. Verifies strict pure ASCII (no bytes > 127) and no UTF-8 BOM across .lua, .toc, .ps1, and CHANGELOG.md.
    4. Verifies internal planning files (AGENTS.md, DESIGN_SYSTEM.md, TASKS.md, Design/) are ignored and untracked.
    5. Runs D:\DriveSync\Push-DynamicSuiteSync.cmd (WoW AddOns + Google Drive sync; never touches SavedVariables).
    6. Stages public changes, commits (when dirty), and pushes to origin/main.
#>
[CmdletBinding()]
param(
    [string] $CommitMessage = "",
    [switch] $SkipSync,
    [switch] $SkipGit
)

$ErrorActionPreference = "Stop"

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
foreach ($docName in @("CHANGELOG.md", "DynamicSuite\CHANGELOG.md", "README.md", "AGENTS.md", "DESIGN_SYSTEM.md", "TASKS.md")) {
    $docPath = Join-Path $RepoRoot $docName
    if (Test-Path -LiteralPath $docPath) {
        $asciiTargets += Get-Item -LiteralPath $docPath
    }
}
$asciiTargets += Get-Item -LiteralPath $PSCommandPath

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
foreach ($pubDoc in @("README.md", "CHANGELOG.md", "DynamicSuite\CHANGELOG.md")) {
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
    "denteedev@gmail.com"
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
    } else {
        Write-Host "[GIT SKIPPED] -SkipGit specified" -ForegroundColor Yellow
    }
}
finally {
    Pop-Location
}
