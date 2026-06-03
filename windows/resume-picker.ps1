<#
=============================================================================
 resume-picker.ps1  --  Check-up "Riprendi il lavoro" per l'app Claude (Windows)
=============================================================================
 Finestra curata che elenca le tue sessioni Claude DIVISE per sezione
 (Chat / Cowork / Code), con caselle di spunta: scegli quali far ripartire.
 Le chat vecchie che non usi piu' restano ferme.

 Pulsanti:
   - Rileva bloccate : spunta da solo le sessioni davvero ferme per il limite.
   - Riprendi selezionate : apre ognuna e preme la ripresa al posto tuo.
   - Ricorda la selezione : ripropone le stesse spunte la volta dopo.

 SICUREZZA: clicca SOLO pulsanti di ripresa. Mai nulla che spenda denaro o
 cambi piano (Acquista crediti, Passa a Max, Aggiorna piano).

 Uso:
   powershell -ExecutionPolicy Bypass -File resume-picker.ps1
   powershell -ExecutionPolicy Bypass -File resume-picker.ps1 -ListOnly  (debug)

 Made in Italy.
=============================================================================
#>
[CmdletBinding()]
param([switch]$ListOnly)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$AE = [System.Windows.Automation.AutomationElement]

$SAFE_RESUME = @('continua a lavorare','continua il lavoro','riprova','riprendi','continue working','continue')
$NEVER_CLICK = @('acquist','passa a max','aggiorna il tuo piano','upgrade','paga','purchase','buy','piano')
$SESSION_STATE_RX = '^(In esecuzione|Inattivo|In pausa|In coda|Pronto|Completato|Annullato|Errore|Running|Idle|Paused|Queued|Ready|Completed|Cancelled|Error)\s+(.+)$'
$GROUPS = @('Chat','Cowork','Code')
$PrefFile = Join-Path $env:LOCALAPPDATA 'claude-ac\preferred-sessions.txt'

# --- Palette -----------------------------------------------------------------
$C_DARK   = [System.Drawing.Color]::FromArgb(17,21,28)
$C_PANEL  = [System.Drawing.Color]::FromArgb(247,248,250)
$C_CARD   = [System.Drawing.Color]::White
$C_TEXT   = [System.Drawing.Color]::FromArgb(17,21,28)
$C_MUTED  = [System.Drawing.Color]::FromArgb(120,128,140)
$C_GREEN  = [System.Drawing.Color]::FromArgb(0,146,70)
$C_RED    = [System.Drawing.Color]::FromArgb(206,43,55)
$C_ACCENT = [System.Drawing.Color]::FromArgb(0,146,70)
$F_TITLE  = New-Object System.Drawing.Font("Segoe UI",16,[System.Drawing.FontStyle]::Bold)
$F_SUB    = New-Object System.Drawing.Font("Segoe UI",9)
$F_GROUP  = New-Object System.Drawing.Font("Segoe UI",11,[System.Drawing.FontStyle]::Bold)
$F_ITEM   = New-Object System.Drawing.Font("Segoe UI",9.5)
$F_BTN    = New-Object System.Drawing.Font("Segoe UI",9.5,[System.Drawing.FontStyle]::Bold)

