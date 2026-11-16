<#
.SYNOPSIS
    Synthesizes the 10-chime EX3-inspired 44.1 kHz Stereo Vorbis .ogg sound pack
    for DynamicChat Tab 3.
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

function Write-StereoWavFile {
    param(
        [string]$Path,
        [double[]]$Left,
        [double[]]$Right,
        [int]$SampleRate = 44100
    )
    $numSamples = $Left.Length
    $channels = 2
    $dataSize = $numSamples * $channels * 2
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter($fs)
    try {
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
        $bw.Write([int](36 + $dataSize))
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
        $bw.Write([int]16)
        $bw.Write([int16]1)
        $bw.Write([int16]$channels)
        $bw.Write([int]$SampleRate)
        $bw.Write([int]($SampleRate * $channels * 2))
        $bw.Write([int16]($channels * 2))
        $bw.Write([int16]16)
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
        $bw.Write([int]$dataSize)

        for ($i = 0; $i -lt $numSamples; $i++) {
            $sl = $Left[$i]
            if ($sl -gt 1.0) { $sl = 1.0 } elseif ($sl -lt -1.0) { $sl = -1.0 }
            $sr = $Right[$i]
            if ($sr -gt 1.0) { $sr = 1.0 } elseif ($sr -lt -1.0) { $sr = -1.0 }
            $bw.Write([int16][Math]::Round($sl * 32767.0))
            $bw.Write([int16][Math]::Round($sr * 32767.0))
        }
    }
    finally {
        $bw.Dispose()
        $fs.Dispose()
    }
}

function Normalize-StereoPeakDbFS {
    param(
        [double[]]$Left,
        [double[]]$Right,
        [double]$TargetDbFS = -6.0
    )
    $maxAbs = 0.0
    for ($i = 0; $i -lt $Left.Length; $i++) {
        $al = [Math]::Abs($Left[$i])
        $ar = [Math]::Abs($Right[$i])
        if ($al -gt $maxAbs) { $maxAbs = $al }
        if ($ar -gt $maxAbs) { $maxAbs = $ar }
    }
    if ($maxAbs -le 1e-9) { return }
    $targetAmp = [Math]::Pow(10.0, $TargetDbFS / 20.0)
    $gain = $targetAmp / $maxAbs
    for ($i = 0; $i -lt $Left.Length; $i++) {
        $Left[$i]  = $Left[$i] * $gain
        $Right[$i] = $Right[$i] * $gain
    }
}

function Add-CrystallineBellPluck {
    param(
        [double[]]$Left,
        [double[]]$Right,
        [int]$SampleRate,
        [double]$StartSec,
        [double]$Freq,
        [double]$Gain,
        [double]$TauMain,
        [double]$Pan,
        [double]$HarmonicScale = 1.0
    )
    $n = $Left.Length
    $startIdx = [int][Math]::Round($StartSec * $SampleRate)
    $twoPi = 2.0 * [Math]::PI
    $attackSec = 0.0028
    $detune = 0.0022

    $angle = ($Pan + 1.0) * 0.25 * [Math]::PI
    $gainL = $Gain * [Math]::Cos($angle)
    $gainR = $Gain * [Math]::Sin($angle)

    $h2 = 0.34 * $HarmonicScale
    $h3 = 0.14 * $HarmonicScale
    $h4 = 0.06 * $HarmonicScale

    for ($i = $startIdx; $i -lt $n; $i++) {
        $t = ($i - $startIdx) / [double]$SampleRate
        $envAtk = 1.0
        if ($t -lt $attackSec) {
            $envAtk = 0.5 * (1.0 - [Math]::Cos([Math]::PI * $t / $attackSec))
        }

        $d1 = [Math]::Exp(-$t / $TauMain)
        $d2 = [Math]::Exp(-$t / ($TauMain * 0.45))
        $d3 = [Math]::Exp(-$t / ($TauMain * 0.20))
        $d4 = [Math]::Exp(-$t / ($TauMain * 0.11))

        $fL = $Freq * (1.0 - $detune)
        $fR = $Freq * (1.0 + $detune)

        $sigL = (
            1.00 * [Math]::Sin($twoPi * $Freq * $t) * $d1 +
            $h2  * [Math]::Sin($twoPi * (2.0 * $fL) * $t) * $d2 +
            $h3  * [Math]::Sin($twoPi * (3.0 * $fL) * $t) * $d3 +
            $h4  * [Math]::Sin($twoPi * (4.02 * $fL) * $t) * $d4
        )
        $sigR = (
            1.00 * [Math]::Sin($twoPi * $Freq * $t) * $d1 +
            $h2  * [Math]::Sin($twoPi * (2.0 * $fR) * $t) * $d2 +
            $h3  * [Math]::Sin($twoPi * (3.0 * $fR) * $t) * $d3 +
            $h4  * [Math]::Sin($twoPi * (4.02 * $fR) * $t) * $d4
        )

        $Left[$i]  += $gainL * $envAtk * $sigL
        $Right[$i] += $gainR * $envAtk * $sigR
    }
}

