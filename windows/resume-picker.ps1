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
param([switch]$ListOnly, [string]$Message='Riprendi da dove eri rimasto. Prima riassumi in una riga cosa era in corso e cosa manca, poi prosegui.')

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$AE = [System.Windows.Automation.AutomationElement]

$SAFE_RESUME = @('continua a lavorare','continua il lavoro','riprova','riprendi','continue working','continue')
$NEVER_CLICK = @('acquist','passa a max','aggiorna il tuo piano','upgrade','paga','purchase','buy','piano')
$SESSION_STATE_RX = '^(In esecuzione|In attesa di input|In attesa|Inattivo|In pausa|In coda|Pronto|Completato|Annullato|Errore|Running|Waiting for input|Waiting|Idle|Paused|Queued|Ready|Completed|Cancelled|Error)\s+(.+)$'
$GROUPS = @('Sessioni')
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
# Enumera TUTTE le sessioni della barra laterale in modo affidabile: ogni sessione
# ha un pulsante gemello "Altre opzioni per <titolo>", da cui ricaviamo il titolo
# pulito (a prescindere dallo stato o dai raggruppamenti). Lo stato, se presente,
# lo leggiamo dal pulsante che apre la sessione (il cui nome inizia con lo stato).
function Get-Sessions($win){
    if(-not $win){ return @() }
    $c=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,[System.Windows.Automation.ControlType]::Button)
    $btns=@($win.FindAll([System.Windows.Automation.TreeScope]::Descendants,$c))
    $order=New-Object System.Collections.Generic.List[string]
    $state=@{}
    # 1) titoli dai pulsanti "Altre opzioni per <titolo>"
    foreach($b in $btns){
        $n=(''+$b.Current.Name).Trim(); if(-not $n){continue}
        $m=[regex]::Match($n,'^Altre opzioni per (.+)$')
        if($m.Success){ $t=$m.Groups[1].Value.Trim(); if($t -and -not $state.ContainsKey($t)){ $state[$t]=''; [void]$order.Add($t) } }
    }
    # 2) stato (dal pulsante che apre la sessione, se inizia con uno stato noto)
    foreach($b in $btns){
        $n=(''+$b.Current.Name).Trim(); if(-not $n){continue}; if($n -like 'Altre opzioni*'){continue}
        $ms=[regex]::Match($n,$SESSION_STATE_RX)
        if($ms.Success){ $st=$ms.Groups[1].Value; $tt=$ms.Groups[2].Value.Trim(); if($state.ContainsKey($tt) -and -not $state[$tt]){ $state[$tt]=$st } }
    }
    $out=@()
    foreach($t in $order){ $s=$state[$t]; if(-not $s){$s='-'}; $out += [pscustomobject]@{Title=$t;State=$s} }
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
# Raccoglie i nomi dei pulsanti della barra laterale IN ORDINE DI DOCUMENTO
# (DFS pre-order). Serve a ricostruire i gruppi: nella barra gli header di sezione
# (Fissato / Non raggruppato / <gruppo-progetto> ...) sono pulsanti che precedono
# le proprie sessioni.
function Collect-SidebarButtons($win){
    $names=New-Object System.Collections.Generic.List[string]
    if(-not $win){ return $names }
    $walker=[System.Windows.Automation.TreeWalker]::ControlViewWalker
    $root=$win
    try{
        $nc=New-Object System.Windows.Automation.PropertyCondition($AE::NameProperty,'Barra laterale')
        $sb=$win.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$nc)
        if($sb){ $root=$sb }
    }catch{}
    $stack=New-Object System.Collections.Generic.Stack[System.Windows.Automation.AutomationElement]
    $stack.Push($root); $guard=0
    while($stack.Count -gt 0 -and $guard -lt 6000){
        $guard++; $el=$stack.Pop()
        if(-not [object]::ReferenceEquals($el,$root)){
            try{ if($el.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button){ $n=(''+$el.Current.Name).Trim(); if($n){ [void]$names.Add($n) } } }catch{}
        }
        $kids=New-Object System.Collections.Generic.List[System.Windows.Automation.AutomationElement]
        try{ $ch=$walker.GetFirstChild($el); while($ch -ne $null){ [void]$kids.Add($ch); $ch=$walker.GetNextSibling($ch) } }catch{}
        for($i=$kids.Count-1;$i -ge 0;$i--){ $stack.Push($kids[$i]) }
    }
    return $names
}
# Raccoglie le sessioni della barra laterale DIVISE per sezione reale dell'app
# (l'app non ha piu' le schede Chat/Cowork/Code: la barra e' divisa in Fissato,
# gruppi-progetto, Non raggruppato, ecc.). Ritorna un dizionario ordinato
# gruppo -> @(sessioni), saltando i gruppi vuoti.
function Gather-All {
    $win=Get-ClaudeWindow
    if(-not $win){ $r=[ordered]@{}; $r.Add('Sessioni',@()); return $r }
    $flat=@(Get-Sessions $win)
    $stateOf=@{}; foreach($s in $flat){ $stateOf[$s.Title]=$s.State }
    $titles=@($flat | ForEach-Object { $_.Title } | Sort-Object { $_.Length } -Descending)
    # pulsanti di navigazione/controllo da ignorare (non sono ne' header ne' sessioni)
    $IGNORE='home','code','nuova sessione','attività rapida','artefatti','routine','personalizza','altre voci di navigazione','collapse sidebar','search','filter','menu','indietro','inoltra','ripristina','riduci a icona','chiudi','mode'
    $names=Collect-SidebarButtons $win
    # hashtable normale (chiavi stringa) + lista d'ordine: evita l'ambiguita' del
    # doppio indexer di OrderedDictionary in PowerShell 5.1.
    $bucket=@{}
    $order=New-Object System.Collections.Generic.List[string]
    $seen=@{}
    $current='Recenti'
    foreach($n in $names){
        $low=$n.ToLower()
        if($low.StartsWith('altre opzioni') -or $low.StartsWith('mostra altri')){ continue }
        if($IGNORE -contains $low){ continue }
        $match=$null
        foreach($t in $titles){ if($t -and $n.EndsWith($t)){ $match=$t; break } }
        if($match){
            if($seen.ContainsKey($match)){ continue }
            $seen[$match]=$true
            if(-not $bucket.ContainsKey($current)){ $bucket[$current]=New-Object System.Collections.Generic.List[object]; [void]$order.Add($current) }
            $st=$stateOf[$match]; if(-not $st){$st='-'}
            [void]$bucket[$current].Add([pscustomobject]@{Title=$match;State=$st})
        } else {
            $current=$n   # header di sezione
        }
    }
    # sessioni non collocate dal walk -> gruppo "Altre" (robustezza)
    foreach($s in $flat){ if(-not $seen.ContainsKey($s.Title)){ if(-not $bucket.ContainsKey('Altre')){ $bucket['Altre']=New-Object System.Collections.Generic.List[object]; [void]$order.Add('Altre') }; [void]$bucket['Altre'].Add($s); $seen[$s.Title]=$true } }
    $res=[ordered]@{}
    foreach($k in $order){ $res.Add($k, $bucket[$k].ToArray()) }
    if($res.Count -eq 0){ $res.Add('Sessioni', @($flat)) }
    return $res
}
# Trova la casella di input del messaggio (composer) nella chat aperta.
function Find-Composer($win){
    if(-not $win){return $null}
    foreach($ct in @([System.Windows.Automation.ControlType]::Edit,[System.Windows.Automation.ControlType]::Document)){
        $c=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,$ct)
        $els=$win.FindAll([System.Windows.Automation.TreeScope]::Descendants,$c)
        foreach($e in $els){
            $n=(''+$e.Current.Name).ToLower()
            if($n -match 'messaggio|message|digita|scrivi|reply|chiedi|comandi'){ return $e }
        }
        if($els.Count -gt 0){ return $els[$els.Count-1] }   # fallback: l'ultima casella editabile (il composer e' in basso)
    }
    return $null
}

