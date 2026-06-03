<#
=============================================================================
 resume-picker.ps1  --  Check-up + lista a spunta delle sessioni da riprendere
=============================================================================
 Mostra una finestra con l'elenco delle sessioni Claude e caselle di spunta:
 scegli TU quali riprendere (cosi' le chat vecchie che non usi piu' restano
 ferme). Poi clicca "Riprendi selezionate" e lo script apre ognuna e preme il
 pulsante di ripresa al posto tuo.

 In piu':
   - "Rileva bloccate": scorre le sessioni e spunta da solo quelle che hanno
     davvero un pulsante di ripresa (cioe' bloccate dal limite).
   - "Ricorda la selezione": ripropone le stesse spunte la volta dopo.

 SICUREZZA: clicca SOLO pulsanti di ripresa. Mai nulla che spenda denaro o
 cambi piano (Acquista crediti, Passa a Max, Aggiorna piano).

 Uso:
   powershell -ExecutionPolicy Bypass -File resume-picker.ps1
   powershell -ExecutionPolicy Bypass -File resume-picker.ps1 -ListOnly   # (debug)

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
$AE = [System.Windows.Automation.AutomationElement]

$SAFE_RESUME = @('continua a lavorare','continua il lavoro','riprova','riprendi','continue working','continue')
$NEVER_CLICK = @('acquist','passa a max','aggiorna il tuo piano','upgrade','paga','purchase','buy','piano')
$SESSION_STATE_RX = '^(In esecuzione|Inattivo|In pausa|In coda|Pronto|Completato|Annullato|Errore|Running|Idle|Paused|Queued|Ready|Completed|Cancelled|Error)\s+(.+)$'
$PrefFile = Join-Path $env:LOCALAPPDATA 'claude-ac\preferred-sessions.txt'

function Toast($t,$x){ try{ $n=New-Object System.Windows.Forms.NotifyIcon; $n.Icon=[System.Drawing.SystemIcons]::Information; $n.Visible=$true; $n.ShowBalloonTip(6000,$t,$x,'Info'); Start-Sleep -Milliseconds 6500; $n.Dispose() }catch{} }

function Get-ClaudeWindow {
    $pids=@(Get-Process claude -ErrorAction SilentlyContinue|Where-Object{$_.Path -like '*WindowsApps*'}|Select-Object -ExpandProperty Id)
    if($pids.Count -eq 0){return $null}
    $c=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,[System.Windows.Automation.ControlType]::Window)
    foreach($w in $AE::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children,$c)){ if($pids -contains $w.Current.ProcessId){return $w} }
    return $null
}
function Test-Invokable($e){ try{$p=$null;return $e.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern,[ref]$p)}catch{return $false} }
function Invoke-Element($e){ try{$p=$e.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern);$p.Invoke();return $true}catch{ try{$p2=$e.GetCurrentPattern([System.Windows.Automation.LegacyIAccessiblePattern]::Pattern);$p2.DoDefaultAction();return $true}catch{return $false} } }
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
# Ritorna lista di oggetti {Title, State}
function Get-Sessions($win){
    $seen=@{}; $out=@()
    $c=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,[System.Windows.Automation.ControlType]::Button)
    foreach($b in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants,$c)){
        $n=(''+$b.Current.Name).Trim(); if(-not $n){continue}; if($n -like 'Altre opzioni*'){continue}
        $m=[regex]::Match($n,$SESSION_STATE_RX)
        if($m.Success){
            $state=$m.Groups[1].Value; $title=$m.Groups[2].Value.Trim()
            if($title -and -not $seen.ContainsKey($title)){ $seen[$title]=$true; $out += [pscustomobject]@{Title=$title;State=$state} }
        }
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
# Apre una sessione e riprende se bloccata. Ritorna $true se ha cliccato la ripresa.
function Resume-SessionByTitle($title){
    $win=Get-ClaudeWindow; if(-not $win){return $false}
    if(Open-SessionByTitle $win $title){
        Start-Sleep -Milliseconds 1500
        $win=Get-ClaudeWindow
        $btn=Find-ResumeButton $win
        if($btn){ if(Invoke-Element $btn){ Start-Sleep -Seconds 2; return $true } }
    }
    return $false
}

# ----------------------------------------------------------------------------
$win = Get-ClaudeWindow
if(-not $win){ Toast "Claude non trovato" "L'app desktop Claude non risulta aperta."; return }
$sessions = Get-Sessions $win

if($ListOnly){
    Write-Output "Sessioni rilevate: $($sessions.Count)"
    foreach($s in $sessions){ Write-Output ("  [{0}] {1}" -f $s.State,$s.Title) }
    return
}
if($sessions.Count -eq 0){ Toast "Nessuna sessione" "Non ho trovato sessioni nella barra laterale."; return }

# selezione ricordata
$remembered=@()
if(Test-Path $PrefFile){ $remembered=@(Get-Content $PrefFile -Encoding utf8 | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

# ----------------------------- FINESTRA -------------------------------------
$form=New-Object System.Windows.Forms.Form
$form.Text="Quali sessioni Claude vuoi riprendere?"
$form.Size=New-Object System.Drawing.Size(560,520)
$form.StartPosition="CenterScreen"; $form.TopMost=$true; $form.MinimizeBox=$false; $form.MaximizeBox=$false

$lbl=New-Object System.Windows.Forms.Label
$lbl.Text="Spunta le sessioni da far ripartire. Le altre restano ferme."
$lbl.Location=New-Object System.Drawing.Point(14,12); $lbl.Size=New-Object System.Drawing.Size(520,20)
$form.Controls.Add($lbl)

$clb=New-Object System.Windows.Forms.CheckedListBox
$clb.Location=New-Object System.Drawing.Point(14,40); $clb.Size=New-Object System.Drawing.Size(516,330)
$clb.CheckOnClick=$true; $clb.IntegralHeight=$false
foreach($s in $sessions){
    $idx=$clb.Items.Add(("{0}   -   ({1})" -f $s.Title,$s.State))
    if($remembered -contains $s.Title){ $clb.SetItemChecked($idx,$true) }
}
$form.Controls.Add($clb)

$chkRemember=New-Object System.Windows.Forms.CheckBox
$chkRemember.Text="Ricorda la mia selezione"; $chkRemember.Location=New-Object System.Drawing.Point(14,378); $chkRemember.Size=New-Object System.Drawing.Size(260,22)
if($remembered.Count -gt 0){ $chkRemember.Checked=$true }
$form.Controls.Add($chkRemember)

$status=New-Object System.Windows.Forms.Label
$status.Location=New-Object System.Drawing.Point(14,404); $status.Size=New-Object System.Drawing.Size(516,20); $status.ForeColor=[System.Drawing.Color]::DimGray
$form.Controls.Add($status)

$btnAll=New-Object System.Windows.Forms.Button; $btnAll.Text="Seleziona tutto"; $btnAll.Location=New-Object System.Drawing.Point(14,436); $btnAll.Size=New-Object System.Drawing.Size(110,30)
$btnAll.Add_Click({ for($i=0;$i -lt $clb.Items.Count;$i++){ $clb.SetItemChecked($i,$true) } })
$form.Controls.Add($btnAll)

$btnNone=New-Object System.Windows.Forms.Button; $btnNone.Text="Deseleziona"; $btnNone.Location=New-Object System.Drawing.Point(130,436); $btnNone.Size=New-Object System.Drawing.Size(100,30)
$btnNone.Add_Click({ for($i=0;$i -lt $clb.Items.Count;$i++){ $clb.SetItemChecked($i,$false) } })
$form.Controls.Add($btnNone)

$btnDetect=New-Object System.Windows.Forms.Button; $btnDetect.Text="Rileva bloccate"; $btnDetect.Location=New-Object System.Drawing.Point(236,436); $btnDetect.Size=New-Object System.Drawing.Size(110,30)
$btnDetect.Add_Click({
    $status.Text="Controllo in corso... (apro le sessioni una a una)"; $form.Refresh()
    for($i=0;$i -lt $sessions.Count;$i++){
        $t=$sessions[$i].Title
        try{
            $w=Get-ClaudeWindow
            if(Open-SessionByTitle $w $t){ Start-Sleep -Milliseconds 1200; $w=Get-ClaudeWindow; $blocked=[bool](Find-ResumeButton $w); $clb.SetItemChecked($i,$blocked) }
        }catch{}
        $status.Text=("Controllo... {0}/{1}" -f ($i+1),$sessions.Count); $form.Refresh()
    }
    $n=0; for($i=0;$i -lt $clb.Items.Count;$i++){ if($clb.GetItemChecked($i)){$n++} }
    $status.Text="Trovate $n sessioni bloccate (gia' spuntate)."
})
$form.Controls.Add($btnDetect)

$btnGo=New-Object System.Windows.Forms.Button; $btnGo.Text="Riprendi selezionate"; $btnGo.Location=New-Object System.Drawing.Point(352,436); $btnGo.Size=New-Object System.Drawing.Size(130,30)
$btnGo.DialogResult=[System.Windows.Forms.DialogResult]::OK; $form.AcceptButton=$btnGo
$form.Controls.Add($btnGo)

$btnCancel=New-Object System.Windows.Forms.Button; $btnCancel.Text="Annulla"; $btnCancel.Location=New-Object System.Drawing.Point(488,436); $btnCancel.Size=New-Object System.Drawing.Size(0,30)
$btnCancel.DialogResult=[System.Windows.Forms.DialogResult]::Cancel; $form.CancelButton=$btnCancel
$form.Controls.Add($btnCancel)

$result=$form.ShowDialog()
if($result -ne [System.Windows.Forms.DialogResult]::OK){ return }

# raccogli selezione
$chosen=@()
for($i=0;$i -lt $sessions.Count;$i++){ if($clb.GetItemChecked($i)){ $chosen += $sessions[$i].Title } }

# memoria
if($chkRemember.Checked){
    $dir=Split-Path $PrefFile; if(-not(Test-Path $dir)){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
    Set-Content -Path $PrefFile -Value $chosen -Encoding utf8
} elseif(Test-Path $PrefFile){ Remove-Item $PrefFile -Force }

if($chosen.Count -eq 0){ Toast "Nessuna selezione" "Non hai selezionato sessioni da riprendere."; return }

$ok=0
foreach($t in $chosen){ try{ if(Resume-SessionByTitle $t){ $ok++ } }catch{} }
Toast "Claude: ripresa completata" ("Riprese {0} di {1} sessioni selezionate." -f $ok,$chosen.Count)
