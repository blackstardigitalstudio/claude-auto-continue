<#
=============================================================================
 make-demo-gif.ps1  --  Genera la GIF demo (animata) di claude-ac
=============================================================================
 Riproduce lo storyboard: comando -> lavoro -> limite (la perdita) -> attesa
 -> ripresa automatica (il picco) -> fatto. Loop infinito.

 Niente strumenti esterni: i frame sono disegnati con System.Drawing e
 assemblati in GIF animata con l'encoder GIF di WPF + iniezione di loop e tempi.

 Uso: powershell -ExecutionPolicy Bypass -File make-demo-gif.ps1
 Made in Italy.
=============================================================================
#>
param([string]$OutFile = (Join-Path (Split-Path $PSScriptRoot) 'claude-ac-demo.gif'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$W=1120; $H=500
# palette
$bg=[System.Drawing.Color]::FromArgb(14,17,23)
$card=[System.Drawing.Color]::FromArgb(17,22,31)
$white=[System.Drawing.Color]::FromArgb(230,232,236)
$gray=[System.Drawing.Color]::FromArgb(138,147,160)
$green=[System.Drawing.Color]::FromArgb(43,212,107)
$red=[System.Drawing.Color]::FromArgb(255,92,87)
$amber=[System.Drawing.Color]::FromArgb(232,179,57)
$blue=[System.Drawing.Color]::FromArgb(96,165,250)
$fMono=New-Object System.Drawing.Font("Consolas",18)
$fHdr=New-Object System.Drawing.Font("Consolas",14)

# linee (segmenti colorati). Ogni segmento: @{t=testo; c=colore}
function Seg($t,$c){ return @{ t=$t; c=$c } }
$L1=@((Seg '$ ' $green),(Seg 'claude-ac ' $green),(Seg '"build me a todo app"' $white))
$L2=@((Seg 'building...  ' $gray),(Seg '[#######   ]' $blue),(Seg '  generating components' $gray))
$L3=@((Seg 'usage limit reached - session stopped  ' $red),(Seg '[X]' $red))
$L4=@((Seg 'claude-ac: ' $amber),(Seg 'detected quota stop. waiting for reset...' $gray))
$L5=@((Seg 'reset detected - resuming the SAME session...' $green))
$L6=@((Seg '[##########]  ' $green),(Seg 'done. todo app ready  ' $white),(Seg '[OK]' $green))

# ArrayList.Add NON appiattisce: ogni elemento resta una "riga" (array di segmenti)
$allLines=New-Object System.Collections.ArrayList
[void]$allLines.Add($L1); [void]$allLines.Add($L2); [void]$allLines.Add($L3)
[void]$allLines.Add($L4); [void]$allLines.Add($L5); [void]$allLines.Add($L6)
$counts=@(1,2,3,4,5,6)             # quante righe mostra ogni frame (cumulativo)
$delays=@(90,90,110,130,120,230)  # centesimi di secondo

function RoundRect($gr,$x,$y,$w,$h,$r,$brush){ $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddArc($x,$y,$r,$r,180,90); $p.AddArc($x+$w-$r,$y,$r,$r,270,90); $p.AddArc($x+$w-$r,$y+$h-$r,$r,$r,0,90); $p.AddArc($x,$y+$h-$r,$r,$r,90,90); $p.CloseFigure(); $gr.FillPath($brush,$p) }

function Render-Frame($n){
  $bmp=New-Object System.Drawing.Bitmap($W,$H)
  $g=[System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAliasGridFit'
  $g.Clear($bg)
  RoundRect $g 40 40 ($W-80) ($H-80) 22 (New-Object System.Drawing.SolidBrush($card))
  # header
  $dots=@($red,$amber,$green)
  for($i=0;$i -lt 3;$i++){ $g.FillEllipse((New-Object System.Drawing.SolidBrush($dots[$i])),(70+$i*22),66,12,12) }
  $g.DrawString("claude-ac : auto-continue demo",$fHdr,(New-Object System.Drawing.SolidBrush($gray)),($W-360),62)
  # linee (prime $n righe). StringFormat di default: gli spazi vengono preservati.
  $y=120
  for($li=0;$li -lt $n;$li++){
    $line=$allLines[$li]
    $x=72.0
    foreach($s in $line){
      $g.DrawString($s.t,$fMono,(New-Object System.Drawing.SolidBrush($s.c)),$x,$y)
      $x += $g.MeasureString($s.t,$fMono).Width - 2
    }
    $y += 46
  }
  $g.Dispose()
  return $bmp
}

# 1) costruisci i frame e l'encoder GIF (WPF) -> bytes senza loop/tempi
function To-Frame($bmp){
  $ms=New-Object System.IO.MemoryStream
  $bmp.Save($ms,[System.Drawing.Imaging.ImageFormat]::Png); $ms.Position=0
  $dec=[System.Windows.Media.Imaging.PngBitmapDecoder]::new($ms,[System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
  return $dec.Frames[0]
}
$enc=New-Object System.Windows.Media.Imaging.GifBitmapEncoder
foreach($n in $counts){ $bmp=Render-Frame $n; $enc.Frames.Add((To-Frame $bmp)); $bmp.Dispose() }
$ms2=New-Object System.IO.MemoryStream; $enc.Save($ms2); $bytes=$ms2.ToArray()

# 2) inietta NETSCAPE loop + Graphic Control Extension (tempi) per frame
$out=New-Object System.Collections.Generic.List[byte]
# header(6) + LSD(7)
for($k=0;$k -lt 13;$k++){ $out.Add($bytes[$k]) }
$packed=$bytes[10]
$o=13
if(($packed -band 0x80) -ne 0){ $gctLen=3*[int][math]::Pow(2,($packed -band 0x07)+1); for($k=0;$k -lt $gctLen;$k++){ $out.Add($bytes[13+$k]) }; $o=13+$gctLen }
# NETSCAPE2.0 loop infinito
$ns=@(0x21,0xFF,0x0B) + ([System.Text.Encoding]::ASCII.GetBytes("NETSCAPE2.0")) + @(0x03,0x01,0x00,0x00,0x00)
foreach($b in $ns){ $out.Add([byte]$b) }

$fi=0
$i=$o
while($i -lt $bytes.Length){
  $b=$bytes[$i]
  if($b -eq 0x3B){ $out.Add(0x3B); break }
  elseif($b -eq 0x21){
    $label=$bytes[$i+1]; $start=$i; $i+=2
    while($bytes[$i] -ne 0){ $i += $bytes[$i]+1 }
    $i+=1
    if($label -ne 0xF9){ for($k=$start;$k -lt $i;$k++){ $out.Add($bytes[$k]) } }  # scarta i GCE esistenti
  }
  elseif($b -eq 0x2C){
    # mio GCE col tempo del frame
    $d=$delays[[math]::Min($fi,$delays.Length-1)]; $fi++
    $dl=[byte]($d -band 0xFF); $dh=[byte](($d -shr 8) -band 0xFF)
    foreach($x in @(0x21,0xF9,0x04,0x04,$dl,$dh,0x00,0x00)){ $out.Add([byte]$x) }
    $start=$i; $imgPacked=$bytes[$start+9]; $i=$start+10
    if(($imgPacked -band 0x80) -ne 0){ $lct=3*[int][math]::Pow(2,($imgPacked -band 0x07)+1); $i+=$lct }
    $i+=1  # min code size
    while($bytes[$i] -ne 0){ $i += $bytes[$i]+1 }
    $i+=1
    for($k=$start;$k -lt $i;$k++){ $out.Add($bytes[$k]) }
  }
  else { $out.Add($bytes[$i]); $i++ }
}

[System.IO.File]::WriteAllBytes($OutFile,$out.ToArray())
Write-Host ("GIF creata: " + $OutFile + "  (" + [math]::Round((Get-Item $OutFile).Length/1KB,1) + " KB, " + $counts.Count + " frame)")
