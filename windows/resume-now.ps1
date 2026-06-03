<#
=============================================================================
 resume-now.ps1  --  Tasto "Continua il lavoro" per l'app Claude (Windows)
=============================================================================
 Lo premi TU quando i crediti sono tornati. Trova l'app Claude e clicca al
 posto tuo i pulsanti sicuri di ripresa ("Continua a lavorare" / "Riprova"),
 usando la UI Automation di Windows.

 MULTI-SESSIONE (default): cicla TUTTE le sessioni della barra laterale, apre
 ognuna e clicca la ripresa dove presente. Cosi' se hai 3 chat bloccate
 (Cowork + Code), le fa ripartire tutte.
   -Single  -> riprende solo la sessione attualmente aperta.

 SICUREZZA: clicca SOLO pulsanti di ripresa. Non tocca MAI nulla che spenda
 denaro o cambi piano (Acquista crediti, Passa a Max, Aggiorna piano).

 Made in Italy.
=============================================================================
#>
[CmdletBinding()]
param([switch]$Single)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$AE = [System.Windows.Automation.AutomationElement]

$SAFE_RESUME = @('continua a lavorare', 'continua il lavoro', 'riprova', 'riprendi', 'continue working', 'continue')
$NEVER_CLICK = @('acquist', 'passa a max', 'aggiorna il tuo piano', 'upgrade', 'paga', 'purchase', 'buy', 'piano')
# Prefissi di stato delle voci-sessione nella barra laterale (per ciclarle)
$SESSION_STATE_RX = '^(In esecuzione|Inattivo|In pausa|In coda|Pronto|Completato|Annullato|Errore|Running|Idle|Paused|Queued|Ready|Completed|Cancelled|Error)\s+(.+)$'

function Toast($title, $text) {
    try {
        $n = New-Object System.Windows.Forms.NotifyIcon
        $n.Icon = [System.Drawing.SystemIcons]::Information; $n.Visible = $true
        $n.ShowBalloonTip(6000, $title, $text, [System.Windows.Forms.ToolTipIcon]::Info)
        Start-Sleep -Milliseconds 6500; $n.Dispose()
    } catch {}
}

# "Offrimi un caffe'": compare dopo una ripresa riuscita (a meno che disattivato).
function Show-Coffee {
    $PAYPAL_URL="https://www.paypal.me/messylove23"
    $flag=Join-Path $env:LOCALAPPDATA 'claude-ac\no-coffee.flag'
    if(Test-Path $flag){ return }
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

function Get-ClaudeWindow {
    $storePids = @(Get-Process claude -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like '*WindowsApps*' } | Select-Object -ExpandProperty Id)
    if ($storePids.Count -eq 0) { return $null }
    $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
    $wins = $AE::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
    foreach ($w in $wins) { if ($storePids -contains $w.Current.ProcessId) { return $w } }
    return $null
}

function Test-Invokable($el) {
    try { $p = $null; return $el.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$p) } catch { return $false }
}

function Invoke-Element($el) {
    try { $p = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern); $p.Invoke(); return $true }
    catch {
        try { $p2 = $el.GetCurrentPattern([System.Windows.Automation.LegacyIAccessiblePattern]::Pattern); $p2.DoDefaultAction(); return $true } catch { return $false }
    }
}

function Find-ResumeButton($win) {
    if (-not $win) { return $null }
    foreach ($ct in @([System.Windows.Automation.ControlType]::Button, [System.Windows.Automation.ControlType]::Hyperlink)) {
        $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, $ct)
        foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)) {
            $name = ('' + $e.Current.Name).Trim(); if (-not $name) { continue }
            $low = $name.ToLower()
            $blocked = $false; foreach ($bad in $NEVER_CLICK) { if ($low.Contains($bad)) { $blocked = $true; break } }
            if ($blocked) { continue }
            if ($SAFE_RESUME -contains $low -and (Test-Invokable $e)) { return $e }
        }
    }
    return $null
}

# Titoli delle sessioni nella barra laterale (senza il prefisso di stato)
function Get-SessionTitles($win) {
    $titles = New-Object System.Collections.Generic.List[string]
    $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
    foreach ($b in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)) {
        $n = ('' + $b.Current.Name).Trim(); if (-not $n) { continue }
        if ($n -like 'Altre opzioni*') { continue }
        $m = [regex]::Match($n, $SESSION_STATE_RX)
        if ($m.Success) {
            $t = $m.Groups[2].Value.Trim()
            if ($t -and -not $titles.Contains($t)) { [void]$titles.Add($t) }
        }
    }
    return $titles
}

# Apre una sessione cercando la voce che termina con quel titolo
function Open-SessionByTitle($win, $title) {
    $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
    foreach ($b in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)) {
        $n = ('' + $b.Current.Name).Trim(); if (-not $n) { continue }
        if ($n -like 'Altre opzioni*') { continue }
        if ($n.EndsWith($title)) { return (Invoke-Element $b) }
    }
    return $false
}

# Clicca la ripresa nella sessione aperta ora; ritorna $true se ha cliccato
function Resume-Current {
    $win = Get-ClaudeWindow
    $btn = Find-ResumeButton $win
    if ($btn) {
        $bn = $btn.Current.Name
        if (Invoke-Element $btn) { Start-Sleep -Seconds 2; return $true }
    }
    return $false
}

# ============================== AZIONE ====================================
$win = Get-ClaudeWindow
if (-not $win) { Toast "Claude non trovato" "L'app desktop Claude non risulta aperta."; Write-Output "App Claude non in esecuzione."; return }

$resumed = 0

# 1) sessione attualmente aperta
if (Resume-Current) { $resumed++; Write-Output "Ripresa sessione corrente." }

if (-not $Single) {
    # 2) cicla tutte le altre sessioni della barra laterale
    $win = Get-ClaudeWindow
    $titles = Get-SessionTitles $win
    Write-Output "Sessioni in lista da controllare: $($titles.Count)"
    $checked = 0
    foreach ($t in $titles) {
        if ($checked -ge 30) { break }   # tetto di sicurezza
        $checked++
        try {
            $win = Get-ClaudeWindow
            if (Open-SessionByTitle $win $t) {
                Start-Sleep -Milliseconds 1500
                if (Resume-Current) { $resumed++; Write-Output "Ripresa: $t" }
            }
        } catch { }
    }
}

if ($resumed -gt 0) {
    $msg = if ($resumed -eq 1) { "Ho ripreso 1 sessione." } else { "Ho ripreso $resumed sessioni." }
    Toast "Claude: lavoro ripreso!" $msg
    Write-Output "OK. $msg"
    Show-Coffee
} else {
    Toast "Niente da riprendere" "Nessuna sessione bloccata dal limite in questo momento."
    Write-Output "Nessuna ripresa: nessun pulsante di ripresa trovato."
}
