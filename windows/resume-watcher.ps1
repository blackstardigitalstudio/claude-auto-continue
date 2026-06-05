<#
=============================================================================
 resume-watcher.ps1  --  Auto-Continue per l'APP DESKTOP di Claude (Windows)
=============================================================================
 Perche' esiste:
   L'hook Stop di Claude Code NON scatta quando finisci i token (la sessione
   va in errore, non in "stop"). E l'app desktop (Microsoft Store / Electron)
   non passa dal wrapper da terminale. Quindi qui usiamo l'unica via che
   funziona davvero sull'app: la UI Automation di Windows.

 Cosa fa:
   - Sorveglia la finestra dell'app "Claude".
   - Quando compare "Limite di utilizzo raggiunto", legge l'ora di reset.
   - Appena passata l'ora di reset, CLICCA lui il pulsante di ripresa
     ("Continua a lavorare" / "Riprova") tramite l'API di accessibilita'.
   - Ti avvisa con una notifica desktop a ogni passaggio.

 SICUREZZA: clicca SOLO pulsanti sicuri di ripresa. Non tocca MAI nulla che
   spenda denaro o cambi piano (Acquista crediti, Passa a Max, Aggiorna piano).

 Uso:
   powershell -ExecutionPolicy Bypass -File resume-watcher.ps1            # loop continuo
   powershell -ExecutionPolicy Bypass -File resume-watcher.ps1 -Once      # un solo scan (diagnostica)
   powershell -ExecutionPolicy Bypass -File resume-watcher.ps1 -NoClick   # rileva e notifica, ma non clicca

 Made in Italy.
=============================================================================
#>
[CmdletBinding()]
param(
    [switch]$Once,                 # esegue una sola scansione e stampa lo stato
    [switch]$NoClick,              # rileva + notifica ma NON clicca (solo avviso)
    [int]$IntervalSeconds = 60,    # ogni quanto controllare
    [int]$BufferSeconds = 30       # margine dopo l'ora di reset prima di cliccare (30s dopo che tornano i token)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$AE = [System.Windows.Automation.AutomationElement]

# --- Configurazione: nomi pulsanti ----------------------------------------
# SOLO questi vengono cliccati. MATCH ESATTO (nome del pulsante == voce),
# per non confondersi con testo della chat o nomi di file tipo "resume-...".
$SAFE_RESUME = @('continua a lavorare', 'continua il lavoro', 'riprova', 'riprendi', 'continue working', 'continue')
# Questi NON vanno MAI cliccati (sicurezza anti-spesa):
$NEVER_CLICK = @('acquist', 'passa a max', 'aggiorna il tuo piano', 'upgrade', 'paga', 'purchase', 'buy', 'piano')
# Pattern stretto per leggere SOLO l'ora di reset (non per rilevare il limite):
$LIMIT_RX = '(?i)(?:ripristina|azzera|si\s+azzera|reset)\D{0,20}\d{1,2}:\d{2}'

$LogDir = Join-Path $env:USERPROFILE '.cache\claude-ac'
$LogFile = Join-Path $LogDir 'resume-watcher.log'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }

function Write-Log([string]$msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Output $line
    Add-Content -Path $LogFile -Value $line -Encoding utf8
}

# Notifica desktop (balloon, zero dipendenze)
$script:Notifier = $null
function Send-Toast([string]$title, [string]$text) {
    try {
        if (-not $script:Notifier) {
            $script:Notifier = New-Object System.Windows.Forms.NotifyIcon
            $script:Notifier.Icon = [System.Drawing.SystemIcons]::Information
            $script:Notifier.Visible = $true
        }
        $script:Notifier.BalloonTipTitle = $title
        $script:Notifier.BalloonTipText = $text
        $script:Notifier.ShowBalloonTip(8000)
    } catch { }
}