function Apply-StereoTailAndFade {
    param(
        [double[]]$Left,
        [double[]]$Right,
        [int]$SampleRate,
        [double]$FadeOutSec = 0.045,
        [double]$Tap1LSec = 0.140,
        [double]$Tap1RSec = 0.165,
        [double]$Tap2LSec = 0.255,
        [double]$Tap2RSec = 0.285
    )
    $n = $Left.Length
    $dL1 = [int][Math]::Round($Tap1LSec * $SampleRate)
    $dR1 = [int][Math]::Round($Tap1RSec * $SampleRate)
    $dL2 = [int][Math]::Round($Tap2LSec * $SampleRate)
    $dR2 = [int][Math]::Round($Tap2RSec * $SampleRate)

    $copyL = $Left.Clone()
    $copyR = $Right.Clone()

    for ($i = 0; $i -lt $n; $i++) {
        if ($i -ge $dL1) { $Left[$i]  += 0.14 * $copyR[$i - $dL1] }
        if ($i -ge $dR1) { $Right[$i] += 0.14 * $copyL[$i - $dR1] }
        if ($i -ge $dL2) { $Left[$i]  += 0.07 * $copyL[$i - $dL2] }
        if ($i -ge $dR2) { $Right[$i] += 0.07 * $copyR[$i - $dR2] }
    }

    $fadeSamples = [int][Math]::Round($FadeOutSec * $SampleRate)
    $fadeStart = $n - $fadeSamples
    if ($fadeStart -lt 0) { $fadeStart = 0 }
    for ($i = $fadeStart; $i -lt $n; $i++) {
        $frac = ($n - 1 - $i) / [double]$fadeSamples
        if ($frac -lt 0.0) { $frac = 0.0 }
        $w = 0.5 * (1.0 - [Math]::Cos([Math]::PI * $frac))
        $Left[$i]  *= $w
        $Right[$i] *= $w
    }
}