# Invia un messaggio nella chat aperta per riattivarla (logica del tasto "Continue").
function Send-ContinueMessage($win,$text){
    $box=Find-Composer $win
    if(-not $box){ return $false }
    try{ $box.SetFocus() }catch{}
    Start-Sleep -Milliseconds 400
    $set=$false
    try{ $vp=$box.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern); if(-not $vp.Current.IsReadOnly){ $vp.SetValue($text); $set=$true } }catch{}
    if(-not $set){ try{ [System.Windows.Forms.SendKeys]::SendWait($text) }catch{ return $false } }
    Start-Sleep -Milliseconds 500
    try{ [System.Windows.Forms.SendKeys]::SendWait("{ENTER}") }catch{}
    Start-Sleep -Milliseconds 800
    return $true
}

function Resume-One($group,$title){
    $win=Get-ClaudeWindow; if(-not $win){return $false}
    if(Open-SessionByTitle $win $title){
        Start-Sleep -Milliseconds 1500; $win=Get-ClaudeWindow
        # 1) se c'e' il pulsante nativo di ripresa, clicca quello (modo pulito).
        #    Cliccarlo e' sicuro: se i crediti non sono tornati l'app ri-mostra solo
        #    il limite, nessun turno sprecato.
        $btn=Find-ResumeButton $win
        if($btn){ if(Invoke-Element $btn){ Start-Sleep -Seconds 2; return $true } }
        # 2) altrimenti invia un messaggio per riattivare la conversazione (Claude Code).
        #    Ma prima verifica che la quota sia DAVVERO tornata: inviare consuma un
        #    turno, quindi se il limite e' ancora attivo aspettiamo e ricontrolliamo
        #    invece di sprecarlo (resume non cieco).
        if(Confirm-CreditsBack $win){
            $win=Get-ClaudeWindow
            if(Send-ContinueMessage $win $Message){ Start-Sleep -Seconds 1; return $true }
        } else {
            Write-Output ("Salto '{0}': limite ancora attivo, non invio a vuoto." -f $title)
        }
    }
    return $false
}
function Test-Blocked($group,$title){
    $win=Get-ClaudeWindow; if(-not $win){return $false}
    if(Open-SessionByTitle $win $title){ Start-Sleep -Milliseconds 1200; $win=Get-ClaudeWindow; return [bool](Find-ResumeButton $win) }
    return $false
}
function Toast($t,$x){ try{ $n=New-Object System.Windows.Forms.NotifyIcon; $n.Icon=[System.Drawing.SystemIcons]::Information; $n.Visible=$true; $n.ShowBalloonTip(6000,$t,$x,'Info'); Start-Sleep -Milliseconds 6500; $n.Dispose() }catch{} }

