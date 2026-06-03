<#
=============================================================================
 make-desktop-gif.ps1  --  GIF demo dell'APP DESKTOP (Windows)
=============================================================================
 Mostra il flusso reale dell'app: crediti finiti -> apri il check-up "Riprendi
 il lavoro" -> scegli le sessioni -> riprese -> Offrimi un caffe'. Loop.
 Stile fedele alla finestra vera (header scuro, tricolore, accento verde).
 Niente strumenti esterni. Made in Italy.
=============================================================================
#>
param([string]$OutFile = (Join-Path (Split-Path $PSScriptRoot) 'claude-ac-desktop.gif'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$W=1000; $H=620
# palette
$cBgDark=[System.Drawing.Color]::FromArgb(14,17,23)
$cHeader=[System.Drawing.Color]::FromArgb(17,21,28)
$cBody=[System.Drawing.Color]::FromArgb(247,248,250)
$cCard=[System.Drawing.Color]::White
$cText=[System.Drawing.Color]::FromArgb(17,21,28)
$cMuted=[System.Drawing.Color]::FromArgb(120,128,140)
$cGreen=[System.Drawing.Color]::FromArgb(0,160,75)
$cGreenBtn=[System.Drawing.Color]::FromArgb(0,146,70)
$cWhite=[System.Drawing.Color]::White
$cRed=[System.Drawing.Color]::FromArgb(206,43,55)
$tri=@($cGreenBtn,$cWhite,$cRed)

$fTitle=New-Object System.Drawing.Font("Segoe UI",21,[System.Drawing.FontStyle]::Bold)
$fSub=New-Object System.Drawing.Font("Segoe UI",10)
$fGroup=New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)
$fItem=New-Object System.Drawing.Font("Segoe UI",11)
$fState=New-Object System.Drawing.Font("Segoe UI",9)
$fBtn=New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$fCap=New-Object System.Drawing.Font("Segoe UI",13,[System.Drawing.FontStyle]::Bold)

# sessioni mostrate: @{g=gruppo; t=titolo; s=stato}
$rows=@(
  @{g='Chat'; t='Job search research'; s='Errore'},
  @{g='Code'; t='Kayamans Farm chatbot project'; s='Inattivo'},
  @{g='Code'; t='Claude skill debugging and republish'; s='Inattivo'},
  @{g='Code'; t='Daily interest notification app'; s='Inattivo'},
  @{g='Code'; t='Racing project website'; s='Inattivo'}
)
# indici da spuntare (le 3 Code principali)
$checkSet=@(1,2,3)

function RoundRect($gr,$x,$y,$w,$h,$r,$brush){ $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddArc($x,$y,$r,$r,180,90); $p.AddArc($x+$w-$r,$y,$r,$r,270,90); $p.AddArc($x+$w-$r,$y+$h-$r,$r,$r,0,90); $p.AddArc($x,$y+$h-$r,$r,$r,90,90); $p.CloseFigure(); $gr.FillPath($brush,$p); return $p }
function Brush($c){ return New-Object System.Drawing.SolidBrush($c) }

function Draw-Check($g,$x,$y,$checked){
  if($checked){
    RoundRect $g $x $y 20 20 5 (Brush $cGreenBtn) | Out-Null
    $pen=New-Object System.Drawing.Pen($cWhite,2.5); $pen.StartCap='Round'; $pen.EndCap='Round'
    $g.DrawLines($pen,@((New-Object System.Drawing.PointF(($x+5),($y+10))),(New-Object System.Drawing.PointF(($x+9),($y+14))),(New-Object System.Drawing.PointF(($x+15),($y+6)))))
  } else {
    RoundRect $g $x $y 20 20 5 (Brush ([System.Drawing.Color]::White)) | Out-Null
    $g.DrawPath((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(190,196,204),1.5)),(RoundRect $g $x $y 20 20 5 (Brush ([System.Drawing.Color]::White))))
  }
}