function New-ChimeFromNotes {
    param(
        [double]$TotalSec,
        [double]$FadeOutSec,
        [hashtable[]]$Notes,
        [double]$HarmonicScale = 1.0,
        [double]$Tap1LSec = 0.140,
        [double]$Tap1RSec = 0.165,
        [int]$SampleRate = 44100
    )
    $n = [int][Math]::Round($TotalSec * $SampleRate)
    $left  = New-Object double[] $n
    $right = New-Object double[] $n
    foreach ($note in $Notes) {
        Add-CrystallineBellPluck -Left $left -Right $right -SampleRate $SampleRate `
            -StartSec $note.Start -Freq $note.Freq -Gain $note.Gain -TauMain $note.Tau -Pan $note.Pan `
            -HarmonicScale $HarmonicScale
    }
    Apply-StereoTailAndFade -Left $left -Right $right -SampleRate $SampleRate -FadeOutSec $FadeOutSec `
        -Tap1LSec $Tap1LSec -Tap1RSec $Tap1RSec
    Normalize-StereoPeakDbFS -Left $left -Right $right -TargetDbFS -6.0
    return @{ Left = $left; Right = $right }
}

$ffmpeg = Resolve-FFmpeg
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "DynamicChatAudioPack10"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$packSpecs = @(
    @{
        Name = "DynamicChat_ChimeSpark"
        Data = (New-ChimeFromNotes -TotalSec 0.340 -FadeOutSec 0.040 -Notes @(
            @{ Start = 0.000; Freq = 987.77;  Gain = 1.00; Tau = 0.095; Pan = 0.00 }
        ))
    },
    @{
        Name = "DynamicChat_KeywordPulse"
        Data = (New-ChimeFromNotes -TotalSec 0.420 -FadeOutSec 0.045 -Notes @(
            @{ Start = 0.000; Freq = 587.33;  Gain = 1.00; Tau = 0.120; Pan = 0.00 }
        ))
    },
    @{
        Name = "DynamicChat_ChimeDuo"
        Data = (New-ChimeFromNotes -TotalSec 0.480 -FadeOutSec 0.045 -Notes @(
            @{ Start = 0.000; Freq = 587.33;  Gain = 0.88; Tau = 0.115; Pan = -0.15 },
            @{ Start = 0.065; Freq = 880.00;  Gain = 1.00; Tau = 0.135; Pan =  0.15 }
        ))
    },
    @{
        Name = "DynamicChat_ChimeWhisper"
        Data = (New-ChimeFromNotes -TotalSec 0.460 -FadeOutSec 0.050 -HarmonicScale 0.45 -Notes @(
            @{ Start = 0.000; Freq = 1318.51; Gain = 0.92; Tau = 0.105; Pan = -0.14 },
            @{ Start = 0.095; Freq = 1108.73; Gain = 1.00; Tau = 0.130; Pan =  0.14 }
        ))
    },
    @{
        Name = "DynamicChat_MentionWarm"
        Data = (New-ChimeFromNotes -TotalSec 0.680 -FadeOutSec 0.055 -Notes @(
            @{ Start = 0.000; Freq = 523.25;  Gain = 0.82; Tau = 0.120; Pan = -0.45 },
            @{ Start = 0.042; Freq = 783.99;  Gain = 0.88; Tau = 0.130; Pan = -0.15 },
            @{ Start = 0.084; Freq = 987.77;  Gain = 0.94; Tau = 0.140; Pan =  0.15 },
            @{ Start = 0.130; Freq = 1318.51; Gain = 1.00; Tau = 0.175; Pan =  0.45 }
        ))
    },
    @{
        Name = "DynamicChat_ChimeAlert"
        Data = (New-ChimeFromNotes -TotalSec 0.560 -FadeOutSec 0.045 -HarmonicScale 1.35 -Notes @(
            @{ Start = 0.000; Freq = 440.00;  Gain = 0.86; Tau = 0.085; Pan =  0.00 },
            @{ Start = 0.110; Freq = 880.00;  Gain = 0.94; Tau = 0.075; Pan = -0.18 },
            @{ Start = 0.185; Freq = 880.00;  Gain = 1.00; Tau = 0.135; Pan =  0.18 }
        ))
    },
    @{
        Name = "DynamicChat_ChimeEcho"
        Data = (New-ChimeFromNotes -TotalSec 0.300 -FadeOutSec 0.040 -Tap1LSec 0.070 -Tap1RSec 0.070 -Notes @(
            @{ Start = 0.000; Freq = 1046.50; Gain = 1.00; Tau = 0.065; Pan = -0.25 }
        ))
    },
    @{
        Name = "DynamicChat_ChimeFourth"
        Data = (New-ChimeFromNotes -TotalSec 0.440 -FadeOutSec 0.045 -Notes @(
            @{ Start = 0.000; Freq = 659.25;  Gain = 0.88; Tau = 0.105; Pan = -0.16 },
            @{ Start = 0.080; Freq = 880.00;  Gain = 1.00; Tau = 0.130; Pan =  0.16 }
        ))
    },
    @{
        Name = "DynamicChat_ChimeBloom"
        Data = (New-ChimeFromNotes -TotalSec 0.620 -FadeOutSec 0.055 -Notes @(
            @{ Start = 0.000; Freq = 698.46;  Gain = 0.84; Tau = 0.135; Pan = -0.24 },
            @{ Start = 0.070; Freq = 1046.50; Gain = 0.92; Tau = 0.145; Pan =  0.00 },
            @{ Start = 0.145; Freq = 1567.98; Gain = 1.00; Tau = 0.175; Pan =  0.24 }
        ))
    },
    @{
        Name = "DynamicChat_ChimeBeacon"
        Data = (New-ChimeFromNotes -TotalSec 0.720 -FadeOutSec 0.055 -Notes @(
            @{ Start = 0.000; Freq = 783.99;  Gain = 0.84; Tau = 0.110; Pan = -0.22 },
            @{ Start = 0.065; Freq = 1174.66; Gain = 0.92; Tau = 0.115; Pan =  0.18 },
            @{ Start = 0.130; Freq = 987.77;  Gain = 0.90; Tau = 0.115; Pan = -0.12 },
            @{ Start = 0.205; Freq = 1174.66; Gain = 1.00; Tau = 0.170; Pan =  0.00 }
        ))
    }
)

foreach ($spec in $packSpecs) {
    $wavPath = Join-Path $tempDir ($spec.Name + ".wav")
    $oggPath = Join-Path $OutputDir ($spec.Name + ".ogg")
    Write-StereoWavFile -Path $wavPath -Left $spec.Data.Left -Right $spec.Data.Right -SampleRate 44100
    & $ffmpeg -y -hide_banner -loglevel error -i $wavPath -c:a libvorbis -q:a 7 -ar 44100 -ac 2 $oggPath
    if ($LASTEXITCODE -ne 0) {
        throw "FFmpeg encoding failed for $($spec.Name)"
    }
    Remove-Item -LiteralPath $wavPath -Force -ErrorAction SilentlyContinue
    Write-Host "[OGG OK] $oggPath" -ForegroundColor Green
}

Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