# --- Attesa "reset + 30s" ----------------------------------------------------
function Get-WindowText($win){
    if(-not $win){return ""}
    $tc=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,[System.Windows.Automation.ControlType]::Text)
    $sb=New-Object System.Text.StringBuilder
    foreach($t in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants,$tc)){ [void]$sb.AppendLine($t.Current.Name) }
    return $sb.ToString()
}
function Parse-ResetTime([string]$text){
    $m=[regex]::Match($text,'(?i)(?:ripristina|ripristino|reimposta|azzera|reset)\D{0,20}(\d{1,2}):(\d{2})')
    if(-not $m.Success){return $null}
    $h=[int]$m.Groups[1].Value; $min=[int]$m.Groups[2].Value
    $now=Get-Date; $t=Get-Date -Hour $h -Minute $min -Second 0
    if($t -lt $now.AddMinutes(-5)){ $t=$t.AddDays(1) }
    return $t
}
# Se c'e' un'ora di reset futura, aspetta fino a (reset + 30s) prima di cliccare.
# Se il reset e' gia' passato -> clicca subito (niente attesa, niente rollover a domani).
function Wait-UntilResetPlus30($win){
    $text=Get-WindowText $win
    $m=[regex]::Match($text,'(?i)(?:ripristina|ripristino|reimposta|azzera|reset)\D{0,20}(\d{1,2}):(\d{2})')
    if(-not $m.Success){return}
    $target=(Get-Date -Hour ([int]$m.Groups[1].Value) -Minute ([int]$m.Groups[2].Value) -Second 0).AddSeconds(30)
    $now=Get-Date
    if($now -ge $target){return}
    if(($target-$now).TotalHours -gt 6){return}
    $wait=[int]($target-$now).TotalSeconds
    Toast "Claude: aspetto il reset" ("Riprendo alle {0} (30s dopo i crediti). Non chiudere." -f $target.ToString('HH:mm:ss'))
    Start-Sleep -Seconds $wait
}