# Trova le finestre top-level dell'APP desktop Claude (non la CLI claude-code)
function Get-ClaudeWindows {
    $storePids = @(Get-Process claude -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like '*WindowsApps*' } | Select-Object -ExpandProperty Id)
    if ($storePids.Count -eq 0) { return @() }
    $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
    $wins = $AE::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
    $out = @()
    foreach ($w in $wins) { if ($storePids -contains $w.Current.ProcessId) { $out += $w } }
    return $out
}

# Tutti gli elementi Text di una finestra concatenati (per cercare il banner limite + ora reset)
function Get-WindowText($win) {
    $txtCond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)
    $txts = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $txtCond)
    $sb = New-Object System.Text.StringBuilder
    foreach ($t in $txts) { [void]$sb.AppendLine($t.Current.Name) }
    return $sb.ToString()
}

# Verifica che un elemento sia realmente cliccabile (espone InvokePattern)
function Test-Invokable($el) {
    try {
        $patt = $null
        return $el.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$patt)
    } catch { return $false }
}

# Cerca un pulsante/link SICURO di ripresa. MATCH ESATTO sul nome + dev'essere
# realmente cliccabile. Cerca tra Button E Hyperlink (il "Continua a lavorare"
# di Cowork e' un link). Restituisce l'elemento o $null.
function Find-ResumeButton($win) {
    $types = @([System.Windows.Automation.ControlType]::Button,
               [System.Windows.Automation.ControlType]::Hyperlink)
    foreach ($ct in $types) {
        $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, $ct)
        $els = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
        foreach ($e in $els) {
            $name = ('' + $e.Current.Name).Trim()
            if (-not $name) { continue }
            $low = $name.ToLower()
            # blacklist assoluta (sicurezza anti-spesa)
            $blocked = $false
            foreach ($bad in $NEVER_CLICK) { if ($low.Contains($bad)) { $blocked = $true; break } }
            if ($blocked) { continue }
            # MATCH ESATTO con la whitelist
            if ($SAFE_RESUME -contains $low) {
                if (Test-Invokable $e) { return $e }
            }
        }
    }
    return $null
}

# Estrae l'ora di reset (HH:MM) dal testo del banner; ritorna [datetime] o $null
function Parse-ResetTime([string]$text) {
    $m = [regex]::Match($text, '(?i)(?:ripristina|ripristino|reimposta|azzera|reset)\D{0,20}(\d{1,2}):(\d{2})')
    if (-not $m.Success) { return $null }
    $h = [int]$m.Groups[1].Value; $min = [int]$m.Groups[2].Value
    $now = Get-Date
    $t = Get-Date -Hour $h -Minute $min -Second 0
    if ($t -lt $now.AddMinutes(-5)) { $t = $t.AddDays(1) }  # se l'ora e' gia' passata oggi -> domani
    return $t
}

# Clicca un elemento via InvokePattern (vero click di accessibilita', no coordinate)
function Invoke-Element($el) {
    try {
        $p = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        $p.Invoke()
        return $true
    } catch {
        # fallback: alcuni controlli usano LegacyIAccessible / SelectionItem
        try {
            $p2 = $el.GetCurrentPattern([System.Windows.Automation.LegacyIAccessiblePattern]::Pattern)
            $p2.DoDefaultAction()
            return $true
        } catch { return $false }
    }
}

# Una scansione: ritorna un oggetto stato
function Scan-Once {
    $wins = Get-ClaudeWindows
    $result = [pscustomobject]@{
        AppRunning = ($wins.Count -gt 0)
        Limited    = $false
        ResetTime  = $null
        Button     = $null
        ButtonName = $null
        WindowName = $null
    }
    foreach ($w in $wins) {
        # Il segnale AFFIDABILE e' la presenza di un VERO pulsante di ripresa
        # cliccabile: il testo della chat puo' contenere le parole "limite di
        # utilizzo" e darebbe falsi positivi, quindi NON lo usiamo per rilevare.
        $btn = Find-ResumeButton $w
        if ($btn) {
            $result.Limited = $true
            $result.WindowName = $w.Current.Name
            $result.Button = $btn
            $result.ButtonName = $btn.Current.Name
            $rt = Parse-ResetTime (Get-WindowText $w)   # ora di reset (best effort)
            if ($rt) { $result.ResetTime = $rt }
            break
        }
    }
    return $result
}

