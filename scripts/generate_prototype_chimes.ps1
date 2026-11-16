<#
.SYNOPSIS
    Synthesizes two 100% original, clean-room 44.1 kHz Stereo Vorbis .ogg chimes
    modelled on the crystalline glass-bell / plucked-harp acoustic profile of EX3.
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
        # RIFF header
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
        $bw.Write([int](36 + $dataSize))
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
        # fmt chunk
        $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
        $bw.Write([int]16)
        $bw.Write([int16]1)                    # PCM
        $bw.Write([int16]$channels)            # Stereo
        $bw.Write([int]$SampleRate)
        $bw.Write([int]($SampleRate * $channels * 2))
        $bw.Write([int16]($channels * 2))       # BlockAlign
        $bw.Write([int16]16)                   # BitsPerSample
        # data chunk
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
        [double]$Pan # -1.0 (L) to +1.0 (R)
    )
    $n = $Left.Length
    $startIdx = [int][Math]::Round($StartSec * $SampleRate)
    $twoPi = 2.0 * [Math]::PI
    $attackSec = 0.0028
    $detune = 0.0022 # +/- 0.22% micro-detuned stereo shimmer (~3.8 cents)

    # Constant-power pan
    $angle = ($Pan + 1.0) * 0.25 * [Math]::PI
    $gainL = $Gain * [Math]::Cos($angle)
    $gainR = $Gain * [Math]::Sin($angle)

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

        # Crisp crystalline glass-bell / harp-pluck partials
        $sigL = (
            1.00 * [Math]::Sin($twoPi * $Freq * $t) * $d1 +
            0.34 * [Math]::Sin($twoPi * (2.0 * $fL) * $t) * $d2 +
            0.14 * [Math]::Sin($twoPi * (3.0 * $fL) * $t) * $d3 +
            0.06 * [Math]::Sin($twoPi * (4.02 * $fL) * $t) * $d4
        )
        $sigR = (
            1.00 * [Math]::Sin($twoPi * $Freq * $t) * $d1 +
            0.34 * [Math]::Sin($twoPi * (2.0 * $fR) * $t) * $d2 +
            0.14 * [Math]::Sin($twoPi * (3.0 * $fR) * $t) * $d3 +
            0.06 * [Math]::Sin($twoPi * (4.02 * $fR) * $t) * $d4
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
        [double]$FadeOutSec = 0.045
    )
    $n = $Left.Length
    # Subtle stereo shimmer tap-delay (+140ms / +240ms) for lively crystalline air
    $dL1 = [int][Math]::Round(0.140 * $SampleRate)
    $dR1 = [int][Math]::Round(0.165 * $SampleRate)
    $dL2 = [int][Math]::Round(0.255 * $SampleRate)
    $dR2 = [int][Math]::Round(0.285 * $SampleRate)

    $copyL = $Left.Clone()
    $copyR = $Right.Clone()

    for ($i = 0; $i -lt $n; $i++) {
        if ($i -ge $dL1) { $Left[$i]  += 0.14 * $copyR[$i - $dL1] }
        if ($i -ge $dR1) { $Right[$i] += 0.14 * $copyL[$i - $dR1] }
        if ($i -ge $dL2) { $Left[$i]  += 0.07 * $copyL[$i - $dL2] }
        if ($i -ge $dR2) { $Right[$i] += 0.07 * $copyR[$i - $dR2] }
    }

    # Smooth raised-cosine fade-out to exact zero
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

function New-MentionWarmStereo {
    param([int]$SampleRate = 44100)
    $totalSec = 0.680
    $n = [int][Math]::Round($totalSec * $SampleRate)
    $left  = New-Object double[] $n
    $right = New-Object double[] $n

    # Crisp 3-note ascending G major crystalline arpeggio (G5 -> B5 -> D6)
    Add-CrystallineBellPluck -Left $left -Right $right -SampleRate $SampleRate -StartSec 0.000 -Freq 783.99  -Gain 0.85 -TauMain 0.130 -Pan -0.22
    Add-CrystallineBellPluck -Left $left -Right $right -SampleRate $SampleRate -StartSec 0.055 -Freq 987.77  -Gain 0.92 -TauMain 0.140 -Pan  0.00
    Add-CrystallineBellPluck -Left $left -Right $right -SampleRate $SampleRate -StartSec 0.115 -Freq 1174.66 -Gain 1.00 -TauMain 0.175 -Pan  0.22

    Apply-StereoTailAndFade -Left $left -Right $right -SampleRate $SampleRate -FadeOutSec 0.055
    Normalize-StereoPeakDbFS -Left $left -Right $right -TargetDbFS -6.0
    return @{ Left = $left; Right = $right }
}

function New-KeywordPulseStereo {
    param([int]$SampleRate = 44100)
    $totalSec = 0.440
    $n = [int][Math]::Round($totalSec * $SampleRate)
    $left  = New-Object double[] $n
    $right = New-Object double[] $n

    # Single-note sister chime in the same EX3 crystalline family at D5 (587.33 Hz)
    Add-CrystallineBellPluck -Left $left -Right $right -SampleRate $SampleRate -StartSec 0.000 -Freq 587.33 -Gain 1.00 -TauMain 0.125 -Pan 0.00

    Apply-StereoTailAndFade -Left $left -Right $right -SampleRate $SampleRate -FadeOutSec 0.045
    Normalize-StereoPeakDbFS -Left $left -Right $right -TargetDbFS -6.0
    return @{ Left = $left; Right = $right }
}

$ffmpeg = Resolve-FFmpeg
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "DynamicChatAudioProto"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$specs = @(
    @{ Name = "DynamicChat_MentionWarm";  Data = (New-MentionWarmStereo) },
    @{ Name = "DynamicChat_KeywordPulse"; Data = (New-KeywordPulseStereo) }
)

foreach ($spec in $specs) {
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