# Il limite e' ANCORA attivo? Segnali: c'e' un pulsante nativo di ripresa,
# oppure la finestra mostra ancora il banner del limite ("limite di utilizzo",
# "si ripristina alle ...", "usage limit", "resets at ...").
function Test-LimitActive($win){
    if(-not $win){ return $false }
    if(Find-ResumeButton $win){ return $true }
    $t=Get-WindowText $win
    return [bool]([regex]::IsMatch($t,'(?i)limite di utilizzo|usage limit|si (?:ripristina|azzera|reimposta)|resets? at'))
}
# Verifica che la quota sia DAVVERO tornata prima di inviare un messaggio.
# Inviare consuma un turno: se il limite e' ancora attivo NON inviamo a vuoto,
# ma ri-controlliamo per qualche minuto e agiamo solo quando i crediti sono tornati
# (feedback community su #35744: "resume shouldn't be blind" / "re-check that the
# quota actually reset before continuing, and re-arm and wait if it hasn't").
function Confirm-CreditsBack($win){
    if(-not (Test-LimitActive $win)){ return $true }
    $deadline=(Get-Date).AddMinutes(6)
    while((Get-Date) -lt $deadline){
        Start-Sleep -Seconds 25
        if(-not (Test-LimitActive (Get-ClaudeWindow))){ return $true }
    }
    return $false
}

