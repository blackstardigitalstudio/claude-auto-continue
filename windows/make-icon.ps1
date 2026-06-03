<#
=============================================================================
 make-icon.ps1  --  Genera l'icona claude-ac.ico (riproducibile)
=============================================================================
 Disegna l'icona: sfondo scuro (stile Claude) + freccia di ripresa verde a
 forma di "C" + banda tricolore. Salva claude-ac.ico (PNG 256x256 nell'ico).

 Made in Italy.
=============================================================================
#>
param([string]$OutFile = (Join-Path $PSScriptRoot 'claude-ac.ico'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing

$sz=256
$bmp=New-Object System.Drawing.Bitmap($sz,$sz)
$g=[System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode='AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)

$dark=[System.Drawing.Color]::FromArgb(17,21,28)
$path=New-Object System.Drawing.Drawing2D.GraphicsPath
$r=56;$x=8;$y=8;$w=240;$h=240
$path.AddArc($x,$y,$r,$r,180,90); $path.AddArc($x+$w-$r,$y,$r,$r,270,90)
$path.AddArc($x+$w-$r,$y+$h-$r,$r,$r,0,90); $path.AddArc($x,$y+$h-$r,$r,$r,90,90); $path.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush($dark)),$path)

$green=[System.Drawing.Color]::FromArgb(0,176,80)
$pen=New-Object System.Drawing.Pen($green,22); $pen.StartCap='Round'; $pen.EndCap='Round'
$g.DrawArc($pen,78,78,100,100,40,280)
$tip=@((New-Object System.Drawing.Point(150,66)),(New-Object System.Drawing.Point(198,86)),(New-Object System.Drawing.Point(168,116)))
$g.FillPolygon((New-Object System.Drawing.SolidBrush($green)),$tip)

$tg=[System.Drawing.Color]::FromArgb(0,146,70); $tw=[System.Drawing.Color]::White; $tr=[System.Drawing.Color]::FromArgb(206,43,55)
$by=196;$bh=20;$bx=78;$bw=100
$g.FillRectangle((New-Object System.Drawing.SolidBrush($tg)),$bx,$by,[int]($bw/3),$bh)
$g.FillRectangle((New-Object System.Drawing.SolidBrush($tw)),$bx+[int]($bw/3),$by,[int]($bw/3),$bh)
$g.FillRectangle((New-Object System.Drawing.SolidBrush($tr)),$bx+[int](2*$bw/3),$by,[int]($bw/3),$bh)
$g.Dispose()

$ms=New-Object System.IO.MemoryStream
$bmp.Save($ms,[System.Drawing.Imaging.ImageFormat]::Png)
$png=$ms.ToArray(); $ms.Dispose(); $bmp.Dispose()
$fs=New-Object System.IO.FileStream($OutFile,[System.IO.FileMode]::Create)
$bw2=New-Object System.IO.BinaryWriter($fs)
$bw2.Write([UInt16]0);$bw2.Write([UInt16]1);$bw2.Write([UInt16]1)
$bw2.Write([Byte]0);$bw2.Write([Byte]0);$bw2.Write([Byte]0);$bw2.Write([Byte]0)
$bw2.Write([UInt16]1);$bw2.Write([UInt16]32)
$bw2.Write([UInt32]$png.Length);$bw2.Write([UInt32]22)
$bw2.Write($png); $bw2.Flush(); $fs.Close()
Write-Host ("Icona creata: " + $OutFile)