# --- UI Automation helpers ---------------------------------------------------
function Get-ClaudeWindow {
    $pids=@(Get-Process claude -ErrorAction SilentlyContinue|Where-Object{$_.Path -like '*WindowsApps*'}|Select-Object -ExpandProperty Id)
    if($pids.Count -eq 0){return $null}
    $c=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,[System.Windows.Automation.ControlType]::Window)
    foreach($w in $AE::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children,$c)){ if($pids -contains $w.Current.ProcessId){return $w} }
    return $null
}
function Test-Invokable($e){ try{$p=$null;return $e.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern,[ref]$p)}catch{return $false} }
function Invoke-Element($e){ try{$p=$e.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern);$p.Invoke();return $true}catch{ try{$p2=$e.GetCurrentPattern([System.Windows.Automation.LegacyIAccessiblePattern]::Pattern);$p2.DoDefaultAction();return $true}catch{return $false} } }
function Click-Tab($win,$name){
    $c=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,[System.Windows.Automation.ControlType]::Button)
    foreach($b in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants,$c)){ if((''+$b.Current.Name).Trim() -eq $name){ return (Invoke-Element $b) } }
    return $false
}
function Find-ResumeButton($win){
    if(-not $win){return $null}
    foreach($ct in @([System.Windows.Automation.ControlType]::Button,[System.Windows.Automation.ControlType]::Hyperlink)){
        $c=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,$ct)
        foreach($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants,$c)){
            $name=(''+$e.Current.Name).Trim(); if(-not $name){continue}
            $low=$name.ToLower(); $blk=$false; foreach($b in $NEVER_CLICK){if($low.Contains($b)){$blk=$true;break}}
            if($blk){continue}
            if($SAFE_RESUME -contains $low -and (Test-Invokable $e)){return $e}
        }
    }
    return $null
}
function Get-Sessions($win){
    $seen=@{}; $out=@()
    $c=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,[System.Windows.Automation.ControlType]::Button)
    foreach($b in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants,$c)){
        $n=(''+$b.Current.Name).Trim(); if(-not $n){continue}; if($n -like 'Altre opzioni*'){continue}
        $m=[regex]::Match($n,$SESSION_STATE_RX)
        if($m.Success){ $state=$m.Groups[1].Value; $title=$m.Groups[2].Value.Trim()
            if($title -and -not $seen.ContainsKey($title)){ $seen[$title]=$true; $out += [pscustomobject]@{Title=$title;State=$state} } }
    }
    return $out
}
function Open-SessionByTitle($win,$title){
    $c=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,[System.Windows.Automation.ControlType]::Button)
    foreach($b in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants,$c)){
        $n=(''+$b.Current.Name).Trim(); if(-not $n){continue}; if($n -like 'Altre opzioni*'){continue}
        if($n.EndsWith($title)){ return (Invoke-Element $b) }
    }
    return $false
}
# Raccoglie le sessioni da tutte le schede (Chat/Cowork/Code)
function Gather-All {
    $res=[ordered]@{}
    foreach($g in $GROUPS){
        $win=Get-ClaudeWindow; if(-not $win){ $res[$g]=@(); continue }
        [void](Click-Tab $win $g); Start-Sleep -Milliseconds 1200
        $win=Get-ClaudeWindow
        $res[$g]= if($win){ @(Get-Sessions $win) } else { @() }
    }
    return $res
}
function Resume-One($group,$title){
    $win=Get-ClaudeWindow; if(-not $win){return $false}
    [void](Click-Tab $win $group); Start-Sleep -Milliseconds 900; $win=Get-ClaudeWindow
    if(Open-SessionByTitle $win $title){ Start-Sleep -Milliseconds 1500; $win=Get-ClaudeWindow
        $btn=Find-ResumeButton $win; if($btn){ if(Invoke-Element $btn){ Start-Sleep -Seconds 2; return $true } } }
    return $false
}
function Test-Blocked($group,$title){
    $win=Get-ClaudeWindow; if(-not $win){return $false}
    [void](Click-Tab $win $group); Start-Sleep -Milliseconds 900; $win=Get-ClaudeWindow
    if(Open-SessionByTitle $win $title){ Start-Sleep -Milliseconds 1200; $win=Get-ClaudeWindow; return [bool](Find-ResumeButton $win) }
    return $false
}
function Toast($t,$x){ try{ $n=New-Object System.Windows.Forms.NotifyIcon; $n.Icon=[System.Drawing.SystemIcons]::Information; $n.Visible=$true; $n.ShowBalloonTip(6000,$t,$x,'Info'); Start-Sleep -Milliseconds 6500; $n.Dispose() }catch{} }

# ----------------------------------------------------------------------------
$win = Get-ClaudeWindow
if(-not $win){ Toast "Claude non trovato" "L'app desktop Claude non risulta aperta."; return }

$data = Gather-All
$total = 0; foreach($g in $GROUPS){ $total += $data[$g].Count }

if($ListOnly){
    foreach($g in $GROUPS){ Write-Output ("== {0} ({1}) ==" -f $g,$data[$g].Count); foreach($s in $data[$g]){ Write-Output ("   [{0}] {1}" -f $s.State,$s.Title) } }
    return
}
if($total -eq 0){ Toast "Nessuna sessione" "Non ho trovato sessioni nelle schede Chat/Cowork/Code."; return }

# selezione ricordata (righe "Group|Title")
$remembered=@{}
if(Test-Path $PrefFile){ foreach($l in (Get-Content $PrefFile -Encoding utf8)){ $t=$l.Trim(); if($t){ $remembered[$t]=$true } } }

# ============================ FINESTRA (stile) ==============================
$form=New-Object System.Windows.Forms.Form
$form.Text="Claude - Riprendi il lavoro"
$form.Size=New-Object System.Drawing.Size(600,660)
$form.StartPosition="CenterScreen"; $form.TopMost=$true
$form.FormBorderStyle="FixedSingle"; $form.MaximizeBox=$false; $form.MinimizeBox=$false
$form.BackColor=$C_PANEL; $form.Font=$F_ITEM