function Render-Desktop($numChecked,$pressed,$success){
  $bmp=New-Object System.Drawing.Bitmap($W,$H)
  $g=[System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAliasGridFit'
  $g.Clear($cBgDark)
  # caption in alto
  $cap = if($success){ "Riprese 3 sessioni - il lavoro continua da solo" } else { "Crediti finiti? Scegli le chat e riprendi con un clic" }
  $capCol = if($success){ $cGreen } else { [System.Drawing.Color]::FromArgb(200,206,214) }
  $g.DrawString($cap,$fCap,(Brush $capCol),48,16)

  # finestra
  $wx=210; $wy=58; $ww=580; $wh=520
  RoundRect $g $wx $wy $ww $wh 18 (Brush $cBody) | Out-Null
  # header scuro (top arrotondato): disegno rettangolo scuro e ricopro angoli bassi col body
  $hh=84
  RoundRect $g $wx $wy $ww $hh 18 (Brush $cHeader) | Out-Null
  $g.FillRectangle((Brush $cHeader),$wx,($wy+18),$ww,($hh-18))
  $g.DrawString("Riprendi il lavoro",$fTitle,(Brush $cWhite),($wx+24),($wy+16))
  $g.DrawString("Scegli quali conversazioni far ripartire",$fSub,(Brush ([System.Drawing.Color]::FromArgb(170,178,190))),($wx+26),($wy+52))
  for($i=0;$i -lt 3;$i++){ $g.FillRectangle((Brush $tri[$i]),($wx+$i*([int]($ww/3))),($wy+$hh-4),[int]($ww/3),4) }

  # corpo: gruppi + righe
  $y=$wy+$hh+14
  $lastGroup=""
  for($r=0;$r -lt $rows.Count;$r++){
    $row=$rows[$r]
    if($row.g -ne $lastGroup){
      $lastGroup=$row.g
      $cnt=($rows | Where-Object { $_.g -eq $row.g }).Count
      $g.FillRectangle((Brush $cGreenBtn),($wx+22),($y+3),4,18)
      $g.DrawString(("{0}   ({1})" -f $row.g,$cnt),$fGroup,(Brush $cText),($wx+34),$y)
      $y+=30
    }
    # card riga
    RoundRect $g ($wx+22) $y ($ww-44) 38 8 (Brush $cCard) | Out-Null
    $isChk = ($checkSet[0..([math]::Max(0,$numChecked-1))] -contains $r) -and ($numChecked -gt 0)
    Draw-Check $g ($wx+34) ($y+9) $isChk
    $g.DrawString($row.t,$fItem,(Brush $cText),($wx+66),($y+9))
    $g.DrawString($row.s,$fState,(Brush $cMuted),($wx+$ww-110),($y+11))
    $y+=44
  }

  # footer
  $fy=$wy+$wh-66
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(225,228,233),1)),($wx+1),$fy,($wx+$ww-1),$fy)
  # Made in Italy + bandiera
  $g.DrawString("Made in Italy",$fSub,(Brush $cMuted),($wx+24),($fy+34))
  $fb=$wx+118
  $g.FillRectangle((Brush $tri[0]),$fb,($fy+34),9,13); $g.FillRectangle((Brush $tri[1]),($fb+9),($fy+34),9,13); $g.FillRectangle((Brush $tri[2]),($fb+18),($fy+34),9,13)
  $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(210,214,220),1)),$fb,($fy+34),26,13)
  # pulsante "Riprendi selezionate"
  $btnCol = if($pressed){ [System.Drawing.Color]::FromArgb(0,120,58) } else { $cGreenBtn }
  $bw=200; $bx=$wx+$ww-$bw-24; $by=$fy+18
  RoundRect $g $bx $by $bw 38 8 (Brush $btnCol) | Out-Null
  $g.DrawString("Riprendi selezionate",$fBtn,(Brush $cWhite),($bx+22),($by+9))

  # overlay successo
  if($success){
    $ow=360; $ox=$wx+($ww-$ow)/2; $oy=$wy+($wh-72)/2
    RoundRect $g $ox $oy $ow 64 12 (Brush $cGreenBtn) | Out-Null
    $pen=New-Object System.Drawing.Pen($cWhite,4); $pen.StartCap='Round'; $pen.EndCap='Round'
    $g.DrawLines($pen,@((New-Object System.Drawing.PointF(($ox+28),($oy+34))),(New-Object System.Drawing.PointF(($ox+40),($oy+46))),(New-Object System.Drawing.PointF(($ox+60),($oy+20)))))
    $g.DrawString("Riprese 3 di 3 sessioni",$fGroup,(Brush $cWhite),($ox+80),($oy+20))
  }
  $g.Dispose()
  return $bmp
}

