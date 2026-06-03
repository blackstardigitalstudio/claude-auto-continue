<#
=============================================================================
 make-banner.ps1  --  Genera banner.png (riproducibile)
=============================================================================
 Banner scuro stile "Officina Tricolore": marchio "C" verde, titolo, sottotitolo,
 piattaforme (Windows/macOS/Linux), Made in Italy, e un mockup terminale.
 Made in Italy.
=============================================================================
#>
param([string]$OutFile = (Join-Path (Split-Path $PSScriptRoot) 'banner.png'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing

$W=1280; $H=440
$bmp=New-Object System.Drawing.Bitmap($W,$H)
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='ClearTypeGridFit'
$dash=[char]0x2014; $dot=[char]0x00B7; $ell=[char]0x2026

$rect=New-Object System.Drawing.Rectangle(0,0,$W,$H)
$bg=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,[System.Drawing.Color]::FromArgb(13,17,24),[System.Drawing.Color]::FromArgb(9,12,18),90)
$g.FillRectangle($bg,$rect)
$glow=New-Object System.Drawing.Drawing2D.GraphicsPath; $glow.AddEllipse(-200,-260,900,700)
$pgb=New-Object System.Drawing.Drawing2D.PathGradientBrush($glow)
$pgb.CenterColor=[System.Drawing.Color]::FromArgb(40,30,60,90); $pgb.SurroundColors=@([System.Drawing.Color]::FromArgb(0,0,0,0))
$g.FillPath($pgb,$glow)

# seam tricolore verticale
$seam=New-Object System.Drawing.Rectangle(64,92,8,256)
$cb=New-Object System.Drawing.Drawing2D.ColorBlend(3)
$cb.Colors=@([System.Drawing.Color]::FromArgb(0,146,70),[System.Drawing.Color]::White,[System.Drawing.Color]::FromArgb(206,43,55))
$cb.Positions=@(0.0,0.5,1.0)
$sb=New-Object System.Drawing.Drawing2D.LinearGradientBrush($seam,[System.Drawing.Color]::White,[System.Drawing.Color]::White,90)
$sb.InterpolationColors=$cb
$g.FillRectangle($sb,$seam)

# marchio "C" verde a freccia
$green=[System.Drawing.Color]::FromArgb(43,212,107)
$cx=150; $cy=188; $rad=52
$pen=New-Object System.Drawing.Pen($green,16); $pen.StartCap='Round'; $pen.EndCap='Round'
$g.DrawArc($pen, ($cx-$rad),($cy-$rad),($rad*2),($rad*2), 45, 270)
$tip=@((New-Object System.Drawing.PointF(($cx+8),($cy-$rad-12))),(New-Object System.Drawing.PointF(($cx+$rad+6),($cy-$rad+18))),(New-Object System.Drawing.PointF(($cx+10),($cy-$rad+30))))
$g.FillPolygon((New-Object System.Drawing.SolidBrush($green)),$tip)

$white=[System.Drawing.Color]::FromArgb(242,244,247); $gray=[System.Drawing.Color]::FromArgb(138,147,160)
$fTitle=New-Object System.Drawing.Font("Segoe UI",54,[System.Drawing.FontStyle]::Bold)
$fSub=New-Object System.Drawing.Font("Segoe UI",21,[System.Drawing.FontStyle]::Italic)
$fTag=New-Object System.Drawing.Font("Consolas",15)
$fMade=New-Object System.Drawing.Font("Consolas",13)
$g.DrawString("claude-ac",$fTitle,(New-Object System.Drawing.SolidBrush($white)),232,120)
$g.DrawString("Auto-Continue per Claude",$fSub,(New-Object System.Drawing.SolidBrush($gray)),238,210)
$g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(42,47,58),1)),240,256,640,256)
$g.DrawString("MIT   $dot   Windows   $dot   macOS   $dot   Linux",$fTag,(New-Object System.Drawing.SolidBrush($gray)),240,272)
$tx=240; $ty=312
$cols=@([System.Drawing.Color]::FromArgb(0,146,70),[System.Drawing.Color]::White,[System.Drawing.Color]::FromArgb(206,43,55))
for($i=0;$i -lt 3;$i++){ $g.FillRectangle((New-Object System.Drawing.SolidBrush($cols[$i])),($tx+$i*13),$ty,12,16) }
$g.DrawString("Made in Italy $dash Blackstar Digital Studio",$fMade,(New-Object System.Drawing.SolidBrush($gray)),($tx+48),($ty+1))

