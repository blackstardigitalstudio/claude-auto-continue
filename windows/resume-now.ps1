<#
=============================================================================
 resume-now.ps1  --  Tasto "Continua il lavoro" per l'app Claude (Windows)
=============================================================================
 Lo premi TU quando i crediti sono tornati. Trova la finestra dell'app Claude
 e clicca al posto tuo il pulsante sicuro di ripresa ("Continua a lavorare" /
 "Riprova"), usando la UI Automation di Windows.

 SICUREZZA: clicca SOLO pulsanti di ripresa. Non tocca MAI nulla che spenda
 denaro o cambi piano (Acquista crediti, Passa a Max, Aggiorna piano).

 Made in Italy.
=============================================================================
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$AE = [System.Windows.Automation.AutomationElement]

$SAFE_RESUME = @('continua a lavorare', 'continua il lavoro', 'riprova', 'riprendi', 'continue working', 'continue')
$NEVER_CLICK = @('acquist', 'passa a max', 'aggiorna il tuo piano', 'upgrade', 'paga', 'purchase', 'buy', 'piano')

function Toast($title, $text) {
    try {
        $n = New-Object System.Windows.Forms.NotifyIcon
        $n.Icon = [System.Drawing.SystemIcons]::Information
        $n.Visible = $true
        $n.ShowBalloonTip(6000, $title, $text, [System.Windows.Forms.ToolTipIcon]::Info)
        Start-Sleep -Milliseconds 6500; $n.Dispose()
    } catch {}
}

function Get-ClaudeWindows {
    $storePids = @(Get-Process claude -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like '*WindowsApps*' } | Select-Object -ExpandProperty Id)
    if ($storePids.Count -eq 0) { return @() }
    $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
    $wins = $AE::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
    $out = @(); foreach ($w in $wins) { if ($storePids -contains $w.Current.ProcessId) { $out += $w } }
    return $out
}

function Test-Invokable($el) {
    try { $p = $null; return $el.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$p) } catch { return $false }
}

function Find-ResumeButton($win) {
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

function Invoke-Element($el) {
    try { $p = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern); $p.Invoke(); return $true }
    catch {
        try { $p2 = $el.GetCurrentPattern([System.Windows.Automation.LegacyIAccessiblePattern]::Pattern); $p2.DoDefaultAction(); return $true } catch { return $false }
    }
}

# --- azione ---------------------------------------------------------------
$wins = Get-ClaudeWindows
if ($wins.Count -eq 0) {
    Toast "Claude non trovato" "L'app desktop Claude non risulta aperta."
    Write-Output "App Claude non in esecuzione."
    return
}

$clicked = $false
foreach ($w in $wins) {
    $btn = Find-ResumeButton $w
    if ($btn) {
        $bn = $btn.Current.Name
        # porta la finestra in primo piano (best effort) e clicca
        try { [void][System.Windows.Forms.SystemInformation]; } catch {}
        if (Invoke-Element $btn) {
            Start-Sleep -Seconds 2
            $still = Find-ResumeButton (Get-ClaudeWindows | Select-Object -First 1)
            if (-not $still) {
                Toast "Claude: lavoro ripreso!" "Ho premuto '$bn' per te. La sessione riparte."
                Write-Output "OK: cliccato '$bn', sessione ripresa."
            } else {
                Toast "Crediti non ancora pronti" "Ho premuto '$bn' ma il limite e' ancora attivo. Riprova tra poco."
                Write-Output "Cliccato '$bn' ma limite ancora presente."
            }
            $clicked = $true
            break
        }
    }
}

if (-not $clicked) {
    Toast "Niente da riprendere" "Nessun pulsante di ripresa: la sessione non e' bloccata dal limite."
    Write-Output "Nessun pulsante di ripresa trovato (nessun limite attivo)."
}