# frame: (numChecked, pressed, success), delay (centesimi)
$frames=@(
  @{n=0; p=$false; s=$false; d=120},
  @{n=1; p=$false; s=$false; d=45},
  @{n=2; p=$false; s=$false; d=45},
  @{n=3; p=$false; s=$false; d=70},
  @{n=3; p=$true;  s=$false; d=55},
  @{n=3; p=$true;  s=$true;  d=230}
)

function To-Frame($bmp){
  $ms=New-Object System.IO.MemoryStream
  $bmp.Save($ms,[System.Drawing.Imaging.ImageFormat]::Png); $ms.Position=0
  $dec=[System.Windows.Media.Imaging.PngBitmapDecoder]::new($ms,[System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
  return $dec.Frames[0]
}
$enc=New-Object System.Windows.Media.Imaging.GifBitmapEncoder
$delays=@()
foreach($f in $frames){ $bmp=Render-Desktop $f.n $f.p $f.s; $enc.Frames.Add((To-Frame $bmp)); $bmp.Dispose(); $delays+=$f.d }
$ms2=New-Object System.IO.MemoryStream; $enc.Save($ms2); $bytes=$ms2.ToArray()

# inietta loop + tempi
$out=New-Object System.Collections.Generic.List[byte]
for($k=0;$k -lt 13;$k++){ $out.Add($bytes[$k]) }
$packed=$bytes[10]; $o=13
if(($packed -band 0x80) -ne 0){ $gctLen=3*[int][math]::Pow(2,($packed -band 0x07)+1); for($k=0;$k -lt $gctLen;$k++){ $out.Add($bytes[13+$k]) }; $o=13+$gctLen }
$ns=@(0x21,0xFF,0x0B)+([System.Text.Encoding]::ASCII.GetBytes("NETSCAPE2.0"))+@(0x03,0x01,0x00,0x00,0x00)
foreach($b in $ns){ $out.Add([byte]$b) }
$fi=0; $i=$o
while($i -lt $bytes.Length){
  $b=$bytes[$i]
  if($b -eq 0x3B){ $out.Add(0x3B); break }
  elseif($b -eq 0x21){ $label=$bytes[$i+1]; $start=$i; $i+=2; while($bytes[$i] -ne 0){ $i+=$bytes[$i]+1 }; $i+=1; if($label -ne 0xF9){ for($k=$start;$k -lt $i;$k++){ $out.Add($bytes[$k]) } } }
  elseif($b -eq 0x2C){
    $d=$delays[[math]::Min($fi,$delays.Length-1)]; $fi++
    $dl=[byte]($d -band 0xFF); $dh=[byte](($d -shr 8) -band 0xFF)
    foreach($x in @(0x21,0xF9,0x04,0x04,$dl,$dh,0x00,0x00)){ $out.Add([byte]$x) }
    $start=$i; $imgPacked=$bytes[$start+9]; $i=$start+10
    if(($imgPacked -band 0x80) -ne 0){ $lct=3*[int][math]::Pow(2,($imgPacked -band 0x07)+1); $i+=$lct }
    $i+=1; while($bytes[$i] -ne 0){ $i+=$bytes[$i]+1 }; $i+=1
    for($k=$start;$k -lt $i;$k++){ $out.Add($bytes[$k]) }
  }
  else { $out.Add($bytes[$i]); $i++ }
}
[System.IO.File]::WriteAllBytes($OutFile,$out.ToArray())
Write-Host ("GIF desktop creata: " + $OutFile + "  (" + [math]::Round((Get-Item $OutFile).Length/1KB,1) + " KB, " + $frames.Count + " frame)")
