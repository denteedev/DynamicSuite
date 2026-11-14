<#
.SYNOPSIS
    Exports DynamicSuite / module SVG emblems to 400x400 CurseForge PNGs and optional 32-bit RGBA .tga icons.

.DESCRIPTION
    Pure-PowerShell + .NET System.Drawing rasterizer (zero external dependencies).
    Reads canonical 24x24 viewBox SVGs from Design\Logos\<Module>.svg (or -SvgPath)
    with 4x supersampling + HighQualityBicubic downsampling.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\export_logo.ps1 -Module DynamicMarker
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\export_logo.ps1 -Module All -ExportTga
#>
[CmdletBinding()]
param(
    [string] $Module    = "DynamicMarker",
    [string] $SvgPath   = "",
    [string] $OutDir    = "",
    [int]    $Size      = 400,
    [switch] $ExportTga,
    [string] $TgaOutDir = "",
    [int]    $TgaSize   = 64
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $OutDir)    { $OutDir    = Join-Path $RepoRoot "Marketing" }
if (-not $TgaOutDir) { $TgaOutDir = Join-Path $OutDir "TGA" }

$AllModules = @(
    "DynamicSuite", "DynamicLoad", "DynamicPrep", "DynamicMarker",
    "DynamicZoom", "DynamicFPS", "DynamicGroup", "DynamicBags", "DynamicChat"
)