# ----------------------------- MODALITA' -Once -----------------------------
if ($Once) {
    $s = Scan-Once
    Write-Log ("SCAN: AppRunning={0} Limited={1} Reset={2} Button='{3}'" -f `
        $s.AppRunning, $s.Limited, $(if($s.ResetTime){$s.ResetTime.ToString('HH:mm')}else{'-'}), $s.ButtonName)
    if (-not $s.AppRunning) { Write-Log "  -> App Claude non in esecuzione." }
    elseif (-not $s.Limited) { Write-Log "  -> Nessun limite attivo adesso. Tutto ok." }
    else { Write-Log "  -> LIMITE ATTIVO. Pulsante ripresa rilevato: $([bool]$s.Button)" }
    return
}

# ----------------------------- LOOP CONTINUO -------------------------------
Write-Log "Resume Watcher avviato (intervallo ${IntervalSeconds}s, buffer ${BufferSeconds}s, NoClick=$NoClick)."
Send-Toast "Claude Auto-Continue" "Sorvegliante attivo: riprendo io il lavoro quando i crediti tornano."

$armed = $false          # abbiamo visto un limite e stiamo aspettando il reset
$announcedReset = $null  # per non ripetere la notifica
$lastResumeTry = [datetime]::MinValue

while ($true) {
    try {
        $s = Scan-Once

        if ($s.Limited) {
            if (-not $armed) {
                $armed = $true
                $rt = if ($s.ResetTime) { $s.ResetTime.ToString('HH:mm') } else { 'ora ignota' }
                Write-Log "LIMITE rilevato. Reset previsto: $rt. In attesa..."
                Send-Toast "Claude: limite raggiunto" "Riprendo io appena i crediti si ricaricano (reset $rt)."
                $announcedReset = $rt
            }

            $now = Get-Date
            $canResume = $true
            if ($s.ResetTime) { $canResume = ($now -ge $s.ResetTime.AddSeconds($BufferSeconds)) }

            if ($canResume -and $s.Button -and -not $NoClick) {
                # evita click a raffica: max 1 tentativo ogni 20s
                if (($now - $lastResumeTry).TotalSeconds -ge 20) {
                    $lastResumeTry = $now
                    $bn = $s.ButtonName
                    Write-Log "Tentativo di ripresa: clic su '$bn'..."
                    $ok = Invoke-Element $s.Button
                    Start-Sleep -Seconds 3
                    $after = Scan-Once
                    if ($ok -and (-not $after.Limited)) {
                        Write-Log "RIPRESA RIUSCITA: il limite e' sparito dopo il clic su '$bn'."
                        Send-Toast "Claude: lavoro ripreso!" "Ho cliccato '$bn' e la sessione e' ripartita."
                        $armed = $false
                    } else {
                        Write-Log "Clic eseguito ma limite ancora presente (crediti non ancora pronti?). Riprovo piu' tardi."
                    }
                }
            }
            elseif ($canResume -and $s.Button -and $NoClick) {
                if (($now - $lastResumeTry).TotalSeconds -ge 120) {
                    $lastResumeTry = $now
                    Send-Toast "Claude: crediti tornati" "Apri Claude e premi '$($s.ButtonName)' per continuare."
                }
            }
        }
        else {
            if ($armed) {
                Write-Log "Limite non piu' presente: la sessione e' attiva. Disarmo."
                $armed = $false
            }
        }
    }
    catch {
        Write-Log ("ERRORE nel loop: " + $_.Exception.Message)
    }

    Start-Sleep -Seconds $IntervalSeconds
}
