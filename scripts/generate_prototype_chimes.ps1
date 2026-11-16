<#
.SYNOPSIS
    Synthesizes two warm, low-fatigue .ogg notification chimes for DynamicChat Tab 3.
#>
[CmdletBinding()]
param(
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $OutputDir = Join-Path $repoRoot "DynamicSuite\Media\Sounds"
}

function Resolve-FFmpeg {
    $cmd = Get-Command "ffmpeg" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $wingetLinks = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\ffmpeg.exe"
    if (Test-Path -LiteralPath $wingetLinks) { return $wingetLinks }
    $wingetPkg = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages") -Filter "ffmpeg.exe" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wingetPkg) { return $wingetPkg.FullName }
    throw "ffmpeg.exe was not found on PATH or in WinGet packages."
}

function Write-WavFile {
    param(
        [string]$Path,
        [double[]]$Samples,
        [int]$SampleRate = 44100
    )
    $numSamples = $Samples.Length
    $dataSize = $numSamples * 2
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter($fs)
    try {
        # RIFF header
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
        $bw.Write([int](36 + $dataSize))
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
        # fmt chunk
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
        $bw.Write([int]16)
        $bw.Write([int16]1)          # PCM
        $bw.Write([int16]1)          # Mono
        $bw.Write([int]$SampleRate)
        $bw.Write([int]($SampleRate * 2))
        $bw.Write([int16]2)          # BlockAlign
        $bw.Write([int16]16)         # BitsPerSample
        # data chunk
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
        $bw.Write([int]$dataSize)

        for ($i = 0; $i -lt $numSamples; $i++) {
            $s = $Samples[$i]
            if ($s -gt 1.0) { $s = 1.0 }
            elseif ($s -lt -1.0) { $s = -1.0 }
            $pcm = [int16][Math]::Round($s * 32767.0)
            $bw.Write($pcm)
        }
    }
    finally {
        $bw.Dispose()
        $fs.Dispose()
    }
}

function Normalize-PeakDbFS {
    param(
        [double[]]$Samples,
        [double]$TargetDbFS = -6.0
    )
    $maxAbs = 0.0
    for ($i = 0; $i -lt $Samples.Length; $i++) {
        $a = [Math]::Abs($Samples[$i])
        if ($a -gt $maxAbs) { $maxAbs = $a }
    }
    if ($maxAbs -le 1e-9) { return $Samples }
    $targetAmp = [Math]::Pow(10.0, $TargetDbFS / 20.0)
    $gain = $targetAmp / $maxAbs
    $out = New-Object double[] $Samples.Length
    for ($i = 0; $i -lt $Samples.Length; $i++) {
        $out[$i] = $Samples[$i] * $gain
    }
    return $out
}

function New-MentionWarmSamples {
    param([int]$SampleRate = 44100)
    $totalSec = 0.320
    $n = [int][Math]::Round($totalSec * $SampleRate)
    $buf = New-Object double[] $n
    $twoPi = 2.0 * [Math]::PI

    # Note 1: G4 (392.00 Hz) at t = 0.000s, Note 2: D5 (587.33 Hz) at t = 0.095s
    $notes = @(
        @{ Start = 0.000; End = 0.240; Freq = 392.00; Gain = 0.85; Tau = 0.070 },
        @{ Start = 0.095; End = 0.320; Freq = 587.33; Gain = 1.00; Tau = 0.085 }
    )

    foreach ($note in $notes) {
        $startIdx = [int][Math]::Round($note.Start * $SampleRate)
        $endIdx = [int][Math]::Min($n - 1, [Math]::Round($note.End * $SampleRate))
        $attackSec = 0.007
        $releaseSec = 0.025
        $dur = $note.End - $note.Start
        $f = $note.Freq

        for ($i = $startIdx; $i -le $endIdx; $i++) {
            $t = ($i - $startIdx) / [double]$SampleRate
            $envAtk = 1.0
            if ($t -lt $attackSec) {
                $envAtk = 0.5 * (1.0 - [Math]::Cos([Math]::PI * $t / $attackSec))
            }
            $envRel = 1.0
            $rem = $dur - $t
            if ($rem -lt $releaseSec) {
                if ($rem -le 0.0) { $envRel = 0.0 }
                else { $envRel = 0.5 * (1.0 - [Math]::Cos([Math]::PI * $rem / $releaseSec)) }
            }
            $decay1 = [Math]::Exp(-$t / $note.Tau)
            $decay2 = [Math]::Exp(-$t / ($note.Tau * 0.52))
            $decay3 = [Math]::Exp(-$t / ($note.Tau * 0.25))

            $sig = (
                1.00 * [Math]::Sin($twoPi * $f * $t) * $decay1 +
                0.22 * [Math]::Sin($twoPi * (2.0 * $f) * $t) * $decay2 +
                0.05 * [Math]::Sin($twoPi * (3.0 * $f) * $t) * $decay3 +
                0.08 * [Math]::Sin($twoPi * (0.5 * $f) * $t) * $decay2
            )
            $buf[$i] += $note.Gain * $envAtk * $envRel * $sig
        }
    }

    return (Normalize-PeakDbFS -Samples $buf -TargetDbFS -6.0)
}

