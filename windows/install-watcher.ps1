<#
=============================================================================
 install-watcher.ps1  --  Attiva il "Resume Watcher" automatico (Windows)
=============================================================================
 Copia resume-watcher.ps1 in una cartella stabile e lo avvia AL LOGIN, nascosto,
 tramite un collegamento nella cartella "Esecuzione automatica" (Startup).
 Non serve Task Scheduler ne' privilegi di amministratore.
 (Si usa un .lnk e non un .vbs perche' gli antivirus tendono a bloccare i .vbs
  in avvio automatico.)

 Il watcher legge da solo l'ora di reset dal banner del limite, aspetta fino a
 (reset + 30s) e clicca il pulsante di ripresa. In autonomia.

 Uso:
   powershell -ExecutionPolicy Bypass -File install-watcher.ps1
   powershell -ExecutionPolicy Bypass -File install-watcher.ps1 -Uninstall

 Made in Italy.
=============================================================================
#>
[CmdletBinding()]
param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$InstallDir = Join-Path $env:LOCALAPPDATA 'claude-ac'
$Target     = Join-Path $InstallDir 'resume-watcher.ps1'
$Startup    = [Environment]::GetFolderPath('Startup')
$LnkPath    = Join-Path $Startup 'ClaudeAutoContinueWatcher.lnk'
$VbsPath    = Join-Path $Startup 'ClaudeAutoContinueWatcher.vbs'   # legacy, da ripulire

function Stop-Watcher {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { try { $_.CommandLine -like '*resume-watcher.ps1*' } catch { $false } } |
        ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force } catch {} }
}

if ($Uninstall) {
    Write-Host "Disattivo il Resume Watcher..."
    foreach ($p in @($LnkPath, $VbsPath)) { if (Test-Path $p) { Remove-Item $p -Force; Write-Host "  - Rimosso: $p" } }
    Stop-Watcher
    Write-Host "Fatto. Il watcher non partira' piu' al login."
    return
}

Write-Host "Attivo il Resume Watcher automatico..."

# 1) copia il watcher in cartella stabile
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null }
Copy-Item -Path (Join-Path $PSScriptRoot 'resume-watcher.ps1') -Destination $Target -Force
Write-Host "  - Watcher copiato in: $Target"

# pulizia eventuale .vbs legacy
if (Test-Path $VbsPath) { Remove-Item $VbsPath -Force }

# 2) avvio automatico al login: collegamento nella cartella Startup
$psExe = (Get-Command powershell.exe).Source
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($LnkPath)
$sc.TargetPath       = $psExe
$sc.Arguments        = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Target`""
$sc.WorkingDirectory = $InstallDir
$sc.WindowStyle      = 7   # minimizzato (nessuna finestra in vista)
$sc.Description       = "claude-ac Resume Watcher (automatico). Made in Italy."
$sc.Save()
Write-Host "  - Avvio automatico registrato: $LnkPath"

# 3) avvia subito (nascosto), senza duplicati
Stop-Watcher
Start-Process $psExe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$Target -WindowStyle Hidden
Write-Host "  - Watcher avviato adesso."

Write-Host ""
Write-Host "Fatto! Da ora il watcher parte a ogni accesso a Windows e, quando finiscono"
Write-Host "i crediti, riprende il lavoro da solo (legge l'ora di reset e clicca a reset+30s)."
Write-Host "Log: $($env:USERPROFILE)\.cache\claude-ac\resume-watcher.log"