function RoundRect($gr,$x,$y,$w,$h,$r,$brush){ $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddArc($x,$y,$r,$r,180,90); $p.AddArc($x+$w-$r,$y,$r,$r,270,90); $p.AddArc($x+$w-$r,$y+$h-$r,$r,$r,0,90); $p.AddArc($x,$y+$h-$r,$r,$r,90,90); $p.CloseFigure(); $gr.FillPath($brush,$p); return $p }
$cardX=712;$cardY=96;$cardW=496;$cardH=250
$p=RoundRect $g $cardX $cardY $cardW $cardH 18 (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(17,22,31)))
$g.DrawPath((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(38,44,56),1)),$p)
$dots=@([System.Drawing.Color]::FromArgb(237,106,94),[System.Drawing.Color]::FromArgb(245,191,79),[System.Drawing.Color]::FromArgb(98,197,84))
for($i=0;$i -lt 3;$i++){ $g.FillEllipse((New-Object System.Drawing.SolidBrush($dots[$i])),(734+$i*20),118,11,11) }
$fHdr=New-Object System.Drawing.Font("Consolas",12)
$g.DrawString("zsh $dash auto-continue",$fHdr,(New-Object System.Drawing.SolidBrush($gray)),1030,116)
$fMono=New-Object System.Drawing.Font("Consolas",16)
$amber=[System.Drawing.Color]::FromArgb(232,179,57); $blue=[System.Drawing.Color]::FromArgb(96,165,250)
$lx=752; $ly=162; $lh=42
$g.DrawString("$",$fMono,(New-Object System.Drawing.SolidBrush($green)),730,$ly)
$g.DrawString("claude-ac",$fMono,(New-Object System.Drawing.SolidBrush($green)),$lx,$ly)
$g.DrawString("`"build me an app`"",$fMono,(New-Object System.Drawing.SolidBrush($white)),($lx+104),$ly)
$ly2=$ly+$lh
$g.FillRectangle((New-Object System.Drawing.SolidBrush($amber)),731,($ly2+3),4,15); $g.FillRectangle((New-Object System.Drawing.SolidBrush($amber)),739,($ly2+3),4,15)
$g.DrawString("usage limit $dash resume 14:30",$fMono,(New-Object System.Drawing.SolidBrush($amber)),$lx,$ly2)
$ly3=$ly2+$lh
$pen2=New-Object System.Drawing.Pen($blue,3); $g.DrawArc($pen2,730,($ly3+2),16,16,30,270)
$g.DrawString("resuming session$ell",$fMono,(New-Object System.Drawing.SolidBrush($gray)),$lx,$ly3)
$ly4=$ly3+$lh
$penc=New-Object System.Drawing.Pen($green,3); $penc.StartCap='Round'; $penc.EndCap='Round'
$g.DrawLines($penc,@((New-Object System.Drawing.PointF(730,($ly4+10))),(New-Object System.Drawing.PointF(736,($ly4+16))),(New-Object System.Drawing.PointF(746,($ly4+3)))))
$g.DrawString("done.",$fMono,(New-Object System.Drawing.SolidBrush($green)),$lx,$ly4)
$g.DrawString(" nothing lost.",$fMono,(New-Object System.Drawing.SolidBrush($white)),($lx+58),$ly4)

$g.Dispose()
$bmp.Save($OutFile,[System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Host ("Banner creato: " + $OutFile)