# ---- Header scuro ----
$header=New-Object System.Windows.Forms.Panel
$header.Dock="Top"; $header.Height=92; $header.BackColor=$C_DARK
$form.Controls.Add($header)
$title=New-Object System.Windows.Forms.Label
$title.Text="Riprendi il lavoro"; $title.Font=$F_TITLE; $title.ForeColor=[System.Drawing.Color]::White
$title.AutoSize=$true; $title.Location=New-Object System.Drawing.Point(22,18); $header.Controls.Add($title)
$sub=New-Object System.Windows.Forms.Label
$sub.Text="Scegli quali conversazioni far ripartire quando i crediti tornano."
$sub.Font=$F_SUB; $sub.ForeColor=[System.Drawing.Color]::FromArgb(170,178,190)
$sub.AutoSize=$true; $sub.Location=New-Object System.Drawing.Point(24,54); $header.Controls.Add($sub)
# tricolore in fondo all'header
$tri=@($C_GREEN,[System.Drawing.Color]::White,$C_RED)
for($i=0;$i -lt 3;$i++){ $p=New-Object System.Windows.Forms.Panel; $p.Height=4; $p.Width=200; $p.Top=88; $p.Left=($i*200); $p.BackColor=$tri[$i]; $header.Controls.Add($p) }

# ---- Footer ----
$footer=New-Object System.Windows.Forms.Panel
$footer.Dock="Bottom"; $footer.Height=96; $footer.BackColor=$C_CARD
$form.Controls.Add($footer)
$sep=New-Object System.Windows.Forms.Panel; $sep.Dock="Top"; $sep.Height=1; $sep.BackColor=[System.Drawing.Color]::FromArgb(225,228,233); $footer.Controls.Add($sep)

$chkRemember=New-Object System.Windows.Forms.CheckBox
$chkRemember.Text="Ricorda la mia selezione"; $chkRemember.AutoSize=$true; $chkRemember.ForeColor=$C_TEXT
$chkRemember.Location=New-Object System.Drawing.Point(20,14); if($remembered.Count -gt 0){$chkRemember.Checked=$true}; $footer.Controls.Add($chkRemember)

$status=New-Object System.Windows.Forms.Label
$status.AutoSize=$true; $status.ForeColor=$C_MUTED; $status.Location=New-Object System.Drawing.Point(20,40); $footer.Controls.Add($status)

$madein=New-Object System.Windows.Forms.Label
$madein.Text="Made in Italy"; $madein.AutoSize=$true; $madein.ForeColor=$C_MUTED; $madein.Font=$F_SUB
$madein.Location=New-Object System.Drawing.Point(20,66); $footer.Controls.Add($madein)
for($i=0;$i -lt 3;$i++){ $p=New-Object System.Windows.Forms.Panel; $p.Size=New-Object System.Drawing.Size(10,12); $p.Top=66; $p.Left=(96+$i*11); $p.BackColor=$tri[$i]; if($i -eq 1){$p.BorderStyle="FixedSingle"}; $footer.Controls.Add($p) }

function New-StyledButton($text,$primary){
    $b=New-Object System.Windows.Forms.Button; $b.Text=$text; $b.Font=$F_BTN; $b.FlatStyle="Flat"; $b.Height=34; $b.Cursor="Hand"
    $b.FlatAppearance.BorderSize=0
    if($primary){ $b.BackColor=$C_ACCENT; $b.ForeColor=[System.Drawing.Color]::White }
    else { $b.BackColor=[System.Drawing.Color]::FromArgb(238,240,243); $b.ForeColor=$C_TEXT }
    return $b
}
$btnGo=New-StyledButton "Riprendi selezionate" $true; $btnGo.Width=168; $btnGo.Location=New-Object System.Drawing.Point(404,46); $footer.Controls.Add($btnGo)
$btnDetect=New-StyledButton "Rileva bloccate" $false; $btnDetect.Width=130; $btnDetect.Location=New-Object System.Drawing.Point(268,46); $footer.Controls.Add($btnDetect)
$btnAll=New-StyledButton "Tutte" $false; $btnAll.Width=64; $btnAll.Location=New-Object System.Drawing.Point(404,12); $footer.Controls.Add($btnAll)
$btnNone=New-StyledButton "Nessuna" $false; $btnNone.Width=80; $btnNone.Location=New-Object System.Drawing.Point(472,12); $footer.Controls.Add($btnNone)

# ---- Area centrale scrollabile con gruppi ----
$scroll=New-Object System.Windows.Forms.Panel
$scroll.Dock="Fill"; $scroll.AutoScroll=$true; $scroll.BackColor=$C_PANEL; $scroll.Padding=New-Object System.Windows.Forms.Padding(16,12,16,12)
$form.Controls.Add($scroll); $scroll.BringToFront()