function Parse-HexColor {
    param([string]$Hex, [double]$Opacity = 1.0)
    if ([string]::IsNullOrWhiteSpace($Hex) -or $Hex -ieq "none") { return $null }
    $h = $Hex.Trim().TrimStart('#')
    if ($h.Length -eq 3) {
        $h = "$($h[0])$($h[0])$($h[1])$($h[1])$($h[2])$($h[2])"
    }
    if ($h.Length -ne 6) {
        throw "Unsupported hex colour: $Hex"
    }
    $r = [Convert]::ToInt32($h.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($h.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($h.Substring(4, 2), 16)
    $a = [Math]::Max(0, [Math]::Min(255, [int][Math]::Round($Opacity * 255.0)))
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

function New-RoundedRectPath {
    param([float]$x, [float]$y, [float]$w, [float]$h, [float]$rx)
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    if ($rx -le 0.01) {
        $gp.AddRectangle([System.Drawing.RectangleF]::new($x, $y, $w, $h))
        return $gp
    }
    $d = [Math]::Min($rx * 2.0, [Math]::Min($w, $h))
    $gp.AddArc($x, $y, $d, $d, 180, 90)
    $gp.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $gp.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $gp.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $gp.CloseFigure()
    return $gp
}

function New-SvgPathGeometry {
    param([string]$D, [float]$Scale)
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath([System.Drawing.Drawing2D.FillMode]::Alternate)
    $tokens = [regex]::Matches($D, '[A-Za-z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?') | ForEach-Object { $_.Value }

    $idx = 0
    $cmd = ""
    $cx = [float]0; $cy = [float]0
    $sx = [float]0; $sy = [float]0
    $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]

    while ($idx -lt $tokens.Count) {
        $tok = $tokens[$idx]
        if ($tok -match '^[A-Za-z]$') {
            $cmd = $tok
            $idx++
            if ($cmd -ceq 'Z' -or $cmd -ceq 'z') {
                if ($pts.Count -ge 2) {
                    $gp.AddPolygon($pts.ToArray())
                    $pts.Clear()
                }
                $cx = $sx; $cy = $sy
                continue
            }
        }

        switch ($cmd) {
            'M' {
                if ($pts.Count -ge 2) {
                    $gp.AddPolygon($pts.ToArray())
                    $pts.Clear()
                }
                $cx = [float]([double]$tokens[$idx] * $Scale); $idx++
                $cy = [float]([double]$tokens[$idx] * $Scale); $idx++
                $sx = $cx; $sy = $cy
                $pts.Add([System.Drawing.PointF]::new($cx, $cy))
                $cmd = 'L'
            }
            'L' {
                $cx = [float]([double]$tokens[$idx] * $Scale); $idx++
                $cy = [float]([double]$tokens[$idx] * $Scale); $idx++
                $pts.Add([System.Drawing.PointF]::new($cx, $cy))
            }
            'H' {
                $cx = [float]([double]$tokens[$idx] * $Scale); $idx++
                $pts.Add([System.Drawing.PointF]::new($cx, $cy))
            }
            'V' {
                $cy = [float]([double]$tokens[$idx] * $Scale); $idx++
                $pts.Add([System.Drawing.PointF]::new($cx, $cy))
            }
            'C' {
                $x1 = [float]([double]$tokens[$idx] * $Scale); $idx++
                $y1 = [float]([double]$tokens[$idx] * $Scale); $idx++
                $x2 = [float]([double]$tokens[$idx] * $Scale); $idx++
                $y2 = [float]([double]$tokens[$idx] * $Scale); $idx++
                $x3 = [float]([double]$tokens[$idx] * $Scale); $idx++
                $y3 = [float]([double]$tokens[$idx] * $Scale); $idx++
                if ($pts.Count -ge 2) {
                    $gp.AddPolygon($pts.ToArray())
                    $pts.Clear()
                }
                $gp.AddBezier($cx, $cy, $x1, $y1, $x2, $y2, $x3, $y3)
                $cx = $x3; $cy = $y3
            }
            default {
                throw "Unsupported SVG path command '$cmd' in path '$D'"
            }
        }
    }
    if ($pts.Count -ge 2) {
        $gp.AddPolygon($pts.ToArray())
    }
    return $gp
}

function Render-SvgToBitmap {
    param(
        [xml]      $SvgXml,
        [int]      $OutSize,
        [string[]] $AllowedLayers = @(),
        [switch]   $ForceWhiteFill
    )

    $vb = $SvgXml.svg.GetAttribute("viewBox")
    $vbParts = ($vb -split '\s+') | Where-Object { $_ -ne '' }
    $vbW = if ($vbParts.Count -ge 3) { [double]$vbParts[2] } else { 24.0 }

    $super = 4
    $hiSize = $OutSize * $super
    $scale = [float]($hiSize / $vbW)

    $hiBmp = New-Object System.Drawing.Bitmap($hiSize, $hiSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($hiBmp)
    try {
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        foreach ($node in $SvgXml.svg.ChildNodes) {
            if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
            $layer = $node.GetAttribute("data-layer")
            if ($AllowedLayers.Count -gt 0 -and -not ($AllowedLayers -contains $layer)) { continue }

            $fillAttr = $node.GetAttribute("fill")
            $fillOpAttr = $node.GetAttribute("fill-opacity")
            $fillOp = if ($fillOpAttr) { [double]$fillOpAttr } else { 1.0 }
            $fillColor = if ($ForceWhiteFill -and $fillAttr -and $fillAttr -ine "none") {
                [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
            } else {
                Parse-HexColor -Hex $fillAttr -Opacity $fillOp
            }

            $strokeAttr = $node.GetAttribute("stroke")
            $strokeOpAttr = $node.GetAttribute("stroke-opacity")
            $strokeOp = if ($strokeOpAttr) { [double]$strokeOpAttr } else { 1.0 }
            $strokeWidthAttr = $node.GetAttribute("stroke-width")
            $strokeW = if ($strokeWidthAttr) { [float]([double]$strokeWidthAttr * $scale) } else { [float]$scale }
            $strokeColor = Parse-HexColor -Hex $strokeAttr -Opacity $strokeOp

            $gp = $null
            try {
                switch ($node.LocalName) {
                    "rect" {
                        $rx = if ($node.GetAttribute("x")) { [float]([double]$node.GetAttribute("x") * $scale) } else { [float]0 }
                        $ry = if ($node.GetAttribute("y")) { [float]([double]$node.GetAttribute("y") * $scale) } else { [float]0 }
                        $rw = [float]([double]$node.GetAttribute("width") * $scale)
                        $rh = [float]([double]$node.GetAttribute("height") * $scale)
                        $rrx = if ($node.GetAttribute("rx")) { [float]([double]$node.GetAttribute("rx") * $scale) } else { [float]0 }
                        $gp = New-RoundedRectPath -x $rx -y $ry -w $rw -h $rh -rx $rrx
                    }
                    "path" {
                        $d = $node.GetAttribute("d")
                        $gp = New-SvgPathGeometry -D $d -Scale $scale
                    }
                    "circle" {
                        $ccx = [float]([double]$node.GetAttribute("cx") * $scale)
                        $ccy = [float]([double]$node.GetAttribute("cy") * $scale)
                        $cr  = [float]([double]$node.GetAttribute("r") * $scale)
                        $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
                        $gp.AddEllipse($ccx - $cr, $ccy - $cr, $cr * 2.0, $cr * 2.0)
                    }
                    "line" {
                        $x1 = [float]([double]$node.GetAttribute("x1") * $scale)
                        $y1 = [float]([double]$node.GetAttribute("y1") * $scale)
                        $x2 = [float]([double]$node.GetAttribute("x2") * $scale)
                        $y2 = [float]([double]$node.GetAttribute("y2") * $scale)
                        $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
                        $gp.AddLine($x1, $y1, $x2, $y2)
                    }
                }

                if ($gp) {
                    if ($fillColor) {
                        $br = New-Object System.Drawing.SolidBrush($fillColor)
                        try { $g.FillPath($br, $gp) } finally { $br.Dispose() }
                    }
                    if ($strokeColor) {
                        $pen = New-Object System.Drawing.Pen($strokeColor, $strokeW)
                        $pen.Alignment = [System.Drawing.Drawing2D.PenAlignment]::Inset
                        try { $g.DrawPath($pen, $gp) } finally { $pen.Dispose() }
                    }
                }
            } finally {
                if ($gp) { $gp.Dispose() }
            }
        }
    } finally {
        $g.Dispose()
    }

    $outBmp = New-Object System.Drawing.Bitmap($OutSize, $OutSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $og = [System.Drawing.Graphics]::FromImage($outBmp)
    try {
        $og.Clear([System.Drawing.Color]::Transparent)
        $og.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $og.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $og.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $og.DrawImage($hiBmp, 0, 0, $OutSize, $OutSize)
    } finally {
        $og.Dispose()
        $hiBmp.Dispose()
    }
    return $outBmp
}

function Write-UncompressedTga32 {
    param(
        [System.Drawing.Bitmap] $Bitmap,
        [string] $OutPath
    )
    $w = $Bitmap.Width
    $h = $Bitmap.Height
    if (($w -band ($w - 1)) -ne 0 -or ($h -band ($h - 1)) -ne 0) {
        throw "TGA dimensions must be power-of-two (got ${w}x${h})."
    }

    $rect = [System.Drawing.Rectangle]::new(0, 0, $w, $h)
    $data = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $byteCount = [Math]::Abs($data.Stride) * $h
        $pixels = New-Object byte[] $byteCount
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $pixels, 0, $byteCount)

        $header = New-Object byte[] 18
        $header[2]  = 2                                 # Uncompressed TrueColor
        $header[12] = [byte]($w -band 0xFF)
        $header[13] = [byte](($w -shr 8) -band 0xFF)
        $header[14] = [byte]($h -band 0xFF)
        $header[15] = [byte](($h -shr 8) -band 0xFF)
        $header[16] = 32                                # 32-bit BGRA
        $header[17] = 0x28                              # Top-left origin, 8-bit alpha

        $fs = [System.IO.File]::Create($OutPath)
        try {
            $fs.Write($header, 0, 18)
            $fs.Write($pixels, 0, $byteCount)
        } finally {
            $fs.Dispose()
        }
    } finally {
        $Bitmap.UnlockBits($data)
    }
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$targets = if ($Module -ieq "All") { $AllModules } else { @($Module) }

foreach ($mod in $targets) {
    $srcSvg = if ($SvgPath -and $targets.Count -eq 1) {
        $SvgPath
    } else {
        Join-Path $RepoRoot "Design\Logos\$mod.svg"
    }
    if (-not (Test-Path -LiteralPath $srcSvg)) {
        throw "SVG not found for '$mod': $srcSvg"
    }

    [xml]$xml = Get-Content -LiteralPath $srcSvg -Raw
    $pngPath = Join-Path $OutDir "${mod}_CurseForge_Logo_${Size}x${Size}.png"
    $bmp = Render-SvgToBitmap -SvgXml $xml -OutSize $Size
    try {
        $bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bmp.Dispose()
    }
    Write-Host "[EXPORT PNG] $pngPath (${Size}x${Size})" -ForegroundColor Green

    if ($ExportTga) {
        New-Item -ItemType Directory -Path $TgaOutDir -Force | Out-Null
        $tgaFull = Join-Path $TgaOutDir "${mod}_icon_${TgaSize}.tga"
        $bFull = Render-SvgToBitmap -SvgXml $xml -OutSize $TgaSize
        try { Write-UncompressedTga32 -Bitmap $bFull -OutPath $tgaFull } finally { $bFull.Dispose() }

        $tgaW = Join-Path $TgaOutDir "${mod}_white_${TgaSize}.tga"
        $bW = Render-SvgToBitmap -SvgXml $xml -OutSize $TgaSize -AllowedLayers @("white")
        try { Write-UncompressedTga32 -Bitmap $bW -OutPath $tgaW } finally { $bW.Dispose() }

        $tgaA = Join-Path $TgaOutDir "${mod}_accent_${TgaSize}.tga"
        $bA = Render-SvgToBitmap -SvgXml $xml -OutSize $TgaSize -AllowedLayers @("accent") -ForceWhiteFill
        try { Write-UncompressedTga32 -Bitmap $bA -OutPath $tgaA } finally { $bA.Dispose() }

        Write-Host "[EXPORT TGA] $tgaFull, $tgaW, $tgaA (${TgaSize}x${TgaSize} 32-bit RGBA)" -ForegroundColor Cyan
    }
}