function New-KeywordPulseSamples {
    param([int]$SampleRate = 44100)
    $totalSec = 0.240
    $n = [int][Math]::Round($totalSec * $SampleRate)
    $buf = New-Object double[] $n
    $twoPi = 2.0 * [Math]::PI

    # Deeper muted warm wood-block / sub-bell pulse at D4 (293.66 Hz)
    $fBase = 293.66
    $attackSec = 0.006
    $releaseSec = 0.025
    $tau1 = 0.062
    $tau2 = 0.028
    $tau3 = 0.015

    $phase1 = 0.0
    $phase2 = 0.0
    $phase3 = 0.0
    $phaseSub = 0.0

    for ($i = 0; $i -lt $n; $i++) {
        $t = $i / [double]$SampleRate
        # Gentle mallet pitch settle (+1.5% -> 0% over ~18ms)
        $f = $fBase * (1.0 + 0.015 * [Math]::Exp(-$t / 0.009))
        $dt = 1.0 / $SampleRate
        $phase1 += $twoPi * $f * $dt
        $phase2 += $twoPi * (2.0 * $f) * $dt
        $phase3 += $twoPi * (2.76 * $f) * $dt
        $phaseSub += $twoPi * (0.5 * $f) * $dt

        $envAtk = 1.0
        if ($t -lt $attackSec) {
            $envAtk = 0.5 * (1.0 - [Math]::Cos([Math]::PI * $t / $attackSec))
        }
        $envRel = 1.0
        $rem = $totalSec - $t
        if ($rem -lt $releaseSec) {
            if ($rem -le 0.0) { $envRel = 0.0 }
            else { $envRel = 0.5 * (1.0 - [Math]::Cos([Math]::PI * $rem / $releaseSec)) }
        }

        $sig = (
            1.00 * [Math]::Sin($phase1) * [Math]::Exp(-$t / $tau1) +
            0.24 * [Math]::Sin($phase2) * [Math]::Exp(-$t / $tau2) +
            0.08 * [Math]::Sin($phase3) * [Math]::Exp(-$t / $tau3) +
            0.18 * [Math]::Sin($phaseSub) * [Math]::Exp(-$t / ($tau1 * 0.90))
        )
        $buf[$i] = $envAtk * $envRel * $sig
    }

    return (Normalize-PeakDbFS -Samples $buf -TargetDbFS -6.0)
}

$ffmpeg = Resolve-FFmpeg
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "DynamicChatAudioProto"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$specs = @(
    @{ Name = "DynamicChat_MentionWarm";  Samples = (New-MentionWarmSamples) },
    @{ Name = "DynamicChat_KeywordPulse"; Samples = (New-KeywordPulseSamples) }
)

foreach ($spec in $specs) {
    $wavPath = Join-Path $tempDir ($spec.Name + ".wav")
    $oggPath = Join-Path $OutputDir ($spec.Name + ".ogg")
    Write-WavFile -Path $wavPath -Samples $spec.Samples -SampleRate 44100
    & $ffmpeg -y -hide_banner -loglevel error -i $wavPath -c:a libvorbis -q:a 6 -ar 44100 -ac 1 $oggPath
    if ($LASTEXITCODE -ne 0) {
        throw "FFmpeg encoding failed for $($spec.Name)"
    }
    Remove-Item -LiteralPath $wavPath -Force -ErrorAction SilentlyContinue
    Write-Host "[OGG OK] $oggPath" -ForegroundColor Green
}

Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