# "Offrimi un caffe'": MASSIMO UNA VOLTA AL GIORNO (niente spam), disattivabile.
function Show-Coffee {
    $PAYPAL_URL="https://www.paypal.me/messylove23"
    $dir=Join-Path $env:LOCALAPPDATA 'claude-ac'
    $flag=Join-Path $dir 'no-coffee.flag'
    $daily=Join-Path $dir 'coffee-last.txt'
    if(Test-Path $flag){ return }
    $today=(Get-Date).ToString('yyyy-MM-dd')
    if(Test-Path $daily){ try{ if(((Get-Content $daily -Raw) -replace '\s','') -eq $today){ return } }catch{} }
    if(-not(Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Set-Content -Path $daily -Value $today -Encoding utf8
    $dark=[System.Drawing.Color]::FromArgb(17,21,28); $accent=[System.Drawing.Color]::FromArgb(0,146,70)
    $tFont=New-Object System.Drawing.Font("Segoe UI",15,[System.Drawing.FontStyle]::Bold)
    $bFont=New-Object System.Drawing.Font("Segoe UI",9.5,[System.Drawing.FontStyle]::Bold)
    $cf=New-Object System.Windows.Forms.Form
    $cf.Text="Grazie!"; $cf.ClientSize=New-Object System.Drawing.Size(430,222); $cf.StartPosition="CenterScreen"; $cf.TopMost=$true
    $cf.FormBorderStyle="FixedSingle"; $cf.MaximizeBox=$false; $cf.MinimizeBox=$false; $cf.BackColor=[System.Drawing.Color]::White
    $hd=New-Object System.Windows.Forms.Panel; $hd.Dock="Top"; $hd.Height=62; $hd.BackColor=$dark; $cf.Controls.Add($hd)
    $tl=New-Object System.Windows.Forms.Label; $tl.Text="Ti e' servito?"; $tl.ForeColor=[System.Drawing.Color]::White; $tl.Font=$tFont; $tl.AutoSize=$true; $tl.Location=New-Object System.Drawing.Point(18,15); $hd.Controls.Add($tl)
    $msg=New-Object System.Windows.Forms.Label; $msg.Text="Se claude-ac ti ha salvato del lavoro, offrimi un caffe':`nmi aiuti a portare avanti aggiornamenti e migliorie."; $msg.AutoSize=$false; $msg.Size=New-Object System.Drawing.Size(394,54); $msg.Location=New-Object System.Drawing.Point(18,76); $cf.Controls.Add($msg)
    $chk=New-Object System.Windows.Forms.CheckBox; $chk.Text="Non chiedermelo piu'"; $chk.AutoSize=$true; $chk.Location=New-Object System.Drawing.Point(18,140); $chk.ForeColor=[System.Drawing.Color]::Gray; $cf.Controls.Add($chk)
    $pay=New-Object System.Windows.Forms.Button; $pay.Text="Offrimi un caffe' (PayPal)"; $pay.Font=$bFont; $pay.FlatStyle="Flat"; $pay.FlatAppearance.BorderSize=0; $pay.BackColor=$accent; $pay.ForeColor=[System.Drawing.Color]::White; $pay.Size=New-Object System.Drawing.Size(206,40); $pay.Location=New-Object System.Drawing.Point(206,168); $pay.Cursor="Hand"; $cf.Controls.Add($pay)
    $no=New-Object System.Windows.Forms.Button; $no.Text="No, grazie"; $no.Font=$bFont; $no.FlatStyle="Flat"; $no.FlatAppearance.BorderSize=0; $no.BackColor=[System.Drawing.Color]::FromArgb(238,240,243); $no.ForeColor=$dark; $no.Size=New-Object System.Drawing.Size(110,40); $no.Location=New-Object System.Drawing.Point(88,168); $no.Cursor="Hand"; $cf.Controls.Add($no)
    $pay.Add_Click({ try{ Start-Process $PAYPAL_URL }catch{}; if($chk.Checked){ New-Item -ItemType File -Path $flag -Force | Out-Null }; $cf.Close() })
    $no.Add_Click({ if($chk.Checked){ New-Item -ItemType File -Path $flag -Force | Out-Null }; $cf.Close() })
    [void]$cf.ShowDialog()
}

# ----------------------------------------------------------------------------
$win = Get-ClaudeWindow
if(-not $win){ Toast "Claude non trovato" "L'app desktop Claude non risulta aperta."; return }

$data = Gather-All
$groupNames = @($data.Keys)
$total = 0; foreach($g in $groupNames){ $total += $data[$g].Count }

if($ListOnly){
    foreach($g in $groupNames){ Write-Output ("== {0} ({1}) ==" -f $g,$data[$g].Count); foreach($s in $data[$g]){ Write-Output ("   [{0}] {1}" -f $s.State,$s.Title) } }
    return
}
if($total -eq 0){ Toast "Nessuna sessione" "Non ho trovato sessioni nella barra laterale di Claude."; return }

# selezione ricordata (righe "Group|Title")
$remembered=@{}
if(Test-Path $PrefFile){ foreach($l in (Get-Content $PrefFile -Encoding utf8)){ $t=$l.Trim(); if($t){ $remembered[$t]=$true } } }

# ============================ FINESTRA (stile) ==============================
$form=New-Object System.Windows.Forms.Form
$form.Text="Claude - Riprendi il lavoro"
$form.ClientSize=New-Object System.Drawing.Size(624,600)
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

# ---- Footer (layout pulito a 3 righe) ----
$footer=New-Object System.Windows.Forms.Panel
$footer.Dock="Bottom"; $footer.Height=128; $footer.BackColor=$C_CARD
$form.Controls.Add($footer)
$sep=New-Object System.Windows.Forms.Panel; $sep.Dock="Top"; $sep.Height=1; $sep.BackColor=[System.Drawing.Color]::FromArgb(225,228,233); $footer.Controls.Add($sep)
$CW=$form.ClientSize.Width

function New-StyledButton($text,$primary){
    $b=New-Object System.Windows.Forms.Button; $b.Text=$text; $b.Font=$F_BTN; $b.FlatStyle="Flat"; $b.Cursor="Hand"
    $b.FlatAppearance.BorderSize=0
    if($primary){ $b.BackColor=$C_ACCENT; $b.ForeColor=[System.Drawing.Color]::White }
    else { $b.BackColor=[System.Drawing.Color]::FromArgb(238,240,243); $b.ForeColor=$C_TEXT }
    return $b
}

# Riga 1: a sinistra "Ricorda", a destra Tutte / Nessuna
$chkRemember=New-Object System.Windows.Forms.CheckBox
$chkRemember.Text="Ricorda la mia selezione"; $chkRemember.AutoSize=$true; $chkRemember.ForeColor=$C_TEXT
$chkRemember.Location=New-Object System.Drawing.Point(20,16); if($remembered.Count -gt 0){$chkRemember.Checked=$true}; $footer.Controls.Add($chkRemember)
$btnNone=New-StyledButton "Nessuna" $false; $btnNone.Size=New-Object System.Drawing.Size(84,30); $btnNone.Location=New-Object System.Drawing.Point(($CW-20-84),12); $footer.Controls.Add($btnNone)
$btnAll=New-StyledButton "Tutte" $false; $btnAll.Size=New-Object System.Drawing.Size(74,30); $btnAll.Location=New-Object System.Drawing.Point(($btnNone.Left-8-74),12); $footer.Controls.Add($btnAll)

# Riga 2: stato (riga propria, niente sovrapposizioni)
$status=New-Object System.Windows.Forms.Label
$status.AutoSize=$true; $status.ForeColor=$C_MUTED; $status.Location=New-Object System.Drawing.Point(20,50); $footer.Controls.Add($status)

# Riga 3: a sinistra Made in Italy + bandiera con bordo, a destra i pulsanti azione
$madein=New-Object System.Windows.Forms.Label
$madein.Text="Made in Italy"; $madein.AutoSize=$true; $madein.ForeColor=$C_MUTED; $madein.Font=$F_SUB
$madein.Location=New-Object System.Drawing.Point(20,92); $footer.Controls.Add($madein)
$flag=New-Object System.Windows.Forms.Panel; $flag.Size=New-Object System.Drawing.Size(27,16); $flag.Location=New-Object System.Drawing.Point(112,90); $flag.BorderStyle="FixedSingle"; $footer.Controls.Add($flag)
$bar0=New-Object System.Windows.Forms.Panel; $bar0.Size=New-Object System.Drawing.Size(8,14); $bar0.Location=New-Object System.Drawing.Point(0,0); $bar0.BackColor=$C_GREEN; $flag.Controls.Add($bar0)
$bar1=New-Object System.Windows.Forms.Panel; $bar1.Size=New-Object System.Drawing.Size(8,14); $bar1.Location=New-Object System.Drawing.Point(8,0); $bar1.BackColor=[System.Drawing.Color]::White; $flag.Controls.Add($bar1)
$bar2=New-Object System.Windows.Forms.Panel; $bar2.Size=New-Object System.Drawing.Size(9,14); $bar2.Location=New-Object System.Drawing.Point(16,0); $bar2.BackColor=$C_RED; $flag.Controls.Add($bar2)

$btnGo=New-StyledButton "Continua selezionate" $true; $btnGo.Size=New-Object System.Drawing.Size(190,38); $btnGo.Location=New-Object System.Drawing.Point(($CW-20-190),80); $footer.Controls.Add($btnGo)
$btnDetect=New-StyledButton "Rileva bloccate" $false; $btnDetect.Size=New-Object System.Drawing.Size(150,38); $btnDetect.Location=New-Object System.Drawing.Point(($btnGo.Left-10-150),80); $footer.Controls.Add($btnDetect)

# ---- Area centrale scrollabile con gruppi ----
$scroll=New-Object System.Windows.Forms.Panel
$scroll.Dock="Fill"; $scroll.AutoScroll=$true; $scroll.BackColor=$C_PANEL; $scroll.Padding=New-Object System.Windows.Forms.Padding(16,12,16,12)
$form.Controls.Add($scroll); $scroll.BringToFront()

$checkItems=New-Object System.Collections.Generic.List[object]
$y=8
foreach($g in $groupNames){
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
        $card=New-Object System.Windows.Forms.Panel; $card.Size=New-Object System.Drawing.Size(552,38); $card.Location=New-Object System.Drawing.Point(8,$y); $card.BackColor=$C_CARD
        $cb=New-Object System.Windows.Forms.CheckBox; $cb.AutoSize=$false; $cb.AutoEllipsis=$true; $cb.Size=New-Object System.Drawing.Size(396,20); $cb.Location=New-Object System.Drawing.Point(12,9)
        $cb.Text=$s.Title; $cb.Font=$F_ITEM; $cb.ForeColor=$C_TEXT
        $key=("{0}|{1}" -f $g,$s.Title); if($remembered.ContainsKey($key)){ $cb.Checked=$true }
        $st=New-Object System.Windows.Forms.Label; $st.Text=$s.State; $st.AutoSize=$false; $st.Size=New-Object System.Drawing.Size(120,20); $st.TextAlign="MiddleRight"; $st.Font=$F_SUB; $st.ForeColor=$C_MUTED; $st.Location=New-Object System.Drawing.Point(420,9)
        $card.Controls.Add($cb); $card.Controls.Add($st); $scroll.Controls.Add($card)
        $checkItems.Add([pscustomobject]@{ Cb=$cb; Group=$g; Title=$s.Title }) | Out-Null
        $y+=42
    }
    $y+=6
}
$status.Text=("{0} sessioni trovate." -f $total)

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

# Se l'app mostra un'ora di reset futura, aspetta fino a (reset + 30s): non clicca subito.
Wait-UntilResetPlus30 (Get-ClaudeWindow)

$ok=0; foreach($c in $chosen){ try{ if(Resume-One $c.Group $c.Title){ $ok++ } }catch{} }
Toast "Claude: ripresa completata" ("Riprese {0} di {1} sessioni selezionate." -f $ok,$chosen.Count)
if($ok -gt 0){ Show-Coffee }