$checkItems=New-Object System.Collections.Generic.List[object]
$y=8
$grpIcons=@{ Chat='Chat'; Cowork='Cowork'; Code='Code' }
foreach($g in $GROUPS){
    $items=$data[$g]
    # intestazione gruppo (card)
    $hd=New-Object System.Windows.Forms.Panel; $hd.Size=New-Object System.Drawing.Size(536,30); $hd.Location=New-Object System.Drawing.Point(8,$y); $hd.BackColor=$C_PANEL
    $bar=New-Object System.Windows.Forms.Panel; $bar.Size=New-Object System.Drawing.Size(4,20); $bar.Location=New-Object System.Drawing.Point(0,5); $bar.BackColor=$C_ACCENT; $hd.Controls.Add($bar)
    $hl=New-Object System.Windows.Forms.Label; $hl.Text=("{0}   ({1})" -f $g,$items.Count); $hl.Font=$F_GROUP; $hl.ForeColor=$C_TEXT; $hl.AutoSize=$true; $hl.Location=New-Object System.Drawing.Point(14,4); $hd.Controls.Add($hl)
    $scroll.Controls.Add($hd); $y+=34
    if($items.Count -eq 0){
        $em=New-Object System.Windows.Forms.Label; $em.Text="   (nessuna sessione in questa sezione)"; $em.ForeColor=$C_MUTED; $em.AutoSize=$true; $em.Location=New-Object System.Drawing.Point(18,$y); $scroll.Controls.Add($em); $y+=28; continue
    }
    foreach($s in $items){
        $card=New-Object System.Windows.Forms.Panel; $card.Size=New-Object System.Drawing.Size(536,38); $card.Location=New-Object System.Drawing.Point(8,$y); $card.BackColor=$C_CARD
        $cb=New-Object System.Windows.Forms.CheckBox; $cb.AutoSize=$false; $cb.Size=New-Object System.Drawing.Size(470,20); $cb.Location=New-Object System.Drawing.Point(12,9)
        $cb.Text=$s.Title; $cb.Font=$F_ITEM; $cb.ForeColor=$C_TEXT
        $key=("{0}|{1}" -f $g,$s.Title); if($remembered.ContainsKey($key)){ $cb.Checked=$true }
        $st=New-Object System.Windows.Forms.Label; $st.Text=$s.State; $st.AutoSize=$true; $st.Font=$F_SUB; $st.ForeColor=$C_MUTED; $st.Location=New-Object System.Drawing.Point(430,11)
        $card.Controls.Add($cb); $card.Controls.Add($st); $scroll.Controls.Add($card)
        $checkItems.Add([pscustomobject]@{ Cb=$cb; Group=$g; Title=$s.Title }) | Out-Null
        $y+=42
    }
    $y+=6
}
$status.Text=("{0} sessioni trovate in Chat/Cowork/Code." -f $total)

# ---- handlers ----
$btnAll.Add_Click({ foreach($it in $checkItems){ $it.Cb.Checked=$true } })
$btnNone.Add_Click({ foreach($it in $checkItems){ $it.Cb.Checked=$false } })
$btnDetect.Add_Click({
    $status.Text="Controllo in corso... apro le sessioni una a una."; $form.Refresh()
    $i=0
    foreach($it in $checkItems){ $i++
        try{ $it.Cb.Checked=(Test-Blocked $it.Group $it.Title) }catch{}
        $status.Text=("Controllo... {0}/{1}" -f $i,$checkItems.Count); $form.Refresh()
    }
    $n=0; foreach($it in $checkItems){ if($it.Cb.Checked){$n++} }
    $status.Text=("Trovate {0} sessioni bloccate (gia' spuntate)." -f $n)
})
$btnGo.Add_Click({ $form.Tag="GO"; $form.Close() })

[void]$form.ShowDialog()
if($form.Tag -ne "GO"){ return }

# selezione
$chosen=@(); foreach($it in $checkItems){ if($it.Cb.Checked){ $chosen += [pscustomobject]@{Group=$it.Group;Title=$it.Title} } }

# memoria
if($chkRemember.Checked){
    $dir=Split-Path $PrefFile; if(-not(Test-Path $dir)){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
    Set-Content -Path $PrefFile -Value ($chosen | ForEach-Object { "{0}|{1}" -f $_.Group,$_.Title }) -Encoding utf8
} elseif(Test-Path $PrefFile){ Remove-Item $PrefFile -Force }

if($chosen.Count -eq 0){ Toast "Nessuna selezione" "Non hai selezionato sessioni da riprendere."; return }

$ok=0; foreach($c in $chosen){ try{ if(Resume-One $c.Group $c.Title){ $ok++ } }catch{} }
Toast "Claude: ripresa completata" ("Riprese {0} di {1} sessioni selezionate." -f $ok,$chosen.Count)
